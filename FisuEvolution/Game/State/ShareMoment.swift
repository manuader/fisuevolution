import EconomyKit

/// Un momento viral (PLAN-v2 E3): lo que se ofrece compartir cuando termina su
/// celebración, con la tarjeta vertical y un premio chico la primera vez.
enum ShareMoment: Equatable, Identifiable {
    case newCharacter(CharacterType)
    case newFloor(floorID: String)
    case reincarnation(level: Int)
    /// El último tier: la llegada a Dios.
    case god(CharacterType)

    /// Con esto se recuerda que ya se compartió (`engagement.sharedMoments`).
    var key: String {
        switch self {
        case .newCharacter(let type): "character.\(type.id)"
        case .newFloor(let floorID): "floor.\(floorID)"
        case .reincarnation(let level): "reincarnation.\(level)"
        case .god: "god"
        }
    }

    var id: String { key }

    /// Si dos caen en la misma celebración (un tier nuevo que abre un piso), se
    /// ofrece el más grande.
    var weight: Int {
        switch self {
        case .newCharacter: 1
        case .newFloor: 2
        case .reincarnation: 3
        case .god: 4
        }
    }
}
