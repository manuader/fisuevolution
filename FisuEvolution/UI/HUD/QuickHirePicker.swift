import SwiftUI

/// El selector del atajo (PLAN-v2 E3): una tarjeta colgada del atajo con las
/// caras de los personajes que el jugador puede contratar, para fijar uno.
///
/// **No es una hoja**: el juego sigue corriendo detrás. Tocar una cara la fija;
/// tocar la fijada o "Mejor disponible" la suelta; tocar afuera cierra. Nunca
/// muestra un tipo sin desbloquear (`quickHirePickerEntries` sale de la misma
/// compuerta que FisuJobs).
struct QuickHirePicker: View {
    @Environment(GameState.self) private var gameState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// El marco del atajo en la pantalla (el ancla `.quickHire` del tutorial).
    let anchor: CGRect?
    let close: () -> Void

    private static let columns = 4
    private static let cellWidth: CGFloat = 64
    private static let gridMaxHeight: CGFloat = 300
    private static var cardWidth: CGFloat {
        CGFloat(columns) * cellWidth + CGFloat(columns - 1) * Tokens.s8 + PanelCard<EmptyView>.contentInset * 2
    }

    var body: some View {
        // Los precios y los llenos se mueven con el tablero.
        let _ = gameState.boardVersion
        let entries = gameState.quickHirePickerEntries
        GeometryReader { proxy in
            let leading = cardLeading(in: proxy.size)
            ZStack(alignment: .bottomLeading) {
                Color.black.opacity(0.18)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: close)
                    .accessibilityElement()
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel(Text("store.close"))
                    .accessibilityIdentifier("quickhire.picker.close")
                card(entries, tailX: (anchor?.midX ?? leading + 40) - leading)
                    .padding(.leading, leading)
                    .padding(.bottom, proxy.size.height - (anchor?.minY ?? proxy.size.height * 0.8) + 14)
            }
        }
        .ignoresSafeArea()
        .transition(reduceMotion ? .opacity : .scale(scale: 0.85, anchor: .bottomLeading).combined(with: .opacity))
    }

    private func cardLeading(in size: CGSize) -> CGFloat {
        let wanted = anchor?.minX ?? Tokens.s12
        return min(max(Tokens.s12, wanted), size.width - Self.cardWidth - Tokens.s12)
    }

    private func card(_ entries: [QuickHirePickerEntry], tailX: CGFloat) -> some View {
        PanelCard {
            VStack(alignment: .leading, spacing: Tokens.s12) {
                Text("quickhire.picker.title")
                    .font(Tokens.title)
                    .foregroundStyle(Color("PaletteInk"))
                bestButton(isActive: !entries.contains(where: \.isPinned))
                ScrollView {
                    // `Grid` y no `LazyVGrid`: la perezosa pierde identifiers.
                    Grid(horizontalSpacing: Tokens.s8, verticalSpacing: Tokens.s8) {
                        ForEach(Array(rows(entries).enumerated()), id: \.offset) { _, row in
                            GridRow {
                                ForEach(row) { entry in option(entry) }
                            }
                        }
                    }
                }
                .scrollBounceBehavior(.basedOnSize)
                .frame(maxHeight: Self.gridMaxHeight)
            }
        }
        .frame(width: Self.cardWidth)
        .overlay(alignment: .bottomLeading) {
            PickerTail()
                .fill(Color("PaletteInk").opacity(0.9))
                .frame(width: 20, height: 12)
                .offset(x: max(16, min(tailX - 10, Self.cardWidth - 36)), y: 11)
                .accessibilityHidden(true)
        }
    }

    private func rows(_ entries: [QuickHirePickerEntry]) -> [[QuickHirePickerEntry]] {
        stride(from: 0, to: entries.count, by: Self.columns).map {
            Array(entries[$0 ..< min($0 + Self.columns, entries.count)])
        }
    }

    private func bestButton(isActive: Bool) -> some View {
        Button {
            gameState.pinQuickHire(typeId: nil)
            close()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isActive ? "checkmark.circle.fill" : "sparkles")
                    .font(.system(size: 14, weight: .black))
                Text("quickhire.picker.best")
                    .font(Tokens.body)
            }
            .foregroundStyle(isActive ? .white : Color("PaletteInk"))
            .shadow(color: .black.opacity(isActive ? 0.45 : 0), radius: 1, y: 1)
            .padding(.horizontal, Tokens.s12)
            .padding(.vertical, Tokens.s8)
            .frame(maxWidth: .infinity)
            .background(
                PillBackground(
                    fill: isActive ? Color("PaletteGreen") : Color("PaletteCream"),
                    border: isActive ? nil : Color("PaletteBrown").opacity(0.6)
                )
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("quickhire.picker.best")
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    private func option(_ entry: QuickHirePickerEntry) -> some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        return Button {
            gameState.pinQuickHire(typeId: entry.isPinned ? nil : entry.id)
            close()
        } label: {
            VStack(spacing: 2) {
                GameIcon(artKey: entry.faceKey, size: 44) { EmptyView() }
                    .overlay(alignment: .topTrailing) {
                        if entry.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 11, weight: .black))
                                .rotationEffect(.degrees(30))
                                .offset(x: 4, y: -4)
                        }
                    }
                if entry.fits {
                    HStack(spacing: 2) {
                        CoinIcon(size: 12)
                        Text(verbatim: entry.costText)
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                } else {
                    Text("quickhire.picker.full")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
            .foregroundStyle(Color("PaletteInk"))
            .frame(width: Self.cellWidth, height: 68)
            .background(shape.fill(entry.isPinned ? Color("PaletteYellow").opacity(0.55) : Color("PaletteCream")))
            .overlay(shape.strokeBorder(Color("PaletteBrown").opacity(entry.isPinned ? 0.9 : 0.45),
                                        lineWidth: entry.isPinned ? 2.5 : 1.5))
            .opacity(entry.fits ? 1 : 0.5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("quickhire.picker.option.\(entry.id)")
        .accessibilityLabel(Text(verbatim: String(localized: "quickhire.ax.purpose \(entry.displayName)")))
        .accessibilityValue(entry.isPinned
            ? Text("quickhire.ax.pinned")
            : (entry.fits ? Text(verbatim: String(localized: "price.ax.coins \(entry.costText)")) : Text("quickhire.picker.full")))
    }
}

/// La cola de la tarjeta, apuntando al atajo.
private struct PickerTail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
