import Foundation

/// Qué salió de un cofre. `coins` lleva rareza igual porque la animación ya
/// pintó su color antes de saber el resultado: si el pago viniera sin rareza,
/// el latido del estallido tendría que elegir un color al azar.
public enum ChestOutcome: Sendable, Equatable {
    case skin(id: String, characterType: String, rarity: SkinsConfig.Rarity)
    case coins(rarity: SkinsConfig.Rarity)
}

/// El sorteo de un cofre. Puro y con RNG inyectado, como `special_roll`: los
/// tests fijan la semilla y el resultado es reproducible.
public enum ChestRoller {
    public static func roll(
        owned: Set<String>,
        skins: SkinsConfig,
        config: ChestsConfig,
        floor: SkinsConfig.Rarity? = nil,
        using rng: inout some RandomNumberGenerator
    ) -> ChestOutcome {
        let candidatas = SkinsConfig.Rarity.allCases.filter { $0 >= (floor ?? .comun) }
        let sorteada = weightedPick(candidatas, config: config, using: &rng) ?? .comun
        guard let resuelta = firstWithStock(from: sorteada, owned: owned, skins: skins) else {
            return .coins(rarity: sorteada)
        }
        let disponibles = stock(of: resuelta, owned: owned, skins: skins)
        // `randomElement(using:)` sobre un array ordenado por catálogo: el orden
        // de `chestPool` es estable, así que la semilla reproduce la tirada.
        let elegida = disponibles.randomElement(using: &rng)!
        return .skin(id: elegida.id, characterType: elegida.characterType, rarity: resuelta)
    }

    /// Sube a la primera rareza con stock; si arriba no hay ninguna, baja.
    ///
    /// Sube antes que bajar porque promocionar se lee como un regalo y degradar
    /// como un recorte, y porque deja las legendarias para el final: son las
    /// únicas que no reciben promociones de más arriba.
    private static func firstWithStock(
        from rarity: SkinsConfig.Rarity, owned: Set<String>, skins: SkinsConfig
    ) -> SkinsConfig.Rarity? {
        let arriba = SkinsConfig.Rarity.allCases.filter { $0 >= rarity }
        let abajo = SkinsConfig.Rarity.allCases.filter { $0 < rarity }.reversed()
        return (arriba + abajo).first { !stock(of: $0, owned: owned, skins: skins).isEmpty }
    }

    private static func stock(
        of rarity: SkinsConfig.Rarity, owned: Set<String>, skins: SkinsConfig
    ) -> [SkinsConfig.Entry] {
        skins.chestPool.filter { $0.chestRarity == rarity && !owned.contains($0.id) }
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
