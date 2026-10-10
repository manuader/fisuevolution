import Foundation

/// Qué salió de un cofre. `coins` lleva rareza igual porque la animación ya
/// pintó su color antes de saber el resultado: si el pago viniera sin rareza,
/// el latido del estallido tendría que elegir un color al azar.
public enum ChestOutcome: Sendable, Equatable {
    case skin(id: String, characterType: String, rarity: SkinsConfig.Rarity)
    case coins(rarity: SkinsConfig.Rarity)
}

/// Lo que devuelve abrir un cofre: un premio, o el aviso de que todavía no hay
/// ninguno que el jugador pueda usar.
///
/// ⚠️ **Es un tipo aparte de `ChestOutcome` a propósito.** `ChestOutcome` es lo
/// que la animación DIBUJA, y "no hay nada" no se dibuja: metido ahí como tercer
/// caso, obligaba a seis ramas muertas adentro de `ChestOpeningView` —una por
/// cada `switch` de la coreografía— para un valor que esa vista no puede recibir.
/// Separados, el tipo del premio sólo modela premios y el compilador sigue
/// obligando a `openChest()` a contestar las dos posibilidades.
public enum ChestDraw: Sendable, Equatable {
    case prize(ChestOutcome)
    /// No hay ninguna pinta que el jugador pueda **ponerse hoy**, pero le quedan
    /// personajes por desbloquear. El cofre NO se gasta: espera a que suba.
    ///
    /// Es una situación distinta de `coins`, y por eso es un caso propio y no un
    /// pago de cero: `coins` es el premio consuelo del que ya completó la
    /// colección, y esto es el cofre de alguien que todavía la está armando.
    /// Confundirlos le quemaría cofres al que recién empieza, que es justo a
    /// quien más le rinden.
    case needsProgress
}

/// Lo que un cofre puede dar hoy, para mostrarlo ANTES de comprar (Apple 3.1.1).
public enum ChestOddsTable: Sendable, Equatable {
    /// Las rarezas con su chance real (`id` = `Rarity.rawValue`), en orden de
    /// rareza; suman 1. Las mismas `PrizeOdds` que la ruleta y el colchón.
    case skins([PrizeOdds])
    /// La colección está completa: el cofre paga plata.
    case coins
    /// No hay ninguna pinta alcanzable todavía: el cofre espera (`needsProgress`).
    case nothingYet
}

/// El sorteo de un cofre. Puro y con RNG inyectado, como `special_roll`: los
/// tests fijan la semilla y el resultado es reproducible.
public enum ChestRoller {
    /// Sortea el contenido de un cofre.
    ///
    /// - Parameter unlocked: Los `characterType` que el jugador desbloqueó **en
    ///   la historia de la cuenta**, no en esta run. Regla del dueño
    ///   (2026-08-28): *es imposible que te toque la pinta de un personaje al
    ///   que no llegaste*, y lo que cuenta son también los que desbloqueaste en
    ///   reencarnaciones anteriores. El filtro vive en `stock`, que es el embudo
    ///   ÚNICO por el que pasan los tres caminos —la rareza sorteada, la
    ///   promoción hacia arriba y la degradación hacia abajo—, así que no queda
    ///   ninguna puerta lateral por la que se escape una pinta bloqueada.
    public static func roll(
        owned: Set<String>,
        unlocked: Set<String>,
        skins: SkinsConfig,
        config: ChestsConfig,
        minRarity: SkinsConfig.Rarity? = nil,
        using rng: inout some RandomNumberGenerator
    ) -> ChestDraw {
        let candidatas = SkinsConfig.Rarity.allCases.filter { $0 >= (minRarity ?? .comun) }
        // El `??` no es alcanzable —`candidatas` nunca queda vacío, el filtro deja
        // como mínimo a `minRarity`— pero cae en `minRarity` y no en `.comun`: si
        // alguna vez lo fuera, devolver la más baja violaría el mínimo pedido.
        let sorteada = weightedPick(candidatas, config: config, using: &rng) ?? (minRarity ?? .comun)
        guard let resuelta = firstWithStock(
            from: sorteada, owned: owned, unlocked: unlocked, skins: skins
        ) else {
            // Sin stock alcanzable hay DOS situaciones que se ven iguales desde
            // acá y no lo son. Si todavía quedan pintas sin ganar, están detrás
            // de personajes a los que el jugador no llegó: el cofre espera. Si no
            // queda ninguna, la colección está completa y el cofre paga.
            return skins.chestPool.allSatisfy { owned.contains($0.id) }
                ? .prize(.coins(rarity: sorteada))
                : .needsProgress
        }
        let disponibles = stock(of: resuelta, owned: owned, unlocked: unlocked, skins: skins)
        // `randomElement(using:)` sobre un array ordenado por catálogo: el orden
        // de `chestPool` es estable, así que la semilla reproduce la tirada.
        let elegida = disponibles.randomElement(using: &rng)!
        return .prize(.skin(id: elegida.id, characterType: elegida.characterType, rarity: resuelta))
    }

    /// ¿Este cofre tiene algo para dar HOY?
    ///
    /// Es la MISMA pregunta que contesta `roll` al abrir, pero sin gastar RNG:
    /// la usa la tarjeta de Regalos para no ofrecer un botón que no va a hacer
    /// nada. Comparte los dos predicados con `roll` a propósito — si se
    /// escribieran por separado, el día que uno cambie la pantalla ofrecería
    /// cofres que no se abren, o escondería cofres que sí.
    public static func hasSomethingToGive(
        owned: Set<String>, unlocked: Set<String>, skins: SkinsConfig
    ) -> Bool {
        if !stockAcrossRarities(owned: owned, unlocked: unlocked, skins: skins).isEmpty { return true }
        return skins.chestPool.allSatisfy { owned.contains($0.id) }
    }

    /// Las probabilidades que de verdad sortea `roll`: el peso de cada rareza
    /// candidata va a la rareza en la que TERMINA (`firstWithStock`: sube si se
    /// agotó, baja si lo de arriba está bloqueado). Mostrar los pesos crudos de
    /// `chests.json` mentiría apenas el jugador tiene la mitad de la colección.
    public static func effectiveOdds(
        owned: Set<String>,
        unlocked: Set<String>,
        skins: SkinsConfig,
        config: ChestsConfig,
        minRarity: SkinsConfig.Rarity? = nil
    ) -> ChestOddsTable {
        let candidatas = SkinsConfig.Rarity.allCases.filter { $0 >= (minRarity ?? .comun) }
        let total = candidatas.reduce(0) { $0 + config.weight(for: $1) }
        var odds: [SkinsConfig.Rarity: Double] = [:]
        for rarity in candidatas {
            // Sin pesos, `weightedPick` devuelve la primera: la misma regla.
            let share = total > 0
                ? Double(config.weight(for: rarity)) / Double(total)
                : (rarity == candidatas.first ? 1 : 0)
            guard share > 0 else { continue }
            guard let resuelta = firstWithStock(from: rarity, owned: owned, unlocked: unlocked, skins: skins) else {
                return skins.chestPool.allSatisfy { owned.contains($0.id) } ? .coins : .nothingYet
            }
            odds[resuelta, default: 0] += share
        }
        return .skins(SkinsConfig.Rarity.allCases.compactMap { rarity in
            odds[rarity].map { PrizeOdds(id: rarity.rawValue, probability: $0) }
        })
    }

    /// Cuántas pintas puede ganar hoy el jugador (sin dueño y desbloqueadas).
    public static func reachableSkinCount(
        owned: Set<String>, unlocked: Set<String>, skins: SkinsConfig
    ) -> Int {
        stockAcrossRarities(owned: owned, unlocked: unlocked, skins: skins).count
    }

    /// Sube a la primera rareza con stock; si arriba no hay ninguna, baja.
    ///
    /// Sube antes que bajar porque promocionar se lee como un regalo y degradar
    /// como un recorte, y porque deja las legendarias para el final: son las
    /// únicas que no reciben promociones de más arriba.
    ///
    /// ⚠️ **Con el filtro de desbloqueo, en la práctica baja mucho más de lo que
    /// sube**, y no es un defecto: las rarezas altas SON los pisos altos (la
    /// bolsa se repartió por el piso donde vive cada personaje), así que lo que
    /// está por encima de tu rareza suele estar además por encima de tu progreso.
    /// El orden se conserva igual porque sigue siendo el correcto el día que el
    /// jugador tenga pisos altos abiertos y le falten pintas ahí.
    ///
    /// No recibe `minRarity` a propósito: el mínimo acota QUÉ SE SORTEA, no qué
    /// se entrega. Agotado todo lo que está a su altura o por encima, un cofre
    /// que baja da una skin que al jugador le falta; respetar el mínimo acá lo
    /// dejaría sin premio teniendo la bolsa a medio llenar.
    private static func firstWithStock(
        from rarity: SkinsConfig.Rarity, owned: Set<String>, unlocked: Set<String>, skins: SkinsConfig
    ) -> SkinsConfig.Rarity? {
        let arriba = SkinsConfig.Rarity.allCases.filter { $0 >= rarity }
        let abajo = SkinsConfig.Rarity.allCases.filter { $0 < rarity }.reversed()
        return (arriba + abajo).first {
            !stock(of: $0, owned: owned, unlocked: unlocked, skins: skins).isEmpty
        }
    }

    /// El embudo único del filtro: **toda** pinta que sale de un cofre pasa por
    /// acá. Sacar `unlocked` de esta línea es lo único que hace falta para que
    /// la regla del dueño deje de valer, y por eso no hay una segunda copia.
    private static func stock(
        of rarity: SkinsConfig.Rarity, owned: Set<String>, unlocked: Set<String>, skins: SkinsConfig
    ) -> [SkinsConfig.Entry] {
        skins.chestPool.filter {
            $0.chestRarity == rarity
                && !owned.contains($0.id)
                && unlocked.contains($0.characterType)
        }
    }

    private static func stockAcrossRarities(
        owned: Set<String>, unlocked: Set<String>, skins: SkinsConfig
    ) -> [SkinsConfig.Entry] {
        SkinsConfig.Rarity.allCases.flatMap {
            stock(of: $0, owned: owned, unlocked: unlocked, skins: skins)
        }
    }

    private static func weightedPick(
        _ rarities: [SkinsConfig.Rarity], config: ChestsConfig, using rng: inout some RandomNumberGenerator
    ) -> SkinsConfig.Rarity? {
        let total = rarities.reduce(0) { $0 + config.weight(for: $1) }
        guard total > 0 else { return rarities.first }
        var corte = Int.random(in: 0..<total, using: &rng)
        for rarity in rarities {
            corte -= config.weight(for: rarity)
            if corte < 0 { return rarity }
        }
        return rarities.last
    }
}
