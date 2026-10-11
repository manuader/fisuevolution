import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// Validates the real bundled content (the JSON that ships in the app).
@Suite("Bundled game content")
struct GameContentValidationTests {
    let content: GameContent

    init() throws {
        content = try GameContentLoader.load(from: .main)
    }

    @Test func tierTableHasExpectedShape() {
        // Remapeo a 10 pisos: 44 entradas = 43 concretas + el nodo de elección
        // `junior`. Las 43 concretas son las 36 de antes menos `kiosco` más los
        // 8 personajes nuevos, y son exactamente las 43 caras del arte.
        #expect(content.tiers.types.count == 44)
        #expect(content.tiers.concreteTypes.count == 43)
        #expect(content.tiers.maxTier == 37)
        #expect(content.tiers.baseType.id == "homeless")
        #expect(content.tiers.terminalType.id == "god")
    }

    @Test func careerChoiceNodeIsWellFormed() throws {
        let junior = try #require(content.tiers.type(id: "junior"))
        #expect(junior.isChoiceNode)
        #expect(junior.choiceOptions?.count == 4)
        for option in junior.choiceOptions ?? [] {
            let resolved = try #require(content.tiers.type(id: option))
            #expect(resolved.tier == 11)
            #expect(resolved.isChoiceNode == false)
        }
    }

    /// RF-10: el playtest pidió "al menos 4 personajes por piso, menos el último
    /// que sólo tiene a Dios". Con 4 exactos por piso el reparto queda forzado,
    /// así que este test es la aritmética entera del remapeo en una sola pieza.
    @Test("la torre cubre 1…37 sin huecos y ningún piso no-Dios tiene menos de 4 tiers")
    func towerCoverageAfterRemap() {
        let floors = content.floorTable.floors
        #expect(floors.count == 10)
        for floor in floors where floor.id != "god_realm" {
            #expect(floor.lastTier - floor.firstTier + 1 == 4, "\(floor.id) no tiene 4 tiers")
        }
        #expect(floors.first?.firstTier == 1)
        #expect(floors.last?.lastTier == 37)
        for (lower, upper) in zip(floors, floors.dropFirst()) {
            #expect(lower.lastTier + 1 == upper.firstTier, "hueco o solape entre \(lower.id) y \(upper.id)")
        }
    }

    /// `kiosco` (Personal de Kiosco) se eliminó de la cadena y El Mantero ocupó
    /// su lugar. Se va de los tres lados a la vez: si sobrevive en uno queda
    /// arte huérfano o —peor— una skin que no se le puede aplicar a nadie.
    @Test("kiosco ya no existe en ningún lado")
    func kioscoIsGone() {
        #expect(content.tiers.types.allSatisfy { $0.id != "kiosco" })
        #expect(content.skins.skins.allSatisfy { $0.characterType != "kiosco" })
        #expect(content.manifest.characters.keys.allSatisfy { !$0.hasPrefix("kiosco") })
    }

    /// El fondo `bg_cosmic` se retiró (decisión estética del dueño). Sin entrada
    /// en el manifest el código cae a un placeholder programático SIN romperse,
    /// así que un fondo huérfano no falla ningún otro test: por eso se asserta acá.
    @Test("el fondo cosmic se retiró del manifest y ningún piso lo pide")
    func cosmicBackgroundIsGone() {
        #expect(content.manifest.backgrounds["cosmic"] == nil)
        #expect(content.floorTable.floors.allSatisfy { $0.background != "cosmic" })
        #expect(content.manifest.backgrounds.count == 10)
    }

    /// El corte `earth`/`cosmic` tiene que caer en un BORDE de piso, no partir
    /// uno al medio: es lo que elige la música y el tema del tablero. Después
    /// del remapeo cae entre T24 (Dueño de la Luna, último de `moon`) y T25
    /// (Dueño de Marte, primero de `mars`).
    @Test("la fase cambia justo en el borde moon→mars")
    func phaseCutFallsOnAFloorBoundary() throws {
        for type in content.tiers.types {
            let expected: GamePhase = type.tier <= 24 ? .earth : .cosmic
            #expect(type.phase == expected, "\(type.id) (T\(type.tier)) está en la fase equivocada")
        }
        let moon = try #require(content.floorTable.floors.first { $0.id == "moon" })
        #expect(moon.lastTier == 24, "el corte de fase dejó de coincidir con el borde de piso")
    }

    /// Anti-drift: every number in tiers.json must equal the F7 formulas applied to
    /// economy.json. Hand-edited numbers break this on purpose.
    @Test func tierNumbersDeriveFromEconomyFormulas() {
        let economy = StandardEconomy(config: content.economy)
        for type in content.tiers.types {
            expectRelativelyEqual(type.tapYield, economy.tapYield(forTier: type.tier), context: "\(type.id).tapYield")
            expectRelativelyEqual(type.passiveYieldPerInstance, economy.passiveYield(forTier: type.tier), context: "\(type.id).passiveYield")
            expectRelativelyEqual(type.passiveUnlockCost, economy.passiveUnlockCost(forTier: type.tier), context: "\(type.id).unlockCost")
        }
    }

    @Test func economyConfigMatchesTunedValues() {
        // Pins de la calibración FINAL de economy.json v2 (F7 "La Torre").
        // Si tuneás la economía, actualizá estos pins A PROPÓSITO — el drift
        // silencioso del JSON es exactamente el bug que este test caza.
        let economy = content.economy
        #expect(economy.schemaVersion == 2)
        #expect(economy.baseTapYieldTier1 == 1)
        #expect(economy.yieldGrowthPerTier == 2.8)
        #expect(economy.passiveRatio == 0.5)
        #expect(economy.passiveUnlockCostMultiplier == 60)
        // Rebalance de pacing §4.3: el TAP dejó de cobrar el `incomeMultiplier`
        // del piso (1 → 620) y el pasivo lo sigue cobrando entero. Es lo que
        // separa las dos curvas, que hasta acá eran la misma con un factor. En
        // el callejón el multiplicador es 1, así que el early game —el tutorial
        // y la primera contratación— no se mueve ni un peso.
        #expect(economy.tapFloorMultiplierExponent == 0)
        // Regla de precios del dueño (2026-08-23): contratar **a tu frontera**
        // cuesta 600× lo que rinde un click de ese personaje, y cada compra sube
        // el precio 6%. El callejón es la excepción barata (25 = el Fisura).
        // Era 300 y el dueño lo duplicó el 2026-08-04; ver Docs/balance-log.md.
        #expect(economy.hire.defaultCostMultiplier == 600)
        // El 20% por compra bajó a 6% en el rebalance de pacing, y NO es un
        // ajuste fino: es el arreglo de la divergencia costos-vs-ingresos.
        // El 20% compone sobre el contador de compras del MISMO tipo, y el bot
        // llega a acumular cientos: medido, 70 compras al abrir corporativo y
        // 870 al final de la partida. Con 1,2 la compra 70 ya cuesta 384 s de
        // income y la run se traba en el tier 11 — el bot NUNCA maxea las siete
        // ni llega a Dios. Con 1,06 la compra 144 cuesta 4,9 s y la partida
        // entera se puede jugar. (1,2^256 = 1,86e20 contra 1,06^256 = 3,0e6, si
        // se quiere el orden de magnitud del compounding.)
        //
        // ⚠️ **El 6% se queda acá y el muro del arranque se arregló en el piso**
        // (quinta ronda, 2026-08-28). Bajarlo GLOBAL es lo primero que se probó
        // y lo que peor midió: 1,04 deja maxear las siete en 15,34 h y 1,03 en
        // 15,96 h —fuera de la banda de 20-30 que pidió el dueño— y sobre todo
        // desarma la pared, que pasa de seis runs trabadas a cuatro y a dos.
        // Este factor es una de las dos patas de la desaceleración; el arranque
        // se arregla donde el arranque vive (ver `hireCostGrowthOverride` del
        // callejón en `floorHireOverridesMatchTunedValues`).
        #expect(economy.hire.defaultCostGrowth == 1.06)
        // La pendiente del precio por tier (cuarta ronda de balance): **1,5, y
        // lo que importa es que esté por DEBAJO de 2**, que es el factor de
        // merge. Con 1,5, una unidad de tu frontera comprada `d` tiers más abajo
        // sale (2/1,5)^d = 1,33^d MÁS cara, así que comprar hondo deja de ser el
        // atajo que medía la tercera ronda. Reemplazó al `tierPremium` de 1,8,
        // que se reiniciaba en cada piso y dejaba la pendiente real dentro del
        // piso en 2,8 × 1,8 = 5,04 — el atajo, otra vez.
        #expect(economy.hire.priceGrowthPerTier == 1.5)
        #expect(
            economy.hire.priceGrowthPerTier < 2,
            "por encima del factor de merge, comprar hondo vuelve a ser más barato"
        )
        // La compuerta de contratación, en TIERS. Subió de 5 a 6 en la cuarta
        // ronda, y recién ahí fue un cambio de dificultad de verdad: con el
        // precio atado a `tapYield(tier)` una compuerta más profunda ABARATABA
        // el juego (N=4 → 6,67 h · N=6 → 5,34 h). Con el precio anclado a la
        // frontera va para el lado que el diseño esperaba — medido, 5 → 4,14 h y
        // 6 → 7,27 h—, porque cada tier de profundidad duplica las unidades que
        // hay que comprar. Arriba de 6 se despierta el muro del early game: hasta
        // que la frontera llega a N+2 lo único contratable es el Fisura.
        #expect(economy.hire.gateTierDistance == 6)
        // La desaceleración (cuarta ronda, ter): del tier 7 para arriba tu propia
        // frontera se encarece un 60 % por tier. Es lo que hace que la run se
        // TRABE y, con eso, lo que le da trabajo al prestigio — sin esto ninguna
        // run se trababa nunca y se podía ir de Fisura a Dios de una sentada.
        // El umbral en 7 deja el callejón y el tutorial intactos: con la escalada
        // desde el tier 1 las primeras cinco runs se traban EN el callejón.
        #expect(economy.hire.frontierEscalationPerTier == 1.6)
        #expect(economy.hire.frontierEscalationFromTier == 7)
        #expect(economy.charUpgrades.baseCostMultiplier == 50)
        // Bajó de 4,0 el 2026-08-22, y no es un ajuste de precio sino la
        // consecuencia del efecto secuencial: contra un efecto LINEAL, un costo
        // ×4 por nivel mata la línea. Medido sobre la partida entera, el bot
        // llegaba como mucho al nivel 7 de 19 y la mediana era 4 — doce niveles
        // que nadie compra nunca, y un ×20 que nadie ve. Con 1,5 la mediana
        // queda en 11/19 y los tipos mejor puestos sí llegan al tope.
        #expect(economy.charUpgrades.costGrowth == 1.5)
        // Efecto SECUENCIAL (dueño, 2026-08-22): el multiplicador es
        // `1 + nivel × paso`, o sea ×2, ×3, ×4 … y no el `2^nivel` de antes,
        // que llegaba a ×1.048.576 y tapaba a la torre entera.
        #expect(economy.charUpgrades.effectStepPerLevel == 1.0)
        // 19 niveles es lo que clava el tope en el ×20 que escribió el dueño
        // (`1 + 19 × 1`). Con 20 sería ×21, que nadie pidió. Cambiarlo es una
        // decisión de balance, no un ajuste.
        #expect(economy.charUpgrades.maxLevel == 19)
        // Bajó de 3e12 a 1e9 el 2026-08-22 para recuperar el contrato del dueño
        // después del efecto secuencial: con el divisor viejo, maxear las siete
        // pasaba a 122 h activas y la primera reencarnación a las 25,67 h. Con
        // 1e9 vuelve a 24,67 h y 8 reencarnaciones.
        //
        // Lo que se paga: la primera reencarnación se adelanta a 4,07 h de pared
        // (0,41 h activas) contra las 62,00 h que dejó la ronda 1. Lo que se
        // conserva —y era el objetivo real de aquel cambio— es que reencarnar
        // temprano CONVENGA: el barrido de umbral quedó monótono (×1 → 24,67 h ·
        // ×8 → 30,54 h · ×1000 → 50,51 h · sin reencarnar, dios a 66,34 h).
        // Subió de 1e9 a 1e10 en la cuarta ronda (ter), y no es un ajuste de
        // precio: es lo que hace que las runs duren lo suficiente para LLEGAR a
        // la pared que construyó la desaceleración. Con 1e9 la pared corría
        // +1 · +3 y a los saltos; con 1e10 corre +1 · +1 · +2 · +2 · +2, parejo,
        // y maxear entra en la banda de 20-30 h. Medido en `balance-log.md`.
        #expect(economy.oro.divisor == 10_000_000_000)
        // RF-07 (Ola 3) lo había bajado de 0.5 a 0.45; el rebalance lo baja a
        // 0.25 porque con 0,45 hacen falta ×4,65 de ganancias por duplicar el
        // ORO y las 8 entregas entraban en 1,3 h activas. Con 0,25 hacen falta
        // ×16 y las 8 se reparten en 25 h. Ver Docs/balance-log.md.
        #expect(economy.oro.exponent == 0.25)
        #expect(economy.oro.globalMultiplierPerOro == 0.18)
        #expect(economy.critChanceBase == 0.0)
        #expect(economy.critMultiplier == 5.0)
        #expect(economy.offlineEfficiencyBase == 0.35)
        #expect(economy.offlineCapHours == 10)
    }

    @Test("el umbral del popup offline viaja en el dato, no en el default del código")
    func offlinePopupThresholdIsDeclared() {
        #expect(content.economy.offlinePopupMinSeconds == 30)
    }

    /// El catálogo de las seis líneas nunca puede pasarse de su `EffectCaps`.
    ///
    /// No es cosmético: `UpgradeManager.recomputeDerivedEffects` (app) CLAMPEA
    /// con esos topes y `PermanentUpgrades.recomputeDerivedEffects` (EconomyKit,
    /// que es lo que corre el simulador) NO. Mientras ninguna línea llegue a su
    /// tope los dos coinciden; en cuanto una lo pase, el simulador mide un
    /// efecto que el juego recorta y la calibración entera queda mintiendo —en
    /// silencio, que es lo peor. Este test es el que hace ruido.
    @Test func upgradeLinesNeverReachTheirEffectCaps() {
        let economy = content.economy
        for line in content.upgradesConfig.upgrades {
            let total = Double(line.maxLevel) * line.magnitudePerLevel
            switch line.effectType {
            case .critChance:
                #expect(economy.critChanceBase + total <= EffectCaps.crit, "\(line.id): \(total)")
            case .offlineEfficiency:
                #expect(economy.offlineEfficiencyBase + total <= EffectCaps.offline, "\(line.id): \(total)")
            case .goldenTouchChance:
                #expect(total <= EffectCaps.golden, "\(line.id): \(total)")
            case .luckyTouch:
                #expect(economy.critChanceBase + total <= EffectCaps.crit, "\(line.id): \(total)")
                #expect(Double(line.maxLevel) * line.goldenPerLevel <= EffectCaps.golden, "\(line.id): dorado")
            case .spawnCostDiscount:
                #expect(total <= EffectCaps.spawnDiscount, "\(line.id): \(total)")
            case .incomeMultiplier, .tapMultiplier, .prestigeBonusPerSoulPoint:
                #expect(total > 0, "\(line.id) no aporta nada")
            }
        }
    }

    @Test func theVideoCatalogFollowsE13() throws {
        let rewards = content.rewardedAds.rewards
        #expect(!rewards.contains { $0.id == "accelerate_evolution" })
        #expect(!rewards.contains { $0.id == "merge_all" }, "Fusionar todo por video vive sólo en la columna")
        let gift = try #require(rewards.first { $0.effectType == .rareUnit })
        #expect(gift.tiersBelowFrontier == 3, "el mismo tier que el Blanqueo")
    }

    /// Pin del catálogo de las seis líneas. `economy.json` tiene el suyo desde
    /// F7 y `upgrades.json` no tenía ninguno — y sobre estos 192 ORO (348 con `baseCost` 2, E2b T14) descansa
    /// toda la calibración del rebalance, incluido el techo de 8
    /// reencarnaciones: el bot reencarna al DUPLICAR su ORO histórico, así que
    /// las reencarnaciones para maxear son log₂(costo total), y log₂(192) = 7,6.
    /// Un catálogo por encima de ~450 ORO totales rompe ese techo en silencio.
    @Test func upgradeCatalogMatchesTunedValues() {
        let esperado: [String: (levels: Int, magnitude: Double, base: Double, growth: Double)] = [
            "income": (10, 0.2, 1, 1.10), "tap": (10, 0.5, 1, 1.10),
            "offline": (10, 0.05, 1, 1.15), "spawn": (10, 0.03, 1, 1.15),
            "lucky": (20, 0.0125, 1, 1.09),
            "prestige": (10, 0.005, 1, 1.25),
        ]
        let lineas = content.upgradesConfig.upgrades
        #expect(lineas.count == esperado.count)
        var total = 0
        for line in lineas {
            guard let pin = esperado[line.id] else {
                Issue.record("línea inesperada en upgrades.json: \(line.id)")
                continue
            }
            #expect(line.maxLevel == pin.levels, "\(line.id).maxLevel")
            #expect(abs(line.magnitudePerLevel - pin.magnitude) < 1e-12, "\(line.id).magnitudePerLevel")
            #expect(line.effectType != .luckyTouch || abs(line.goldenPerLevel - 0.0025) < 1e-12, "\(line.id).goldenPerLevel")
            #expect(abs(line.baseCost - pin.base) < 1e-12, "\(line.id).baseCost")
            #expect(abs(line.costGrowth - pin.growth) < 1e-12, "\(line.id).costGrowth")
            #expect(line.currency == .oro, "\(line.id) tiene que pagarse con ORO")
            // El precio de cada nivel se redondea para arriba a entero
            // (`UpgradeManager.purchase`), así que el total se suma así.
            total += (0..<line.maxLevel).reduce(0) { $0 + Int(UpgradeManager.cost(of: line, level: $1).rounded(.up)) }
        }
        #expect(total == 192, "maxear las seis cuesta \(total) ORO")
        // Y ninguna línea puede volver a ser el 99,99% del costo de ganar, que
        // es lo que `crit` era antes del rebalance (1,776e10 de 1,778e10).
        let porNivel = lineas.map { line in
            Double((0..<line.maxLevel).reduce(0) { $0 + Int(UpgradeManager.cost(of: line, level: $1).rounded(.up)) })
                / Double(line.maxLevel)
        }
        let masCara = porNivel.max() ?? 0
        let masBarata = porNivel.min() ?? 1
        #expect(masCara / masBarata < 2.0, "\(masCara) vs \(masBarata)")
    }

    /// Pin de los DOCE logros que pagan ORO fijo, contra los 193 que cuesta
    /// maxear las siete líneas.
    ///
    /// Existe porque la calibración del rebalance dejó una regla en pie que
    /// nadie estaba midiendo: los doce sumaban **620 ORO** contra un camino de
    /// 193, o sea que juntar logros **ganaba el juego 3,2 veces** y las siete
    /// líneas dejaban de ser el objetivo. La decisión del dueño (2026-08-21) fue
    /// re-escalarlos a **montos fijos** —no a un porcentaje del costo, que es
    /// menos legible en la ficha del logro— para que los logros **aporten** el
    /// camino en vez de reemplazarlo: **15-20 %**.
    ///
    /// La regla del re-escalado, para que el próximo logro de ORO tenga de dónde
    /// salir en vez de inventarse: **el monto viejo dividido 20, redondeado para
    /// arriba, con piso en 1**. Conserva el orden entero del catálogo (el más
    /// caro sigue siendo `ach_skins_all`) y ningún logro pasa a pagar cero.
    ///
    /// El assert que importa es el TOTAL, no los doce montos: los montos son
    /// tuning y el total es la regla de diseño.
    @Test func fixedOroAchievementsFundAFifthOfTheRun() {
        let deOro = content.achievements.achievements.filter { $0.reward.rewardKind == .oro }
        #expect(deOro.count == 12)

        var total = 0
        for logro in deOro {
            let monto = logro.reward.amount ?? 0
            #expect(monto > 0, "\(logro.id) paga \(monto) de ORO: un logro que no paga nada")
            total += monto
        }
        #expect(total == 33, "los doce logros de ORO suman \(total)")

        // Contra el costo REAL de maxear, derivado del catálogo y no un literal:
        // si mañana `upgrades.json` se encarece, esta proporción se mueve sola y
        // el test lo dice.
        let maxear = content.upgradesConfig.upgrades
            .filter { $0.currency == .oro }
            .reduce(0) { acumulado, line in
                acumulado + (0..<line.maxLevel).reduce(0) { $0 + Int(UpgradeManager.cost(of: line, level: $1).rounded(.up)) }
            }
        let porcentaje = Double(total) / Double(maxear)
        #expect(porcentaje >= 0.15 && porcentaje <= 0.20,
                "los logros aportan \(porcentaje * 100) % del camino (\(total) de \(maxear))")
    }

    @Test func floorHireOverridesMatchTunedValues() {
        // La regla de precios es ÚNICA para toda la torre, así que los únicos
        // overrides legítimos son los DOS del alley, y los dos existen por el
        // mismo motivo —el arranque es el único tramo con un solo personaje
        // comprable—: el multiplicador a 25 ancla el primer Fisura en 25 monedas
        // (era 50; el dueño lo bajó a la mitad para acortar el tutorial) y el
        // growth a 1,03 le saca el muro a la cuesta. Cualquier otro override
        // rompería la regla y es drift, no tuning.
        for floor in content.floorTable.floors {
            if floor.id == "alley" {
                #expect(floor.hireCostMultiplierOverride == 25)
            } else {
                #expect(floor.hireCostMultiplierOverride == nil, "override de hire inesperado en \(floor.id)")
            }
            if floor.id == "alley" {
                // **3% en vez del 6% global, y es el arreglo del muro del arranque**
                // (quinta ronda, 2026-08-28). Hasta que tu frontera llega a
                // `gateTierDistance + 1` el Fisura es lo ÚNICO contratable, así que
                // la cuesta entera se paga con UNA curva cuyo contador se duplica
                // con cada tier: con el 6% el paso T7→T8 salía ×32 el anterior
                // —5 h y media de tapeo contra 14 minutos los seis juntos— y el
                // dueño se trabó ahí. Con el 3% queda en ×6,1
                // (`thePreGateClimbHasNoWallInIt` lo pinea).
                //
                // Vive en el PISO y no en `hire.defaultCostGrowth` porque el
                // global es una de las dos patas de la desaceleración: bajarlo
                // arregla el arranque y desarma la pared (medido: de seis runs
                // trabadas a dos). Acá el efecto queda medido y acotado —dios
                // 28,43 → 30,73 h activas, las siete al tope 20,67 → 20,33 h, la
                // pared intacta en seis runs—, porque el callejón deja de ser el
                // camino barato en el tier 22 y de ahí en más nadie lo compra.
                #expect(floor.hireCostGrowthOverride == 1.03)
            } else {
                #expect(floor.hireCostGrowthOverride == nil, "growth overrideado en \(floor.id)")
            }
            // v2 no overridea unlockTier: todo piso se desbloquea con su firstTier.
            #expect(floor.unlockTierOverride == nil, "unlockTier inesperado en \(floor.id)")
            // El encuadre del fondo nunca puede pasar el sobrante del aspect-fill
            // (1.18 → 18%): más que eso despegaría el fondo del techo del piso.
            #expect(
                floor.backgroundOffset >= 0 && floor.backgroundOffset <= 0.18,
                "backgroundOffset fuera del sobrante en \(floor.id): \(floor.backgroundOffset)"
            )
        }
    }

    /// **LA REGLA DE PRECIOS DEL DUEÑO, en números concretos y contra el
    /// contenido real. Reemplaza a la de los "600 clicks" del 2026-08-04.**
    ///
    /// > 1. Contratar **a tu frontera** cuesta **600 clicks** de ese personaje
    /// >    (el callejón, 25 — el primer Fisura sigue saliendo 25).
    /// > 2. Cada tier que bajás descuenta sólo un tercio (÷1,5) y fusionar
    /// >    necesita el doble de unidades, así que **bajar un tier deja la unidad
    /// >    de tu frontera 1,33× más cara**: comprar hondo no es un atajo.
    ///
    /// La regla vieja decía "el tier base de un piso cuesta 600 veces lo que
    /// rinde un click SUYO ahí", y su problema no era el 600: era que ataba el
    /// precio a `tapYield(tier)`, la MISMA curva que el rendimiento (2,8 por
    /// tier). Como fusionar sólo multiplica por 2, una unidad de tu frontera
    /// comprada `d` tiers más abajo salía `(2/2,8)^d` —y `(2/5,04)^d` dentro de
    /// un piso, con el `tierPremium` puesto—: comprar hondo SIEMPRE salía más
    /// barato, y por eso una compuerta más profunda abarataba el juego en vez de
    /// encarecerlo (medido: N=4 → 6,67 h, N=6 → 5,34 h). El diagnóstico entero y
    /// las tres salidas están en `Docs/balance-log.md`, tercera ronda; el dueño
    /// eligió ésta el 2026-08-23.
    ///
    /// El punto 1 se mide en CLICKS y no replicando la fórmula del precio: el
    /// factor de piso sale de `tapFloorMultiplier(for:)`, el mismo que cobra
    /// `GameActions.applyTap`. Que sea en clicks no es cosmético — cuando el
    /// rebalance le sacó al tap el multiplicador de piso, el precio lo seguía
    /// llevando crudo y contratar el tier base del reino divino pasó de 600
    /// clicks a 600 × 620 = 372.000 sin que nada hiciera ruido, y la versión de
    /// entonces de este test seguía verde porque replicaba la fórmula vieja.
    ///
    /// El callejón queda afuera del loop y con su propio assert porque no es una
    /// excepción sino OTRA decisión del dueño: `hireCostMultiplierOverride: 25`
    /// ancla al primer Fisura en 25 monedas, o sea 25 clicks.
    @Test func hirePricesFollowTheOwnersRule() throws {
        let economy = StandardEconomy(config: content.economy)
        let alley = content.floorTable[0]
        // El primer Fisura sigue costando 25 (decisión cerrada del dueño). Su
        // frontera al empezar la partida es T1 —el Fisura con el que arrancás—,
        // así que el ancla nueva no lo mueve. El SEGUNDO sigue al knob por
        // compra del CALLEJÓN: 30 con el 20% global, 26,5 con el 6% global y
        // **25,75 con el 3% del piso** (quinta ronda).
        #expect(content.economy.hireCost(floor: alley, tier: 1, frontierTier: 1, purchases: 0) == 25)
        let segundo = content.economy.hireCost(floor: alley, tier: 1, frontierTier: 1, purchases: 1)
        #expect(abs(segundo - 25.75) < 1e-9)

        // 1. Contratar A TU FRONTERA cuesta el multiplicador del piso, en clicks.
        for ordinal in 0..<content.floorTable.count {
            let floor = content.floorTable[ordinal]
            for tier in floor.firstTier...floor.lastTier {
                let precio = content.economy.hireCost(
                    floor: floor, tier: tier, frontierTier: tier, purchases: 0
                )
                // Lo que RINDE un click ahí, con el MISMO factor de piso que
                // cobra `applyTap`. Vale para cualquier valor futuro de
                // `tapFloorMultiplierExponent`.
                let click = economy.tapYield(forTier: tier)
                    * content.economy.tapFloorMultiplier(for: floor)
                let clicks = precio / click
                // Del tier `frontierEscalationFromTier` para arriba se suma la
                // DESACELERACIÓN: tu propia frontera se encarece
                // `frontierEscalationPerTier` por tier. Es el renglón (3) de la
                // regla y es lo que pone densa la torre arriba.
                let escalada = pow(
                    content.economy.hire.frontierEscalationPerTier,
                    Double(max(0, tier - content.economy.hire.frontierEscalationFromTier))
                )
                let esperado = content.economy.hireCostMultiplier(for: floor) * escalada
                // Tolerancia RELATIVA y no absoluta: con la desaceleración el
                // número esperado llega a 600 × 1,6³⁰, y a esa escala un `1e-9`
                // absoluto mide el error de redondeo del `pow`, no la regla.
                #expect(
                    abs(clicks / esperado - 1) < 1e-12,
                    "\(floor.id) T\(tier): contratarlo son \(clicks) clicks, no \(esperado)"
                )
            }
        }

        // 2. Bajar un tier deja la unidad de frontera 2/1,5 = 1,33× más cara.
        //    Se mide DENTRO de cada multiplicador de piso: el único salto que lo
        //    rompe es el ancla del Fisura (25 contra 600), y ése tiene su propio
        //    test — `elDescuentoDelCallejonSeAgotaSolo`.
        let frontera = content.tiers.maxTier
        let unidadDeFrontera = { (tier: Int) -> Double in
            let floor = content.floorTable[content.floorTable.ordinal(forTier: tier)]
            return pow(2, Double(frontera - tier)) * content.economy.hireCost(
                floor: floor, tier: tier, frontierTier: frontera, purchases: 0
            )
        }
        for tier in 1..<frontera {
            let deAcá = content.floorTable[content.floorTable.ordinal(forTier: tier)]
            let deArriba = content.floorTable[content.floorTable.ordinal(forTier: tier + 1)]
            guard content.economy.hireCostMultiplier(for: deAcá)
                == content.economy.hireCostMultiplier(for: deArriba) else { continue }
            let masCaro = unidadDeFrontera(tier) / unidadDeFrontera(tier + 1)
            #expect(abs(masCaro - 2 / 1.5) < 1e-9, "T\(tier) → T\(tier + 1): ×\(masCaro)")
        }
    }

    /// **La cuesta pre-compuerta no puede tener un muro adentro.**
    ///
    /// Hasta que tu frontera llega a `gateTierDistance + 1` el Fisura es lo
    /// ÚNICO contratable: la compuerta no habilita un segundo tipo antes, y el
    /// tier base es su única exención. O sea que el arranque entero se paga con
    /// UNA curva, y el exponente de esa curva es el contador de compras de ese
    /// tipo — que **se duplica con cada tier**, porque subir uno pide `2^(f−1)`
    /// Fisuras. `growth^(2^k)` es una doble exponencial: no se nota abajo y
    /// arriba se lleva puesto el juego.
    ///
    /// Medido con el 6 % que se embarcó hasta el 2026-08-28, en clicks de tu
    /// propia frontera (la unidad que ya usa `hirePricesFollowTheOwnersRule`,
    /// y la única comparable entre tiers porque el ingreso también sube):
    ///
    ///     26 · 39 · 61 · 117 · 322 · 1.931 · 61.921
    ///     ×1,5 · ×1,6 · ×1,9 · ×2,8 · ×6,0 · ×32,1
    ///
    /// Los primeros seis tiers son 2.500 clicks entre todos y el séptimo son
    /// 62.000 él solo: **a 3 taps/s eso es pasar de 14 minutos a 5 horas y
    /// media, en un paso**. Eso no es una curva de dificultad, es un muro — y
    /// cae justo en el tier 8, que es donde el dueño se trabó.
    ///
    /// El tope es ×8 y no ×32: deja pasar el 3 % embarcado (×6,1) con aire, y
    /// carnea cualquier vuelta al 4 % (×10,5) o al 6 %. No pinea el valor del
    /// knob sino **la forma** —que ningún tier del arranque cueste un orden de
    /// magnitud más que el anterior—, que es lo que la banda de pacing no puede
    /// ver: el simulador cronometra esta fase en 96 s porque su bot tapea a 6/s
    /// con todas las mejoras puestas, así que el muro le pasa por al lado.
    @Test("ningún tier de la cuesta pre-compuerta cuesta 8× el anterior")
    func thePreGateClimbHasNoWallInIt() throws {
        let economy = StandardEconomy(config: content.economy)
        let alley = content.floorTable[0]
        let click = { (frontera: Int) in
            economy.tapYield(forTier: frontera) * content.economy.tapFloorMultiplier(for: alley)
        }
        // Subir de `frontera` a `frontera + 1` pide `2^(frontera−1)` Fisuras, y
        // se compran con el contador ya corrido por las de los tiers de abajo:
        // ésa es la parte que compone.
        let cuesta = { (frontera: Int) -> Double in
            let compras = 1 << (frontera - 1)
            let total = (compras..<(compras * 2)).reduce(0.0) { suma, n in
                suma + content.economy.hireCost(
                    floor: alley, tier: alley.firstTier, frontierTier: frontera, purchases: Double(n)
                )
            }
            return total / click(frontera)
        }

        // El último tier de la fase es aquel cuya frontera recién habilita un
        // segundo tipo: de ahí en más el contador se reparte y deja de componer.
        let última = 1 + content.economy.hire.gateTierDistance
        let escalones = (1...última).map(cuesta)
        for (tier, (anterior, siguiente)) in zip(1..., zip(escalones, escalones.dropFirst())) {
            let salto = siguiente / anterior
            #expect(
                salto <= 8,
                "muro en T\(tier + 1) → T\(tier + 2): ×\(salto) (\(siguiente) clicks contra \(anterior))"
            )
        }
    }

    /// **La única costura de la regla, y es el precio de una decisión cerrada.**
    ///
    /// El callejón cotiza con 25 y los otros nueve pisos con 600, así que
    /// comprar en el callejón sale 24× menos y el punto 2 de la regla no vale al
    /// cruzar esa frontera. Es a propósito: el Fisura a 25 es el motor del early
    /// game y el tutorial lo enseña.
    ///
    /// Lo que hace que la costura no rompa el balance es que **el descuento no
    /// compone**: comprar el tope del callejón (T4) y subir mergeando sale
    /// `25 × 1,33^(frontera − 4)`, que CRECE con la frontera, mientras que
    /// comprar lo más alto que la compuerta habilita sale `600 × 1,33^N` y es
    /// constante. El callejón deja de ser el camino barato en el **tier 22** de
    /// 37 —a mitad de la torre— y con el tier 10, que es la primera frontera que
    /// habilita el tope del callejón, el descuento vale exactamente 24× (600/25:
    /// las dos ramas llevan el mismo `1,33^6` y sólo queda el multiplicador).
    /// Está medido en la cuarta ronda y este test lo pinea.
    @Test func elDescuentoDelCallejonSeAgotaSolo() throws {
        let alley = content.floorTable[0]
        #expect(content.economy.hireCostMultiplier(for: alley) == 25)
        #expect(content.economy.hire.defaultCostMultiplier == 600)

        // Lo que cuesta una unidad de tu frontera por los dos caminos, en
        // múltiplos de lo que rinde un click de esa frontera (el factor
        // `tapYield(frontera)` es común a los dos y se cancela).
        let pendiente = content.economy.hire.priceGrowthPerTier
        let porElCallejón = { (frontera: Int) in
            25 * pow(2 / pendiente, Double(frontera - alley.lastTier))
        }
        let porLaCompuerta = 600 * pow(2 / pendiente, Double(content.economy.hire.gateTierDistance))

        // Con la frontera en 9 —la primera que habilita el tope del callejón— el
        // descuento es exactamente el cociente de multiplicadores, 600/25 = 24.
        let primeraFrontera = alley.lastTier + content.economy.hire.gateTierDistance
        #expect(abs(porLaCompuerta / porElCallejón(primeraFrontera) - 24) < 1e-9)
        // Y se da vuelta a mitad de la torre.
        let cruce = try #require((5...content.tiers.maxTier).first { porElCallejón($0) >= porLaCompuerta })
        #expect(cruce == 22, "el callejón deja de ser el camino barato en el tier \(cruce)")
    }

    @Test func towerFloorsMatchCalibratedLayout() throws {
        // Layout FINAL de La Torre: 10 pisos data-driven, del callejón al reino
        // divino, capacity 10 en todos e income estrictamente creciente.
        // El `incomeMultiplier` es una progresión geométrica interpolada, no
        // inventada: va de 1,0 a 620,0 en 9 saltos, o sea razón 620^(1/9) =
        // 2,0431 redondeada al estilo de la tabla vieja.
        let expected: [(id: String, tiers: ClosedRange<Int>, income: Double)] = [
            ("alley", 1...4, 1.0),
            ("urban", 5...8, 2.0),
            ("corporate", 9...12, 4.2),
            ("luxury", 13...16, 8.5),
            ("island", 17...20, 17.0),
            ("moon", 21...24, 35.0),
            ("mars", 25...28, 72.0),
            ("solar", 29...32, 150.0),
            ("galaxy", 33...36, 305.0),
            ("god_realm", 37...37, 620.0),
        ]
        let table = content.floorTable
        try #require(table.count == expected.count)
        for (floor, pin) in zip(table.floors, expected) {
            #expect(floor.id == pin.id)
            #expect(floor.firstTier == pin.tiers.lowerBound, "\(pin.id).firstTier")
            #expect(floor.lastTier == pin.tiers.upperBound, "\(pin.id).lastTier")
            #expect(floor.capacity == 10, "\(pin.id).capacity")
            expectRelativelyEqual(floor.incomeMultiplier, pin.income, context: "\(pin.id).incomeMultiplier")
        }
        // Estrictamente creciente: un piso más alto SIEMPRE rinde más.
        for (lower, upper) in zip(table.floors, table.floors.dropFirst()) {
            #expect(lower.incomeMultiplier < upper.incomeMultiplier, "income no crece de \(lower.id) a \(upper.id)")
        }
        // Cobertura exacta 1...maxTier, sin huecos ni solapes. FloorTable ya lo
        // valida en su init; esto es anti-regresión por si esa validación se relaja.
        #expect(table.floors.first?.firstTier == 1)
        for (lower, upper) in zip(table.floors, table.floors.dropFirst()) {
            #expect(upper.firstTier == lower.lastTier + 1, "hueco o solape entre \(lower.id) y \(upper.id)")
        }
        #expect(table.floors.last?.lastTier == content.tiers.maxTier)
    }

    /// Todo fondo referenciado por un piso tiene que tener arte en el manifest
    /// (el loader ya lo exige al arrancar; acá queda documentado como contrato).
    @Test func floorBackgroundsExistInManifest() {
        for floor in content.floorTable.floors {
            #expect(
                content.manifest.backgrounds[floor.background] != nil,
                "piso \(floor.id): fondo \(floor.background) sin entrada en manifest.backgrounds"
            )
        }
    }

    /// Los servicios que F6 enciende a mano siguen apagados en el árbol.
    ///
    /// ⚠️ `useRealAds` salió de esta lista el 2026-09-02: con la rama A
    /// confirmada (AdMob real) el valor embarcado es `true`, y lo que hay que
    /// cuidar dejó de ser "que esté apagado" y pasó a ser **la coherencia entre
    /// el proveedor y lo que la tienda vende** — eso lo prueba
    /// `theStoreDoesNotSellRemovingAdsThatDoNotExist`, abajo.
    @Test func featureFlagsShipDisabled() {
        #expect(content.flags.gameCenterEnabled == false)
        #expect(content.flags.cloudKitEnabled == false)
        #expect(content.flags.buildVariant == "dev")
    }

    /// **La incoherencia que se puede embarcar sin que nada falle**, y por eso
    /// tiene test propio: la tienda vende `remove_ads`, y con `useRealAds` en
    /// `false` el juego corre con `StubAdsProvider` — un "anuncio" de 2 s que
    /// paga el premio sin mostrar publicidad. En ese estado la app cobra 2,99
    /// por sacar algo que no existe, que es lo que la guideline 2.3.1 llama
    /// engañoso.
    ///
    /// No hay forma de que el compilador lo note: son un JSON y un catálogo de
    /// productos que no se conocen entre sí.
    @Test func theStoreDoesNotSellRemovingAdsThatDoNotExist() throws {
        // El catálogo NO vive en `GameContent`: lo carga `StoreManager` por su
        // cuenta desde `products.json`. Por eso se lee acá igual que allá — y
        // por eso mismo la incoherencia era invisible: son dos configuraciones
        // que nadie cruzaba.
        let catalog = try ProductCatalog.load(from: .main)
        guard !catalog.removeAdsProductIDs.isEmpty else { return }
        #expect(
            content.flags.useRealAds,
            """
            La tienda vende remove_ads pero `useRealAds` está en false: el juego \
            correría con el proveedor stub y estaría cobrando por sacar una \
            publicidad que no se muestra. O se prende `useRealAds`, o \
            `remove_ads` sale del catálogo (rama B de Docs/ads-integration.md).
            """
        )
        // Y la mitad que se olvida: los rewarded son OPT-IN por política de
        // Google, así que no son lo que `remove_ads` saca. Lo único
        // interruptivo del juego es el interstitial; sin su unidad declarada,
        // el producto no tiene nada que quitar.
        #expect(
            content.flags.declaredAdUnitIDs.interstitial != nil,
            """
            La tienda vende remove_ads pero no hay unidad de interstitial \
            declarada en feature_flags.json. Los rewarded son opt-in y NO se \
            quitan con esa compra, así que el producto no sacaría nada: hay que \
            crear la unidad de interstitial en AdMob, o sacar remove_ads (y el \
            starter_pack, que también lo otorga) del catálogo.
            """
        )
    }

    /// Un build de tienda no puede salir con los ad unit IDs de prueba de
    /// Google: sirven anuncios de relleno y no pagan un centavo. Es un cambio
    /// de dos strings en `feature_flags.json` que **no rompe nada** si se
    /// olvida — la app funciona igual, sólo no factura.
    @Test func storeBuildsUseRealAdUnitIDs() {
        guard content.flags.isStoreBuild, content.flags.useRealAds else { return }
        #expect(
            !content.flags.declaredAdUnitIDs.usesAnyGoogleTestID,
            """
            buildVariant es "store" pero los ad unit IDs son los de prueba \
            públicos de Google. Poné los de la cuenta real en \
            feature_flags.json (y el App ID real en FisuEvolution/Info.plist).
            """
        )
    }

    /// El arte entra por tandas: cada entrada del manifest debe apuntar a un
    /// tipo real; los tipos sin entrada renderizan placeholder (regla de oro).
    @Test func manifestEntriesReferenceRealTypes() {
        // Una entrada de personaje debe apuntar a un tier real O a un special
        // real (los specials tienen arte propio en specials.atlas, no son tiers).
        let specialIds = Set(content.specials.specials.map(\.id))
        for (typeId, asset) in content.manifest.characters {
            let isReal = content.tiers.type(id: typeId) != nil || specialIds.contains(typeId)
            #expect(isReal, "manifest huérfano: \(typeId)")
            #expect(!asset.key.isEmpty)
            #expect(!asset.atlas.isEmpty)
        }
    }

    @Test func skinCatalogReferencesBundledTypesAndFloors() {
        #expect(content.skins.schemaVersion == 1)
        #expect(content.skins.skins.count >= 5)
        for skin in content.skins.skins {
            #expect(
                skin.characterType == "*" || content.tiers.type(id: skin.characterType) != nil,
                "skin \(skin.id): tipo desconocido \(skin.characterType)"
            )
            if let floor = skin.floorReached {
                #expect(content.floorTable.floors.contains { $0.id == floor }, "skin \(skin.id): piso desconocido \(floor)")
            }
        }
    }

    /// Las 41 pintas de piso ya no se regalan al llegar: las reparte el cofre, y
    /// su rareza sale del piso donde VIVE el personaje (no del `floorReached`
    /// viejo, que apuntaba al piso siguiente). Los totales solos no alcanzan —
    /// una entrada mal clasificada pasaría mientras otra compense—, así que
    /// abajo se recalcula la rareza desde el tier de cada personaje.
    @Test("las 41 pintas de piso son de cofre, con la rareza del piso donde vive el personaje")
    func chestPoolMatchesTheDesignedRarities() throws {
        let pool = content.skins.chestPool

        // Lo que ataja de verdad una migración a medias es esto: una entrada que
        // se quedó con `floorReached` no entra a la bolsa y el conteo se cae.
        #expect(pool.count == 41)
        // Las dos de acá abajo NO pueden fallar, y quedan como documentación del
        // invariante: el `init()` de la suite carga con `GameContentLoader`, que
        // corre `skins.validate(...)`, que ya tira `chestAndMilestone` para este
        // caso exacto — o sea que el load explotaría antes de llegar hasta acá.
        #expect(content.skins.skins.allSatisfy { $0.floorReached == nil || $0.chestRarity == nil })
        #expect(pool.allSatisfy { !$0.isMilestone })

        let esperado: [SkinsConfig.Rarity: Int] = [.comun: 7, .rara: 14, .epica: 12, .legendaria: 8]
        for (rareza, cuantas) in esperado {
            #expect(pool.filter { $0.chestRarity == rareza }.count == cuantas, "\(rareza)")
        }

        let porPiso: [String: SkinsConfig.Rarity] = [
            "alley": .comun, "urban": .comun,
            "corporate": .rara, "luxury": .rara,
            "island": .epica, "moon": .epica, "mars": .epica,
            "solar": .legendaria, "galaxy": .legendaria,
        ]
        for skin in pool {
            let tier = try #require(content.tiers.type(id: skin.characterType)).tier
            let piso = content.floorTable.floor(forTier: tier)
            #expect(skin.chestRarity == porPiso[piso.id], "\(skin.characterType) (T\(tier), \(piso.id))")
        }
    }

    @Test("los packs de plata pagan los minutos del dueño: 1 h, 6 h y 24 h, y el starter 4 h")
    func coinPacksPayTheOwnersMinutes() throws {
        let catalog = try ProductCatalog.load(from: .main)
        let minutes = Dictionary(uniqueKeysWithValues: catalog.products.compactMap { entry in
            entry.coinMinutes.map { (entry.id, $0) }
        })
        #expect(minutes == [
            "com.fisuevolution.iap.starter_pack": 240,
            "com.fisuevolution.iap.coins_small": 60,
            "com.fisuevolution.iap.coins_medium": 360,
            "com.fisuevolution.iap.coins_large": 1440,
        ])
    }

    @Test("chests.json trae los pesos y los minutos del dueño")
    func chestConfigMatchesTunedValues() {
        let chests = content.chests
        #expect(chests.weight(for: .comun) == 55)
        #expect(chests.weight(for: .rara) == 28)
        #expect(chests.weight(for: .epica) == 12)
        #expect(chests.weight(for: .legendaria) == 5)
        #expect(chests.floorsPerChest == 2)
        #expect(chests.completedPayoutMinutes == 20)
        #expect(chests.prestigePayoutMinutes == 45)
        // La pinta del cofre de bienvenida tiene que existir en la bolsa: un id mal
        // escrito acá deja el cofre del tutorial sin premio y nada más lo diría.
        #expect(content.skins.chestPool.contains { $0.id == chests.welcomeSkinId })
    }

    /// La pinta del cofre de bienvenida es **del personaje que el jugador acaba
    /// de fabricar con sus manos**, y eso se computa: el tipo base fusionado una
    /// vez. Nada de literales — si mañana cambia la cadena de evolución, esto
    /// sigue midiendo la intención y no un id escrito a mano.
    ///
    /// ⚠️ Este test existe porque el agujero era REAL y estuvo abierto: el
    /// `welcomeSkinId` apuntó a la pinta del Cartonero (T4) mientras la fase
    /// obligatoria del tutorial termina en el Trapito (T2), y **ningún test de la
    /// suite lo notaba** — los unitarios del cofre leen el id del config (que es
    /// lo correcto: prueban el mecanismo, no el contenido) y el de acá al lado
    /// sólo pedía que estuviera en la bolsa.
    ///
    /// Lo que se rompía no era una animación: la carta del premio anunciaba a un
    /// personaje que el jugador no conoció, y Pintas —que abre en el de tier más
    /// alto VISTO— aterrizaba en otro, dejando la pinta recién ganada a un toque
    /// de carrusel. Con la pinta alineada al aterrizaje, las dos cosas se
    /// arreglan solas.
    /// Las dos cartas de premio del juego componen el nombre del personaje, y
    /// **ninguna puede duplicar el artículo**.
    ///
    /// ⚠️ Este test existe porque el bug SHIPPEÓ y nadie lo vio.
    /// `chest.skin.subtitle` decía `"Para tu %@."` / `"For your %@."`, y **tres
    /// de los 44** nombres ya traen artículo —El Fisura / The Hobo, El Trapito /
    /// The Fake Valet, El Mantero / The Bootleg Vendor—, así que la carta leía
    /// *"Para tu El Trapito."*. Ninguna prueba resolvía esa clave, y el cofre de
    /// bienvenida —que es justo del Trapito— lo puso en el minuto 2 de TODAS las
    /// partidas nuevas.
    ///
    /// La carta hermana (`skin.award.subtitle`, la de las pintas de milestone)
    /// nunca lo tuvo porque va **sin posesivo**; el arreglo alineó las dos en vez
    /// de inventar una forma nueva. Esto es lo que impide que vuelva el posesivo.
    ///
    /// Recorre el catálogo entero y no una lista escrita a mano: un personaje
    /// nuevo con artículo queda cubierto sin tocar el test.
    @Test("ninguna carta de premio duplica el artículo con ningún personaje")
    func noPrizeSubtitleDoublesTheArticle() {
        // Los dos idiomas en la misma lista a propósito: el host de los tests
        // resuelve en UNO solo y cuál depende de dónde corra (trampa 6), así que
        // se chequean los dos patrones contra el string ya resuelto en vez de
        // asumir el idioma de la corrida.
        let duplicados = ["tu el ", "tu la ", "tu los ", "tu las ",
                          "your the ", "your a ", "your an "]
        for type in content.tiers.concreteTypes {
            let frases = [
                String(localized: "chest.skin.subtitle \(type.localizedName)"),
                String(localized: "skin.award.subtitle \(type.localizedName)"),
            ]
            for frase in frases {
                // ⚠️ **La red de la red, y no es decoración.** Si la clave no
                // resolviera, `frase` volvería siendo la clave cruda y los
                // `contains` de abajo pasarían TODOS por la razón equivocada —
                // el test quedaría verde sin haber mirado una sola frase. Es el
                // mismo guardián que `theChestCardCopyIsResolved` pone sobre las
                // copys de Regalos.
                #expect(frase.contains(type.localizedName),
                        "la clave no resolvió: '\(frase)' no nombra a \(type.id)")
                #expect(!frase.contains("subtitle"),
                        "quedó una clave cruda en pantalla: '\(frase)'")

                let plana = frase.lowercased()
                for duplicado in duplicados {
                    #expect(
                        !plana.contains(duplicado),
                        "artículo duplicado con \(type.id): '\(frase)'"
                    )
                }
            }
        }
    }

    @Test("la pinta de bienvenida es del personaje en el que termina el tutorial")
    func theWelcomeSkinBelongsToTheFirstMergeResult() throws {
        let base = content.tiers.baseType
        let trasLaPrimeraFusion = try #require(
            base.mergesInto, "el tipo base tiene que fusionar en alguien: es el paso 3 del tutorial"
        )
        let pinta = try #require(
            content.skins.chestPool.first { $0.id == content.chests.welcomeSkinId },
            "el id de bienvenida tiene que estar en la bolsa del cofre"
        )
        #expect(
            pinta.characterType == trasLaPrimeraFusion,
            """
            el cofre de bienvenida regala una pinta de '\(pinta.characterType)', \
            pero la fase obligatoria del tutorial termina en '\(trasLaPrimeraFusion)'
            """
        )
    }

    /// Cada personaje concreto tiene su skin alternativa catalogada, y todas
    /// declaran nombre visible: una skin sin `displayNameKey` se vería en la
    /// ficha como su id crudo.
    @Test func everyCharacterHasACataloguedSkinWithAName() throws {
        let textureSkins = content.skins.skins.filter { $0.treatment == .texture }
        let covered = Set(textureSkins.map(\.characterType))
        for type in content.tiers.concreteTypes {
            #expect(covered.contains(type.id), "el personaje \(type.id) no tiene skin catalogada")
        }
        for skin in content.skins.skins {
            let key = try #require(skin.displayNameKey, "skin \(skin.id): sin displayNameKey")
            #expect(key == "skin.name.\(skin.id)")
        }
    }

    /// El nombre del personaje sale de `tiers.json`, que es **dato en
    /// castellano**: dibujado tal cual, el juego en inglés mostraba "El Fisura".
    /// La traducción vive en `tier.name.<id>` y este test es lo único que la
    /// mantiene completa — `localizedName` cae al castellano del dato cuando
    /// falta la clave, así que un tier nuevo se shippearía en castellano en
    /// silencio, que es exactamente el bug que esto arregló.
    ///
    /// Los dos bundles se abren a mano porque `Bundle.main` sólo responde en el
    /// idioma con el que corre el runner (inglés, trampa 6): preguntarle a él
    /// dejaría el castellano sin chequear.
    @Test("cada tier tiene su nombre en los dos idiomas y el castellano es el del dato")
    func everyTierHasItsNameInBothLanguages() throws {
        let missing = "(falta)"
        for language in ["es", "en"] {
            let path = try #require(Bundle.main.path(forResource: language, ofType: "lproj"))
            let bundle = try #require(Bundle(path: path))
            for type in content.tiers.types {
                let key = "tier.name.\(type.id)"
                let name = bundle.localizedString(forKey: key, value: missing, table: nil)
                #expect(name != missing, "\(key): sin nombre en \(language)")
                if language == "es" {
                    #expect(name == type.displayName, "\(key): el catálogo se separó de tiers.json")
                }
            }
        }
    }

    /// La convención de textura es `<baseKey>__<skinId>` (spec §5): el arte de
    /// una skin vive en el atlas de SU personaje, con el `__` DESPUÉS de `_idle`.
    /// Romperla no falla en runtime —hay fallback a la base— pero deja la skin
    /// invisible para siempre, que es peor: por eso se asserta acá.
    @Test func textureSkinKeysFollowTheNamingConvention() throws {
        for skin in content.skins.skins where skin.treatment == .texture {
            let key = try #require(skin.textureKey, "skin \(skin.id): texture sin textureKey")
            let asset = try #require(
                content.manifest.characters[skin.characterType],
                "skin \(skin.id): su personaje no tiene arte base en el manifest"
            )
            #expect(key == "\(asset.key)__\(skin.id)", "skin \(skin.id): textureKey fuera de convención (\(key))")
        }
    }

    /// El contrato que permite shippear catálogo y arte por separado: una skin
    /// cuyo PNG todavía no existe DEBE caer a la textura base, nunca a un
    /// placeholder roto. Vale antes y después de que entre el arte.
    @MainActor
    @Test func missingSkinArtFallsBackToTheBaseTexture() throws {
        let renderer = PlaceholderRenderer()
        for skin in content.skins.skins where skin.treatment == .texture {
            guard let type = content.tiers.type(id: skin.characterType) else { continue }
            let texture = try #require(
                renderer.texture(for: type, manifest: content.manifest, skinTextureKey: skin.textureKey),
                "skin \(skin.id): el renderer no devolvió textura"
            )
            // Sirve el arte de la skin si existe y la base si todavía no: en
            // ningún caso una textura inválida (0x0) que se vería como un hueco.
            #expect(texture.size().width > 1, "skin \(skin.id): textura inválida servida")
            #expect(texture.size().height > 1, "skin \(skin.id): textura inválida servida")
        }
    }

    @Test @MainActor func skinResolverIsDataDrivenAndScopedToCharacterType() {
        let config = SkinsConfig(
            schemaVersion: 1,
            skins: [
                .init(id: "golden", characterType: "*", treatment: .tint, tintHex: "#FFD93D", textureKey: nil, floorReached: nil, reincarnations: nil),
                .init(id: "urban", characterType: "cartonero", treatment: .texture, tintHex: nil, textureKey: "cartonero_idle__urban", floorReached: "urban", reincarnations: nil),
            ]
        )

        #expect(SkinResolver.treatment(for: nil, characterType: "homeless", config: config) == .base)
        #expect(SkinResolver.treatment(for: "golden", characterType: "homeless", config: config) == .tint(hex: "#FFD93D"))
        #expect(SkinResolver.treatment(for: "urban", characterType: "cartonero", config: config) == .texture(key: "cartonero_idle__urban"))
        // Un ID válido pero ajeno a la ficha vuelve a la base, sin filtrarse a
        // otro personaje ni mostrar una textura inválida.
        #expect(SkinResolver.treatment(for: "urban", characterType: "homeless", config: config) == .base)
    }

    /// El drill de remapeo contra el contenido REAL: un save escrito con el
    /// mapeo de 11 pisos tiene unidades de `kiosco`, que ya no existe. Tiene que
    /// cargar, descartar sólo esas y reacomodar el resto contra el mapeo
    /// vigente. `TowerReconciler` se construyó exactamente para esto, así que
    /// pasa de una: se deja igual porque es la red del PRÓXIMO remapeo.
    @Test("un save con el mapeo de 11 pisos carga y reacomoda sus unidades")
    func oldSaveSurvivesTheRemap() throws {
        var state = PlayerState.newGame(
            startTypeId: "homeless",
            startFloorId: "alley",
            offlineEfficiencyBase: content.economy.offlineEfficiencyBase,
            critChanceBase: content.economy.critChanceBase,
            now: 1_700_000_000
        )
        // Un tipo que sigue existiendo y otro que se eliminó en este remapeo.
        state.run.units = ["homeless": 3, "kiosco": 2]

        let outcome = TowerReconciler.reconcile(
            run: &state.run,
            floorTable: content.floorTable,
            tiers: content.tiers
        )

        #expect(outcome.discarded == ["kiosco": 2], "las unidades de un tipo eliminado se descartan, no rompen la carga")
        #expect(state.run.units == ["homeless": 3], "kiosco tiene que salir de units, no quedar de zombi")
        #expect(outcome.tower.unitCounts == state.run.units)
        // Y el Fisura queda parado en el callejón, que es donde lo pone el
        // mapeo NUEVO (T1 sigue en `alley`, ahora 1…4 en vez de 1…2).
        #expect(content.floorTable.ordinal(forTier: 1) == 0)
    }

    private func expectRelativelyEqual(_ actual: Double, _ expected: Double, context: String) {
        let tolerance = max(abs(expected), 1) * 1e-9
        #expect(abs(actual - expected) <= tolerance, "\(context): \(actual) != \(expected)")
    }
}
