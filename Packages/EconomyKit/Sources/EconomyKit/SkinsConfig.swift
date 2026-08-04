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
            displayNameKey: String? = nil
        ) {
            self.id = id
            self.characterType = characterType
            self.treatment = treatment
            self.tintHex = tintHex
            self.textureKey = textureKey
            self.floorReached = floorReached
            self.reincarnations = reincarnations
            self.displayNameKey = displayNameKey
        }

        public var isMilestone: Bool { floorReached != nil || reincarnations != nil }
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
        var ids = Set<String>()
        for skin in skins {
            guard ids.insert(skin.id).inserted else { throw ValidationError.duplicateID(skin.id) }
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
    public static func newlyUnlocked(state: PlayerState, config: SkinsConfig) -> [String] {
        let owned = state.meta.allOwnedSkins
        return config.skins.compactMap { skin in
            guard skin.isMilestone, !owned.contains(skin.id) else { return nil }
            let reachedFloor = skin.floorReached.map { state.run.unlockedFloors.contains($0) } ?? true
            let reachedPrestige = skin.reincarnations.map { state.meta.prestigeLevel >= $0 } ?? true
            return reachedFloor && reachedPrestige ? skin.id : nil
        }
    }
}
