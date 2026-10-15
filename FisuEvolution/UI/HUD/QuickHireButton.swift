import SwiftUI

/// El atajo de contratación de la pantalla principal, hecho solapa de la barra de
/// abajo (C18; ver `BarFlaps`): compra la oferta
/// `quickHireOffer` sin abrir FisuJobs, y mantenerlo presionado abre el selector
/// para fijar a quién. **Nunca desaparece** con la partida cargada: cuando no
/// compra dice por qué ("no te alcanza" o "Piso lleno") y tiembla al tocarlo
/// (patrón `PricePill`: nunca `.disabled`).
///
/// ⚠️ Un toque compra lo mismo que tres toques en FisuJobs: el atajo dejó de
/// recortar el 2026-08-28. El porqué está en `computeQuickHireOffer()`.
///
/// Es una etiqueta de precio con el Fisura saludando (`fisura_wave`); sólo si el
/// arte falta cae a la cara por `faceKey` (las 43 existen — auditoría RF-05; no
/// lleva fallback vectorial porque `UIArt` ya cae a su placeholder).
///
/// ⚠️ **La oferta NO se recalcula al tocar.** El botón lee la proyección
/// publicada y le pasa el `typeId` a `hireQuickOffer()`, que hace lo mismo:
/// en el filo de los ~125 ms de `refreshProjections` se puede tocar una oferta
/// recién vencida, y eso es deliberado — `TowerActions.hire` revalida piso,
/// gate, saldo y lugar, así que lo peor que pasa es un `hire rejected` con su
/// háptico de error. Recalcular acá sería una segunda regla de selección que
/// mantener sincronizada con `computeQuickHireOffer`, que es justo lo que la
/// proyección viene a evitar.
///
/// ⚠️ Sin `.tutorialAnchor`: el tutorial no lo ilumina en ningún paso (el paso
/// "hire" ilumina el tab `hud.hire`, que abre FisuJobs). Queda bajo el scrim
/// como el resto de la franja.
struct QuickHireButton: View {
    @Environment(GameState.self) private var gameState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Abre el selector (mantener presionado, o la acción de VoiceOver).
    var onChoose: () -> Void = {}
    @State private var shake = 0
    /// El mantener presionado ya abrió el selector: el toque de soltar que le
    /// sigue no compra. Si SwiftUI cancela la acción del `Button`, la bandera la
    /// baja el fin del dedo (ver el `DragGesture`), para que no se trague el
    /// próximo toque real.
    @State private var longPressFired = false

    /// El mismo reloj que el mantener presionado del tablero (`BoardScene`).
    static let longPressDuration: Double = 0.45

    var body: some View {
        // `nil` sólo antes de cargar, y antes de cargar la pantalla es el splash.
        if let offer = gameState.quickHireOffer {
            button(for: offer)
        }
    }

    private func button(for offer: QuickHireOffer) -> some View {
        Button {
            if longPressFired {
                longPressFired = false
                return
            }
            // Un toque bloqueado no cuenta como lección cumplida.
            if offer.blocker == nil {
                gameState.tutorialTipCompleted(.quickHire)
            } else if !reduceMotion {
                shake += 1
            }
            gameState.hireQuickOffer()
        } label: {
            label(for: offer)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: Self.longPressDuration)
                .onEnded { _ in
                    longPressFired = true
                    gameState.playHaptic(.merge)
                    onChoose()
                }
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 0).onEnded { _ in
                // Después de la acción del `Button`, que si corre ya la bajó.
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(250))
                    longPressFired = false
                }
            }
        )
        // UNA sola parada, sin el nombre suelto como hijo: la única forma que da
        // a la vez "sin hijos", "sigue siendo botón" y "sigue siendo tocable" es
        // `accessibilityRepresentation` (medido con dumps del árbol de AX).
        .accessibilityRepresentation {
            Color.clear
                .accessibilityElement()
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel(spokenLabel(for: offer))
                .accessibilityValue(Text(verbatim: offer.accessibilityState))
                .accessibilityAction(named: Text("quickhire.ax.choose"), onChoose)
        }
        // ⚠️ DESPUÉS de la representación: puesto arriba, se iría con lo que
        // ella reemplaza.
        .accessibilityIdentifier("hud.quickhire")
        // Las keyframes de `PricePill`; van últimas para que el identifier quede
        // pegado al botón (trampa 9a-bis).
        .keyframeAnimator(initialValue: 0.0, trigger: shake) { view, dx in
            view.offset(x: dx)
        } keyframes: { _ in
            KeyframeTrack {
                CubicKeyframe(-4, duration: 0.07)
                CubicKeyframe(4, duration: 0.08)
                CubicKeyframe(-3, duration: 0.08)
                CubicKeyframe(0, duration: 0.07)
            }
        }
    }

    /// La etiqueta de precio (E14b B28, diseño B): verde con costura, ojal y
    /// piolín, colgada de la solapa; el Fisura saludando parado arriba a la
    /// izquierda, y el precio en una placa crema con la moneda. El nombre no se
    /// ve —lo dice VoiceOver— y el pin es un puntito en el hombro del Fisura.
    ///
    /// Se hamaca y el Fisura da un saltito cada tanto, pero sólo si compra: sin
    /// plata la etiqueta queda gris y quieta, y Reduce Motion apaga todo.
    private func label(for offer: QuickHireOffer) -> some View {
        let ready = offer.blocker == nil
        let moves = ready && !reduceMotion
        return PulseClock(interval: 4.2, active: moves) { tick in
            tagWithPrice(for: offer, ready: ready)
                .keyframeAnimator(initialValue: -3.0, trigger: tick) { view, angle in
                    view.rotationEffect(.degrees(angle), anchor: .leading)
                } keyframes: { _ in
                    KeyframeTrack {
                        CubicKeyframe(-5.0, duration: 0.5)
                        CubicKeyframe(-1.5, duration: 0.6)
                        CubicKeyframe(-3.0, duration: 0.5)
                    }
                }
        }
        // El Fisura sobresale de la etiqueta: va en un overlay para no sumar alto.
        .overlay(alignment: .bottomLeading) {
            PulseClock(interval: 3.1, active: moves, delay: 1.2) { tick in
                wavingFisura(for: offer, ready: ready)
                    .keyframeAnimator(initialValue: 0.0, trigger: tick) { view, dy in
                        view.offset(y: dy)
                    } keyframes: { _ in
                        KeyframeTrack {
                            CubicKeyframe(-7, duration: 0.14)
                            CubicKeyframe(0, duration: 0.16)
                        }
                    }
            }
        }
        .foregroundStyle(Color("PaletteInk"))
        .dynamicTypeSize(...DynamicTypeSize.large)
        .frame(maxWidth: .infinity)
        .frame(height: GameTabBar.flapHeight)
        .contentShape(Rectangle())
    }

    /// El lugar que se come el Fisura a la izquierda de la placa de precio.
    static let fisuraSlot: CGFloat = 36
    /// Cuánto de la placa se come la etiqueta por la izquierda (la punta, el ojal y
    /// el Fisura, que se le monta encima) y el aire de la derecha.
    static let plateLeadingInset: CGFloat = PriceTagShape.notch + fisuraSlot - 12
    static let plateTrailingInset: CGFloat = 7
    /// Moneda + aire a la izquierda del monto, y triángulo + aire a la derecha.
    static let plateChromeWidth: CGFloat = 10 + 15 + 2 + 3 + 9

    /// El ancho que tiene el monto dentro de una solapa de `lane` pt.
    static func priceTextWidth(lane: CGFloat) -> CGFloat {
        max(0, lane - plateLeadingInset - plateTrailingInset - plateChromeWidth)
    }

    private func tagWithPrice(for offer: QuickHireOffer, ready: Bool) -> some View {
        ZStack(alignment: .leading) {
            PriceTagBody(tint: ready ? Color("PaletteGreen") : nil)
            HStack(spacing: 0) {
                Color.clear.frame(width: Self.plateLeadingInset)
                pricePlate(for: offer)
            }
            .padding(.trailing, Self.plateTrailingInset)
            .padding(.bottom, GameTabBar.flapOverlap)
        }
    }

    /// El Fisura de cuerpo entero saludando (`fisura_wave`, del atlas de UI); si
    /// el arte no está, cae a su cara.
    @ViewBuilder private func wavingFisura(for offer: QuickHireOffer, ready: Bool) -> some View {
        Group {
            if let wave = UIArt.image("fisura_wave") {
                wave.resizable().scaledToFit()
                    .frame(width: 50, height: 54)
            } else {
                GameIcon(artKey: offer.faceKey, size: 40) { EmptyView() }
            }
        }
        .saturation(ready ? 1 : 0)
        .overlay(alignment: .topTrailing) {
            if offer.isPinned {
                Circle()
                    .fill(Color("PaletteOrange"))
                    .overlay(Circle().strokeBorder(Color("PaletteInk"), lineWidth: 1.5))
                    .frame(width: 10, height: 10)
            }
        }
        .padding(.leading, 2)
        .padding(.bottom, GameTabBar.flapOverlap + 4)
        .allowsHitTesting(false)
    }

    /// La placa crema del precio: la moneda, el monto (con el de lista tachado
    /// encima) y el triángulo del selector. Con el piso lleno, el motivo.
    private func pricePlate(for offer: QuickHireOffer) -> some View {
        HStack(spacing: 3) {
            priceLine(for: offer)
            FlapChevron()
        }
        .padding(.horizontal, 5)
        .frame(maxWidth: .infinity)
        .frame(height: 30)
        .background(Color("PaletteCream"), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
            .strokeBorder(Color("PaletteInk"), lineWidth: 2.5))
    }

    /// El precio (con el de lista tachado encima) o, con el piso lleno, el motivo.
    @ViewBuilder private func priceLine(for offer: QuickHireOffer) -> some View {
        if offer.blocker == .floorFull {
            Text("quickhire.blocker.floor_full")
                .font(Tokens.caption)
                .lineLimit(2)
                .minimumScaleFactor(0.5)
        } else {
            HStack(spacing: 2) {
                CoinIcon(size: 15)
                VStack(spacing: -2) {
                    if let list = offer.listCostText {
                        StrikePrice(text: list)
                    }
                    Text(verbatim: offer.costText)
                        .font(Tokens.body)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
            }
        }
    }

    /// "Contratar a {nombre}, {monto} monedas", más el motivo y el pin.
    private func spokenLabel(for offer: QuickHireOffer) -> Text {
        var label = Text(verbatim: String(localized: "quickhire.ax.purpose \(offer.displayName)"))
        switch offer.blocker {
        case .floorFull:
            label = label + Text(verbatim: ", ") + Text("quickhire.blocker.floor_full")
        case .cantAfford:
            label = label + Text(verbatim: ", \(String(localized: "price.ax.coins \(offer.costText)")), ")
                + Text("quickhire.ax.cant_afford")
        case nil:
            label = label + Text(verbatim: ", \(String(localized: "price.ax.coins \(offer.costText)"))")
        }
        if let list = offer.listCostText, offer.blocker != .floorFull {
            label = label + Text(verbatim: ", \(String(localized: "price.ax.was \(list)"))")
        }
        if offer.isPinned {
            label = label + Text(verbatim: ", ") + Text("quickhire.ax.pinned")
        }
        if offer.followsFloor {
            label = label + Text(verbatim: ", ") + Text("quickhire.ax.floor_base")
        }
        return label
    }
}
