import SwiftUI

/// El atajo de contratación de la pantalla principal: compra la oferta
/// `quickHireOffer` sin abrir FisuJobs, y mantenerlo presionado abre el selector
/// para fijar a quién. **Nunca desaparece** con la partida cargada: cuando no
/// compra dice por qué ("no te alcanza" o "Piso lleno") y tiembla al tocarlo
/// (patrón `PricePill`: nunca `.disabled`).
///
/// ⚠️ Un toque compra lo mismo que tres toques en FisuJobs: el atajo dejó de
/// recortar el 2026-08-28. El porqué está en `computeQuickHireOffer()`.
///
/// La cara viene del atlas por `faceKey` (las 43 existen — auditoría RF-05);
/// no lleva fallback vectorial porque `UIArt` ya cae a su placeholder.
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

    /// Cuánto mide de alto la cápsula, para lo que se apoye sobre ella.
    ///
    /// Es la suma del layout del label, no una medición suelta: **40** de la
    /// carita —que es el hijo más alto del `HStack`, porque la columna de texto
    /// mide ~35 al tamaño por defecto— más los **8 + 8** de
    /// `padding(.vertical, Tokens.s8)`. Confirmado en el árbol de AX de una
    /// corrida real: **56,0 exactos** en 3× (16 Pro) y en 2× (SE 3), sin el
    /// medio punto que sí tiene el botón de prestigio.
    ///
    /// ⚠️ Existe por lo mismo que `GameTabBar.barHeight`: este número lo
    /// necesitan DOS lugares fuera de acá —los dos toasts de `RootView`, que
    /// flotan sobre la franja de abajo ENTERA— y allá el despeje es de 1,0 pt
    /// en 3× y 0,5 pt en 2×. Con el alto copiado como literal en cada padding,
    /// el día que cambie se arregla en uno y se olvida en el otro, que es
    /// exactamente las dos veces que `barHeight` tuvo que aprender a subir sola.
    ///
    /// ⚠️⚠️ **El gatillo de que este número deje de valer es Dynamic Type, no un
    /// rediseño.** `Tokens.caption` y `Tokens.body` son text styles DINÁMICOS: a
    /// tamaños de accesibilidad la columna de texto pasa los 40 pt de la carita
    /// y la cápsula crece por encima de 56. El `minimumScaleFactor` **no** lo
    /// frena —con `minWidth: 170` y sin ancho máximo, el `HStack` se ensancha
    /// antes que escalar el texto—, así que el despeje de los toasts se puede
    /// comer **en runtime** y no en un commit. Es una exposición que este botón
    /// COMPARTE con el de prestigio, cuyo 45 es igual de estático, y que precede
    /// a los dos: el número está pineado al tamaño por defecto, que es donde se
    /// midió y lo único que garantiza.
    ///
    /// ⚠️ **Está aislado al main actor, como todo el tipo.** `View` es
    /// `@MainActor @preconcurrency`, así que la conformance aísla al struct
    /// ENTERO y a sus statics con él. No lleva anotación porque no le hace
    /// falta —sus dos consumidores son `body`s de SwiftUI, que ya corren ahí—,
    /// **no** porque esté exento: la exención de inmutable-`Sendable` es para
    /// los statics de tipos NO aislados globalmente, y SE-0434 cubre los `let`
    /// **de instancia**, no los estáticos. Ninguna de las dos aplica acá. Si
    /// alguna vez lo necesitara un contexto `nonisolated`, la anotación hay que
    /// escribirla —`nonisolated static let`— y no darla por puesta.
    ///
    /// Comprobado compilando las tres formas con `-swift-version 6
    /// -strict-concurrency=complete`: el static de un tipo que conforma `View`,
    /// leído desde `nonisolated`, es **error** ("main actor-isolated static
    /// property 'h' can not be referenced from a nonisolated context"); el mismo
    /// static en un tipo sin la conformance compila; y un `let` de instancia
    /// `Sendable` del mismo `View` también.
    static let capsuleHeight: CGFloat = 56

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

    private func label(for offer: QuickHireOffer) -> some View {
        let ready = offer.blocker == nil
        return HStack(spacing: Tokens.s8) {
            GameIcon(artKey: offer.faceKey, size: 40) { EmptyView() }
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(verbatim: offer.displayName)
                        .font(Tokens.caption)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    if offer.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 9, weight: .black))
                            .rotationEffect(.degrees(30))
                    }
                }
                secondLine(for: offer)
            }
            // "Hay más": mantener presionado abre el selector.
            Image(systemName: "chevron.up")
                .font(.system(size: 10, weight: .black))
                .opacity(0.6)
        }
        .foregroundStyle(ready ? .white : Color("PaletteInk"))
        .shadow(color: .black.opacity(ready ? 0.45 : 0), radius: 1, y: 1)
        .padding(.horizontal, Tokens.s16)
        .padding(.vertical, Tokens.s8)
        .frame(minWidth: 170)
        .background(
            // Verde caramelo cuando compra; el gris de la casa (el de
            // `GameCard.locked`) cuando no.
            PillBackground(
                fill: ready ? Color("PaletteGreen") : CardMaterials.lockedFill,
                border: ready ? nil : CardMaterials.lockedBorder
            )
            .shadow(color: .black.opacity(0.12), radius: 3, y: 2)
        )
        .contentShape(Capsule())
    }

    /// La segunda línea mide lo mismo en los tres estados (20 pt, el alto de la
    /// moneda): el atajo no cambia de tamaño.
    @ViewBuilder private func secondLine(for offer: QuickHireOffer) -> some View {
        if offer.blocker == .floorFull {
            HStack(spacing: 5) {
                Image(systemName: "person.3.fill")
                    .font(.system(size: 12, weight: .black))
                Text("quickhire.blocker.floor_full")
                    .font(Tokens.body)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .frame(height: 20)
        } else {
            HStack(spacing: 5) {
                CoinIcon(size: 20)
                VStack(spacing: -2) {
                    if let list = offer.listCostText {
                        StrikePrice(text: list,
                                    color: offer.blocker == nil ? .white.opacity(0.8) : Color("PaletteInk").opacity(0.6))
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
        return label
    }
}
