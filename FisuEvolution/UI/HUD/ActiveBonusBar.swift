import EconomyKit
import SwiftUI

/// Los contadores de los bonus temporales que están corriendo: en la columna de
/// la derecha, debajo del especial, uno por fila: primero los relojes de
/// eventos y después los boosts y multiplicadores. Pasadas las cuatro filas, el
/// resto se agrupa en un chip «+N» que lo despliega. Los chips de evento llevan
/// la cara de quien lo anunció y son botones: abren el popup del evento.
///
/// El tiempo lo cuenta **esta vista** y no la proyección. `ActiveBonus` lleva
/// `expiresAt` y `totalDuration`, que no cambian mientras el bonus vive, así que
/// `GameState` no publica nada nuevo por el paso del tiempo. Acá alcanza con un
/// solo timer de 1 Hz para toda la barra —el mismo patrón que `EventPopupView`,
/// y uno solo, no uno por chip—; el aro se interpola con un tween lineal de 1 s
/// entre tick y tick, así se ve continuo sin animación de larga duración.
struct ActiveBonusBar: View {
    let bonuses: [ActiveBonus]
    /// Tocar el chip de un evento abre su popup.
    var onEventTap: (String) -> Void = { _ in }

    @Environment(GameState.self) private var gameState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var now = Date()
    @State private var showsAll = false

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    /// Alto del ícono con su aro. El resto de la cápsula se acomoda alrededor.
    private static let iconSide: CGFloat = 30
    /// Filas a la vista antes de agrupar el resto en «+N».
    static let maxRows = 4

    /// Los relojes de eventos primero, los boosts después; cada grupo conserva
    /// su orden (el que vence primero).
    static func ordered(_ bonuses: [ActiveBonus]) -> [ActiveBonus] {
        bonuses.filter { $0.eventId != nil } + bonuses.filter { $0.eventId == nil }
    }

    /// Las filas a la vista: hasta `maxRows`, o todas si el «+N» está abierto.
    static func visibleRows(_ bonuses: [ActiveBonus], showsAll: Bool) -> [ActiveBonus] {
        let all = ordered(bonuses)
        return showsAll ? all : Array(all.prefix(maxRows))
    }

    /// Cuántas filas agrupa el «+N».
    static func hiddenCount(_ bonuses: [ActiveBonus]) -> Int { max(0, bonuses.count - maxRows) }

    private var rows: [ActiveBonus] { Self.visibleRows(bonuses, showsAll: showsAll) }

    private var hiddenCount: Int { Self.hiddenCount(bonuses) }

    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            ForEach(rows) { bonus in
                Group {
                    if let eventId = bonus.eventId {
                        Button { onEventTap(eventId) } label: { chip(bonus) }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("hud.event.chip.\(eventId)")
                            .accessibilityLabel(Text("hud.event.chip.ax \(eventTitle(eventId))"))
                            .tutorialAnchor(.eventChip)
                    } else {
                        // Es estado, no un control: no puede comerse un toque
                        // destinado al tablero que tiene abajo.
                        chip(bonus)
                            .allowsHitTesting(false)
                            .tutorialAnchor(.autoTapChip, when: bonus.effect == .autoTapPerSecond)
                            .accessibilityIdentifier("hud.bonus.chip")
                            .accessibilityLabel(Text("hud.bonus.active.label"))
                    }
                }
                .transition(.scale(scale: 0.7, anchor: .trailing).combined(with: .opacity))
            }
            if hiddenCount > 0 { moreChip }
        }
        .animation(reduceMotion ? nil : .spring(duration: 0.32), value: rows.map(\.id))
        .onReceive(timer) { now = $0 }
        // ⚠️ Sin identificador en el contenedor. Un `accessibilityIdentifier`
        // sobre un `VStack` que no es elemento de accesibilidad **se propaga y
        // pisa el de sus hijos**: con él, el árbol de AX mostraba un solo
        // elemento llamado `hud.bonuses` y los chips desaparecían del test
        // aunque en pantalla se vieran perfectos. Es la trampa 9a del HANDOFF
        // con otra cara: nunca es el control, siempre es el contenedor.
    }

    /// «+N» (o «−» abierto): el resto de las filas.
    private var moreChip: some View {
        Button { showsAll.toggle() } label: {
            Text(verbatim: showsAll ? "−" : "+\(hiddenCount)")
                .font(.system(size: 15, design: .rounded).weight(.heavy))
                .foregroundStyle(Color("PaletteInk"))
                .frame(minWidth: 44, minHeight: 32)
                .background(PillBackground(fill: Color("PaletteCream"), border: Color("PaletteBrown").opacity(0.7), lip: 2))
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("hud.bonus.more")
        .accessibilityLabel(Text("hud.bonus.more.ax \(hiddenCount)"))
    }

    private func eventTitle(_ id: String) -> String {
        gameState.content?.events.event(id: id).map { VisitCopy.text($0.titleKey) } ?? id
    }

    private func chip(_ bonus: ActiveBonus) -> some View {
        let remaining = max(0, bonus.expiresAt - now.timeIntervalSince1970)
        let time = Self.timeText(remaining)
        let tint = bonus.polarity.map(Self.tint) ?? Self.tint(bonus.effect)
        return HStack(spacing: 7) {
            icon(bonus, tint: tint, progress: Self.progress(remaining: remaining, total: bonus.totalDuration))
            // El número y el tiempo van SIEMPRE, no sólo el color: un evento
            // suma además su flecha (sube, baja, las dos).
            if let polarity = bonus.polarity {
                PolarityMark(polarity: polarity)
                    .fill(tint)
                    .frame(width: 12, height: 14)
                    .accessibilityHidden(true)
            }
            Text(verbatim: bonus.effectText)
                .font(.system(size: 15, design: .rounded).weight(.heavy))
                .foregroundStyle(tint)
            Text(verbatim: time)
                .font(.system(size: 13, design: .rounded).weight(.bold))
                .monospacedDigit()
                .foregroundStyle(Color("PaletteInk").opacity(0.7))
        }
        .padding(.leading, 5)
        .padding(.trailing, 11)
        .padding(.vertical, 5)
        .background(
            PillBackground(fill: Color("PaletteCream"), border: Color("PaletteBrown").opacity(0.7), lip: 2)
                .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
        )
        .contentShape(Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityValue(Text(verbatim: "\(bonus.effectText) \(time)"))
    }

    private func icon(_ bonus: ActiveBonus, tint: Color, progress: Double) -> some View {
        ZStack {
            Circle().fill(tint.opacity(0.16))
            Circle()
                .trim(from: 0, to: progress)
                .stroke(tint, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : .linear(duration: 1), value: progress)
            glyph(bonus, tint: tint)
        }
        .frame(width: Self.iconSide, height: Self.iconSide)
    }

    @ViewBuilder
    private func glyph(_ bonus: ActiveBonus, tint: Color) -> some View {
        switch bonus.icon {
        case .art(let key):
            if let art = UIArt.image(key) {
                art.resizable().scaledToFit()
                    .frame(width: Self.iconSide * 0.62, height: Self.iconSide * 0.62)
            } else {
                // Un boost sin su arte en el atlas sigue mostrando su contador:
                // el manifest cae a placeholder, no a nada.
                bolt(tint: tint)
            }
        case .symbol:
            bolt(tint: tint)
        case .face(let visitorId):
            VisitorFace(visitorId: visitorId, side: Self.iconSide - 6)
        }
    }

    private func bolt(tint: Color) -> some View {
        BoltShape()
            .fill(tint)
            .frame(width: 12, height: 16)
    }

    /// El color de un evento dice hacia dónde va (y la flecha lo repite).
    static func tint(_ polarity: EventCatalog.Polarity) -> Color {
        switch polarity {
        case .positive: Color("PaletteGreen")
        case .negative: Color("PalettePink")
        case .mixed: Color("PaletteOrange")
        }
    }

    /// Cuánto del aro queda pintado. Sin duración conocida va lleno: un bonus
    /// que corre y no se ve es peor que un aro que no se vacía.
    static func progress(remaining: TimeInterval, total: TimeInterval?) -> Double {
        guard let total, total > 0 else { return 1 }
        return min(1, max(0, remaining / total))
    }

    /// "42s" abajo del minuto, "1:42" arriba. Redondea hacia ARRIBA: con el
    /// truncado, un boost recién activado de 60 s aparece marcando 59 s.
    static func timeText(_ remaining: TimeInterval) -> String {
        let seconds = Int(remaining.rounded(.up))
        guard seconds >= 60 else { return "\(seconds)s" }
        return "\(seconds / 60):" + String(format: "%02d", seconds % 60)
    }

    /// El color codifica QUÉ potencia, nunca cuánto: el número siempre está al lado.
    static func tint(_ effect: ActiveModifier.Effect) -> Color {
        switch effect {
        case .incomeMultiplier: Color("PaletteGreen")
        case .tapMultiplier: Color("PaletteOrange")
        case .spawnCostMultiplier: Color("PaletteBlue")
        case .spendingFrozen: Color("PalettePink")
        case .passiveMultiplier: Color("PaletteGreen")
        case .eventImmunity: Color("PaletteYellow")
        case .packageRateMultiplier: Color("PaletteBrown")
        case .autoTapPerSecond: Color("PaletteBlue")
        case .freeHire: Color("PaletteBlue")
        case .eventPresence: Color("PaletteGreen")
        }
    }
}

/// La flecha del evento, dibujada: sube, baja o las dos.
struct PolarityMark: Shape {
    let polarity: EventCatalog.Polarity

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let half = rect.height / 2 - 1
        func arrow(up: Bool, in band: CGRect) {
            let tipY = up ? band.minY : band.maxY
            let baseY = up ? band.maxY : band.minY
            path.move(to: CGPoint(x: band.midX, y: tipY))
            path.addLine(to: CGPoint(x: band.maxX, y: baseY))
            path.addLine(to: CGPoint(x: band.minX, y: baseY))
            path.closeSubpath()
        }
        switch polarity {
        case .positive: arrow(up: true, in: rect)
        case .negative: arrow(up: false, in: rect)
        case .mixed:
            arrow(up: true, in: CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: half))
            arrow(up: false, in: CGRect(x: rect.minX, y: rect.maxY - half, width: rect.width, height: half))
        }
        return path
    }
}

/// El rayo de un boost sin arte propio.
struct BoltShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.maxX * 0.62, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY * 0.58))
        path.addLine(to: CGPoint(x: rect.maxX * 0.46, y: rect.maxY * 0.58))
        path.addLine(to: CGPoint(x: rect.maxX * 0.34, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY * 0.38))
        path.addLine(to: CGPoint(x: rect.maxX * 0.54, y: rect.maxY * 0.38))
        path.closeSubpath()
        return path
    }
}
