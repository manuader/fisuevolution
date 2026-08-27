import Foundation

/// Catálogo de skins F7.5. La UI y SpriteKit nunca conocen IDs particulares:
/// una entrada puede aplicar a un tipo o a todos (`characterType == "*"`).
public struct SkinsConfig: Codable, Sendable, Equatable {
    public enum Treatment: String, Codable, Sendable {
        case tint
        case texture
    }

    /// Rareza de una skin de cofre. El orden de declaración es el de escalada:
    /// `ChestRoller` promociona hacia el siguiente caso cuando el sorteado se agota.
    public enum Rarity: String, Codable, Sendable, CaseIterable, Comparable {
        case comun, rara, epica, legendaria

        public static func < (lhs: Rarity, rhs: Rarity) -> Bool {
            allCases.firstIndex(of: lhs)! < allCases.firstIndex(of: rhs)!
        }
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
        /// Rareza si esta skin sale de un cofre. Excluyente con los tres criterios
        /// de milestone: con `chestRarity` puesto, `isMilestone` cae a `false` solo
        /// y `SkinMilestones` deja de proponerla sin tener que conocerla.
        public let chestRarity: Rarity?
        /// Clave de localización del nombre visible (spec §3.9). Opcional: sin
        /// ella la ficha muestra el id embellecido, que alcanza para una skin
        /// de prueba pero no para una que se shippea.
        public let displayNameKey: String?

        /// Los campos de tratamiento y de milestone son mutuamente excluyentes
        /// según el tipo de skin, así que van con default: declarar una entrada
        /// nueva no obliga a enumerar los seis que no aplican.
        public init(
            id: String,
            characterType: String,
            treatment: Treatment,
            tintHex: String? = nil,
            textureKey: String? = nil,
            floorReached: String? = nil,
            reincarnations: Int? = nil,
            upgradesMaxed: Bool? = nil,
            chestRarity: Rarity? = nil,
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
            self.chestRarity = chestRarity
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
        case chestAndMilestone(String)
    }

    public let schemaVersion: Int
    public let skins: [Entry]

    public init(schemaVersion: Int, skins: [Entry]) {
        self.schemaVersion = schemaVersion
        self.skins = skins
    }

    /// Las skins que reparten los cofres, en orden de catálogo.
    public var chestPool: [Entry] { skins.filter { $0.chestRarity != nil } }

    /// De quién es cada pinta, cuando es de UNO SOLO. Las que visten a todos no
    /// figuran: no alcanzan para decir a qué personaje pertenece la propiedad.
    ///
    /// ⚠️ "Vestir a todos" está escrito de **dos formas** en el catálogo y las
    /// dos tienen que caer del mismo lado. La declarada (`characterType == "*"`)
    /// y la que efectivamente se usa: el MISMO id repetido una vez por
    /// personaje, que es como viven `oro` y `diamante`. Lo segundo no es un
    /// descuido del dato — es la razón de que la unicidad se pida por
    /// (personaje, id) y no por id (ver `validate`): la propiedad se guarda por
    /// id en `allOwnedSkins`, así que tener "diamante" es tenerlo en los 43.
    ///
    /// Lo pregunta quien tiene que traducir "tengo esta pinta" en "entonces
    /// conozco a este personaje". Con las compartidas adentro, un solo paquete
    /// de diamante contestaría "conozco a los 43".
    public var exclusiveCharacterTypeBySkinID: [String: String] {
        var dueño: [String: String] = [:]
        var compartidas: Set<String> = []
        for skin in skins {
            if skin.characterType == "*" {
                compartidas.insert(skin.id)
            } else if let anterior = dueño[skin.id], anterior != skin.characterType {
                compartidas.insert(skin.id)
            } else {
                dueño[skin.id] = skin.characterType
            }
        }
        return dueño.filter { !compartidas.contains($0.key) }
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
            // Las dos vías reparten la misma skin: si una entrada declara ambas, el
            // jugador la cobraría al llegar al piso y el cofre después le sortearía
            // algo que ya tiene. El dato tiene que elegir una.
            if skin.chestRarity != nil, skin.isMilestone {
                throw ValidationError.chestAndMilestone(skin.id)
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
