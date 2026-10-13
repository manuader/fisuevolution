import EconomyKit
import SwiftUI

/// Qué imagen ilustra un premio (E14 C4): el mapa único de efecto → arte. Cada
/// caso tiene su clave nueva (`rw_*`, la de E14) y, mientras T3 no la integre,
/// una hermana del atlas que ya existe o, si no hay ninguna, un disco dibujado
/// con su marca.
enum RewardKind: String, CaseIterable, Sendable {
    case coins
    case incomeBoost
    case tapBoost
    case hireDiscount
    case boostRefresh
    case evolve
    case freeUnit
    case exchange
    case fine
    case arrest
    case frozen
    case blue
    case package
    case packageRain
    case chest
    case wheelSpin
    case gift
    /// El premio al azar antes de abrir (la Ruleta, el Colchón cerrado).
    case mystery
    case mattressTreasure

    /// La cadena de claves: la primera integrada gana.
    var artKeys: [String] {
        switch self {
        case .coins: ["rw_coins", "ui_coin"]
        case .incomeBoost: ["rw_income_mult"]
        case .tapBoost: ["rw_tap_mult"]
        case .hireDiscount: ["rw_hire_discount"]
        case .boostRefresh: ["rw_boost_refresh"]
        case .evolve: ["rw_evolve"]
        case .freeUnit: ["rw_free_unit"]
        case .exchange: ["rw_exchange"]
        case .fine: ["rw_fine"]
        case .arrest: ["rw_arrest"]
        case .frozen: ["rw_frozen"]
        case .blue: ["ui_dolar_blue", "ui_oro"]
        case .package: ["pickup_package_full"]
        case .packageRain: ["ui_oro_package_rain", "pickup_package_full"]
        case .chest: ["ui_chest_closed"]
        case .wheelSpin: ["wheel_icon"]
        case .gift: ["ui_gift_bow"]
        case .mystery: ["rw_mystery_all"]
        case .mattressTreasure: ["rw_mattress_treasure", "pickup_mattress_open"]
        }
    }

    /// La marca y el tono del disco dibujado, cuando ninguna clave está.
    var fallbackMark: (mark: String, tint: Color) {
        switch self {
        case .coins: ("$", Color("PaletteYellow"))
        case .incomeBoost: ("×2", Color("PaletteGreen"))
        case .tapBoost: ("×", Color("PaletteOrange"))
        case .hireDiscount: ("%", Color("PaletteOrange"))
        case .boostRefresh: ("↻", Color("PaletteBlue"))
        case .evolve: ("↑", Color("PaletteGreen"))
        case .freeUnit: ("+1", Color("PaletteGreen"))
        case .exchange: ("⇄", Color("PaletteBlue"))
        case .fine: ("−$", GameTint.alert)
        case .arrest: ("!", GameTint.alert)
        case .frozen: ("❄︎", Color("PaletteBlue"))
        case .blue: ("$", Color("PaletteBlue"))
        case .package, .packageRain: ("?", Color("PaletteBrown").lifted(0.3))
        case .chest: ("?", Color("PaletteOrange"))
        case .wheelSpin: ("★", Color("PalettePink"))
        case .gift: ("★", Color("PalettePink"))
        case .mystery: ("?", Color("PalettePink"))
        case .mattressTreasure: ("$", Color("PaletteYellow"))
        }
    }

    /// Lo negativo (multas, el arresto, el Corralito) va sin rayos dorados: los
    /// rayos celebran, y una multa no se festeja.
    var celebrates: Bool {
        switch self {
        case .fine, .arrest, .frozen: false
        default: true
        }
    }

    @MainActor
    var resolvedArtKey: String? {
        artKeys.first { UIArt.uiImage($0) != nil }
    }
}

// MARK: - Del vocabulario de premios a la imagen

extension RewardKind {
    /// El premio unificado de la 2.0. `nil` = no hay imagen que lo diga (C4:
    /// "si no da nada, sin imagen").
    init?(_ spec: RewardSpec) {
        switch spec {
        case .coinsSeconds: self = .coins
        case .oro: self = .blue
        case .package: self = .package
        case .skinChest: self = .chest
        case .modifier(let effect, _, _):
            guard let kind = RewardKind(modifier: effect) else { return nil }
            self = kind
        case .clearBoostCooldowns: self = .boostRefresh
        case .autoTap: self = .tapBoost
        case .nextOfflineMultiplier: self = .incomeBoost
        case .nextDailyMultiplier: self = .gift
        case .wheelSpin: self = .wheelSpin
        case .extraSlots, .eventImmunity: return nil
        }
    }

    /// Un modificador (eventos, boosts, ruleta).
    init?(modifier effect: ActiveModifier.Effect) {
        switch effect {
        case .incomeMultiplier, .passiveMultiplier: self = .incomeBoost
        case .tapMultiplier, .autoTapPerSecond: self = .tapBoost
        case .spawnCostMultiplier, .freeHire: self = .hireDiscount
        case .spendingFrozen: self = .frozen
        case .packageRateMultiplier: self = .packageRain
        case .eventImmunity, .eventPresence: return nil
        }
    }

    /// Un efecto de evento.
    init?(event effect: EventCatalog.Effect) {
        switch effect {
        case .modifier(let modifier, _):
            guard let kind = RewardKind(modifier: modifier) else { return nil }
            self = kind
        case .coinsSeconds: self = .coins
        case .evolveBestUnit: self = .evolve
        case .grantUnit: self = .freeUnit
        case .callVisitor: return nil
        }
    }

    /// Los nombres de efecto de los JSON (`visitors.json`, `events.json`,
    /// `wheel.json`), tal como los lista la tabla de C4.
    init?(effectName name: String) {
        switch name {
        case "coinsSeconds": self = .coins
        case "incomeMultiplier", "passiveMultiplier": self = .incomeBoost
        case "tapMultiplier": self = .tapBoost
        case "spawnCostMultiplier": self = .hireDiscount
        case "clearBoostCooldowns": self = .boostRefresh
        case "evolveBestUnit": self = .evolve
        case "grantUnit": self = .freeUnit
        case "exchange": self = .exchange
        case "fine", "fee", "take": self = .fine
        case "arrest": self = .arrest
        case "spendingFrozen": self = .frozen
        case "oro": self = .blue
        case "package": self = .package
        case "packageRateMultiplier": self = .packageRain
        case "skinChest": self = .chest
        case "wheelSpin": self = .wheelSpin
        case "gift": self = .gift
        default: return nil
        }
    }
}

// MARK: - La ilustración

/// El premio grande con los rayos detrás (C4), estilo Cow Evolution en la
/// paleta de la casa. El marco incluye los rayos —que se disuelven antes del
/// borde—, así que la ilustración no pisa a sus vecinos (D14).
///
/// Los rayos giran sólo mientras la vista está en pantalla (`TimelineView`, no
/// `repeatForever`) y con Reduce Motion quedan quietos.
struct RewardIllustration: View {
    let kind: RewardKind
    /// Lado del dibujo del premio; el marco con los rayos es `frameSide`.
    var size: CGFloat = 120
    var spinsRays = true

    /// El marco total: el premio más el aire de los rayos.
    static func frameSide(for size: CGFloat) -> CGFloat { (size * 1.5).rounded() }

    var body: some View {
        ZStack {
            if kind.celebrates {
                RewardRays(spins: spinsRays)
            }
            art
                .frame(width: size, height: size)
                .shadow(color: .black.opacity(0.18), radius: 6, y: 3)
        }
        .frame(width: Self.frameSide(for: size), height: Self.frameSide(for: size))
        .accessibilityHidden(true)
    }

    @ViewBuilder private var art: some View {
        if let key = kind.resolvedArtKey, let image = UIArt.image(key) {
            image.resizable().scaledToFit()
        } else {
            IconCanvas {
                MarkDisc(mark: kind.fallbackMark.mark, fill: kind.fallbackMark.tint)
            }
        }
    }
}

/// Los rayos: gajos amarillos alternados, disueltos hacia afuera.
struct RewardRays: View {
    var spins = true
    var rays = 16
    var tint = Color("PaletteYellow")

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // La máscara es radial: no gira, así que vive afuera del reloj y no se
        // recalcula en cada cuadro.
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !spins || reduceMotion)) { timeline in
            let seconds = timeline.date.timeIntervalSinceReferenceDate
            let angle = spins && !reduceMotion ? (seconds * 18).truncatingRemainder(dividingBy: 360) : 0
            RayFan(rays: rays)
                .fill(tint.opacity(0.75))
                .rotationEffect(.degrees(angle))
        }
        .drawingGroup()
        .mask {
            GeometryReader { geo in
                RadialGradient(
                    colors: [.black, .black.opacity(0.55), .clear],
                    center: .center,
                    startRadius: geo.size.width * 0.12,
                    endRadius: geo.size.width * 0.5
                )
            }
        }
        .accessibilityHidden(true)
    }
}

/// `rays` gajos de ancho igual al hueco que los separa.
struct RayFan: Shape {
    var rays = 16

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = hypot(rect.width, rect.height) / 2
        let step = 2 * Double.pi / Double(max(rays, 1))
        var path = Path()
        for index in 0..<max(rays, 1) {
            let start = Double(index) * step
            let end = start + step / 2
            path.move(to: center)
            path.addLine(to: CGPoint(x: center.x + radius * CGFloat(cos(start)),
                                     y: center.y + radius * CGFloat(sin(start))))
            path.addLine(to: CGPoint(x: center.x + radius * CGFloat(cos(end)),
                                     y: center.y + radius * CGFloat(sin(end))))
            path.closeSubpath()
        }
        return path
    }
}
