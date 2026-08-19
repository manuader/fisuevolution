import Foundation

/// Catálogo de skins F7.5. La UI y SpriteKit nunca conocen IDs particulares:
/// una entrada puede aplicar a un tipo o a todos (`characterType == "*"`).
public struct SkinsConfig: Codable, Sendable, Equatable {
    public enum Treatment: String, Codable, Sendable {
        case tint
        case texture
    }

    public struct Entry: Codable, Sendable, Equatable, Identifiable {
        public let id: String
        public let characterType: String
        public let treatment: Treatment
        /// Color hexadecimal para tratamientos `tint`.
        public let tintHex: String?
        /// Key de atlas para `texture`; si no existe el arte, el renderer usa
        /// la textura base sin hacer visible un placeholder roto.
        public let textureKey: String?
        /// ID del piso que desbloquea esta skin de milestone.
        public let floorReached: String?
        /// Reencarnaciones acumuladas que desbloquean esta skin de milestone.
        public let reincarnations: Int?
        /// Se desbloquea al tener TODAS las líneas de mejora permanente en su
        /// nivel máximo. Es la vía gratuita de las skins de oro; la de pago es
        /// el paquete, que las entrega por `ownedSkins`.
        public let upgradesMaxed: Bool?
        /// Clave de localización del nombre visible (spec §3.9). Opcional: sin
        /// ella la ficha muestra el id embellecido, que alcanza para una skin
        /// de prueba pero no para una que se shippea.
        public let displayNameKey: String?

        /// Los campos de tratamiento y de milestone son mutuamente excluyentes
        /// según el tipo de skin, así que van con default: declarar una entrada
        /// nueva no obliga a enumerar los cinco que no aplican.
        public init(
            id: String,
            characterType: String,
            treatment: Treatment,
            tintHex: String? = nil,
            textureKey: String? = nil,
            floorReached: String? = nil,
            reincarnations: Int? = nil,
            upgradesMaxed: Bool? = nil,
            displayNameKey: String? = nil
        ) {
            self.id = id
            self.characterType = characterType
            self.treatment = treatment
            self.tintHex = tintHex
            self.textureKey = textureKey
            self.floorReached = floorReached
            self.reincarnations = reincarnations
            self.upgradesMaxed = upgradesMaxed
            self.displayNameKey = displayNameKey
        }

        public var isMilestone: Bool {
            floorReached != nil || reincarnations != nil || upgradesMaxed == true
        }
    }

    public enum ValidationError: Error, Equatable {
        case duplicateID(String)
        case unknownCharacterType(String)
        case unknownFloor(String)
        case missingTint(String)
        case missingTexture(String)
        case invalidReincarnations(String)
    }

    public let schemaVersion: Int
    public let skins: [Entry]

    public init(schemaVersion: Int, skins: [Entry]) {
        self.schemaVersion = schemaVersion
        self.skins = skins
    }

    public func entry(id: String) -> Entry? {
        skins.first { $0.id == id }
    }

    /// Orden estable de catálogo: globales primero, luego las específicas.
    public func entries(forCharacterType typeID: String) -> [Entry] {
        skins.filter { $0.characterType == "*" || $0.characterType == typeID }
    }

    public func validate(characterTypeIDs: Set<String>, floorIDs: Set<String>) throws {
        // La unicidad es por (personaje, id), no por id global. Una variante como
        // "oro" existe una vez por personaje, y que las 43 compartan el id es
        // justamente lo que hace que un solo paquete las desbloquee todas: la
        // propiedad se guarda por id en `allOwnedSkins`, así que tener "oro"
        // significa tenerlo en todos. Con unicidad global habría que inventar
        // ids por personaje y romper la convención `<baseKey>__<skinId>`.
        var vistas = Set<String>()
        for skin in skins {
            guard vistas.insert("\(skin.characterType)/\(skin.id)").inserted else {
                throw ValidationError.duplicateID(skin.id)
            }
            guard skin.characterType == "*" || characterTypeIDs.contains(skin.characterType) else {
                throw ValidationError.unknownCharacterType(skin.characterType)
            }
            if let floorReached = skin.floorReached, !floorIDs.contains(floorReached) {
                throw ValidationError.unknownFloor(floorReached)
            }
            if let reincarnations = skin.reincarnations, reincarnations < 1 {
                throw ValidationError.invalidReincarnations(skin.id)
            }
            switch skin.treatment {
            case .tint:
                guard skin.tintHex?.isEmpty == false else { throw ValidationError.missingTint(skin.id) }
            case .texture:
                guard skin.textureKey?.isEmpty == false else { throw ValidationError.missingTexture(skin.id) }
            }
        }
    }
}

/// Evaluador puro e idempotente de skins de milestone. StoreKit administra las
/// IAP en `ownedSkins`; este tipo sólo propone las que deben entrar en
/// `milestoneSkins` y por eso jamás pisa entitlements.
public enum SkinMilestones {
    /// `allUpgradesMaxed` lo calcula quien tiene el catálogo de mejoras a mano:
    /// EconomyKit no conoce `upgrades.json`, y pasarlo ya resuelto mantiene este
    /// evaluador puro en vez de arrastrarle otra dependencia.
    public static func newlyUnlocked(
        state: PlayerState,
        config: SkinsConfig,
        allUpgradesMaxed: Bool = false
    ) -> [String] {
        let owned = state.meta.allOwnedSkins
        return config.skins.compactMap { skin in
            guard skin.isMilestone, !owned.contains(skin.id) else { return nil }
            let reachedFloor = skin.floorReached.map { state.run.unlockedFloors.contains($0) } ?? true
            let reachedPrestige = skin.reincarnations.map { state.meta.prestigeLevel >= $0 } ?? true
            let reachedUpgrades = skin.upgradesMaxed == true ? allUpgradesMaxed : true
            return reachedFloor && reachedPrestige && reachedUpgrades ? skin.id : nil
        }
    }
}
