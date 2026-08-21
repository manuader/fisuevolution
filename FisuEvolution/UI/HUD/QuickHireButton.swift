import SwiftUI

/// El atajo de contratación de la pantalla principal: compra al PERSONAJE
/// INICIAL —el tier base— del piso más alto que la plata alcanza (proyección
/// `bestHire`), sin abrir FisuJobs. Mismo contrato visual que `PricePill`:
/// nunca `.disabled`, verde cuando alcanza, temblor cuando no.
///
/// ⚠️ Es el atajo del tier BASE y no el de "lo mejor que la plata alcanza": los
/// tiers de arriba de cada piso se siguen comprando desde FisuJobs, que vende
/// todo lo desbloqueado. Ofrecerlos acá salteaba la profundidad de merge del
/// piso y aceleraba el juego (§4.5 del rebalance de pacing).
///
/// La cara viene del atlas por `faceKey` (las 43 existen — auditoría RF-05);
/// no lleva fallback vectorial porque `UIArt` ya cae a su placeholder.
///
/// ⚠️ **La oferta NO se recalcula al tocar.** El botón lee la proyección
/// publicada y le pasa el `typeId` a `hireBestCharacter()`, que hace lo mismo:
/// en el filo de los ~125 ms de `refreshProjections` se puede tocar una oferta
/// recién vencida, y eso es deliberado — `TowerActions.hire` revalida piso,
/// gate, saldo y lugar, así que lo peor que pasa es un `hire rejected` con su
/// háptico de error. Recalcular acá sería una segunda regla de selección que
/// mantener sincronizada con `computeBestHire`, que es justo lo que la
/// proyección viene a evitar.
///
/// ⚠️ Sin `.tutorialAnchor`: el tutorial no lo ilumina en ningún paso (el paso
/// "hire" ilumina el tab `hud.hire`, que abre FisuJobs). Queda bajo el scrim
/// como el resto de la franja.
struct QuickHireButton: View {
    @Environment(GameState.self) private var gameState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shake = 0

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

    var body: some View {
        if let best = gameState.bestHire {
            button(for: best)
        }
    }

    private func button(for best: BestHire) -> some View {
        Button {
            // El temblor reemplaza al `.disabled` (patrón `PricePill`): dice "no
            // te alcanza" sin apagar el botón. Va ANTES de la acción, que en el
            // caso caro no va a comprar nada.
            if !best.affordable, !reduceMotion { shake += 1 }
            gameState.hireBestCharacter()
        } label: {
            HStack(spacing: Tokens.s8) {
                GameIcon(artKey: best.faceKey, size: 40) { EmptyView() }
                VStack(alignment: .leading, spacing: 1) {
                    Text(verbatim: best.displayName)
                        .font(Tokens.caption)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    HStack(spacing: 5) {
                        CoinIcon(size: 20)
                        Text(verbatim: best.costText)
                            .font(Tokens.body)
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                }
            }
            .foregroundStyle(best.affordable ? .white : Color("PaletteInk"))
            .shadow(color: .black.opacity(best.affordable ? 0.45 : 0), radius: 1, y: 1)
            .padding(.horizontal, Tokens.s16)
            .padding(.vertical, Tokens.s8)
            .frame(minWidth: 170)
            .background(
                // La cápsula caramelo del v3 (PillBackground): verde cuando
                // alcanza, crema con borde marrón cuando no — el mismo material
                // que PricePill, que es su gemelo de adentro de las hojas.
                PillBackground(
                    fill: best.affordable ? Color("PaletteGreen") : Color("PaletteCream"),
                    border: best.affordable ? nil : Color("PaletteBrown").opacity(0.6)
                )
                .shadow(color: .black.opacity(0.12), radius: 3, y: 2)
            )
            .saturation(best.affordable ? 1 : 0.7)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        // ⚠️ **UNA sola parada: el botón no puede exponer el nombre del personaje
        // como un elemento suelto.** Es el patrón T8 de la casa —los nombres los
        // anuncia el resumen de quien los contiene, nunca un `StaticText`
        // propio— y lo cazó
        // `FisuJobsUITests.testContratarSubeElPrecioDeLaFilaYPoneLaUnidadEnElTablero`,
        // que asserta `app.staticTexts["El Fisura"].exists == false` sobre la app
        // ENTERA: la hoja de FisuJobs tapa la pantalla principal pero **no** tapa
        // el árbol de AX, así que este botón le metía el nombre suelto en la
        // escena a un test más viejo que la rama entera.
        //
        // ⚠️⚠️ **Y tiene que ser `accessibilityRepresentation`.** Un `Button` de
        // SwiftUI publica el contenido de su label como hijos pase lo que pase
        // —`hud.prestige` expone su 'Reincarnate' y los tabs su 'Outfits',
        // miralos en cualquier dump—, y las cuatro formas que uno escribiría
        // NO lo evitan. Medido con dumps del árbol de AX, no supuesto:
        //
        //   · `.accessibilityElement(children: .ignore)` sobre el `Button`  → siguen
        //   · `.accessibilityHidden(true)` sobre el contenido del label       → siguen
        //   · `.accessibilityElement(children: .ignore)` dentro del label     → siguen
        //   · `.accessibilityHidden(true)` sobre cada `Text` hoja             → siguen
        //   · `.accessibilityChildren { EmptyView() }`  → los saca, PERO deja el
        //     botón `isHittable == false`: rompe el smoke test y, peor, la
        //     activación por VoiceOver.
        //
        // `accessibilityRepresentation` es la única que da las tres cosas a la
        // vez: sin hijos, sigue siendo `Button` con su label compuesto, y sigue
        // siendo tocable. Reemplaza la accesibilidad del control por la de este
        // `Color.clear` —que ocupa el mismo frame— sin tocar el dibujo ni el
        // hit-testing reales.
        //
        // El trait va explícito porque el sustituto es un `Color.clear` pelado:
        // sin él, `app.buttons["hud.quickhire"]` deja de encontrarlo.
        .accessibilityRepresentation {
            Color.clear
                .accessibilityElement()
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel(spokenLabel(for: best))
        }
        // ⚠️ **El identifier va DESPUÉS de `accessibilityRepresentation`, y el
        // orden es load-bearing**: la representación reemplaza el AX del control
        // entero, así que un identifier puesto ARRIBA de ella se va con lo que
        // reemplaza y `app.buttons["hud.quickhire"]` deja de encontrar nada.
        //
        // Ojo con la nota de acá abajo, que invita justo a la lectura que lo
        // rompe: lo que la trampa 9a-bis pide es que el identifier no cuelgue de
        // un CONTENEDOR de más, no que vaya lo más adentro posible. Las dos
        // reglas conviven —identifier después de la representación, y el
        // `keyframeAnimator` después del identifier— porque `offset` no crea
        // elemento de accesibilidad y la representación sí.
        .accessibilityIdentifier("hud.quickhire")
        // ±4 pt, cuatro tramos, 0,3 s en total — las mismas keyframes que
        // `PricePill`, para que los dos botones de compra del juego digan "no"
        // igual. Va **último** para que el identifier quede pegado al botón y no
        // a un contenedor de más (trampa 9a-bis): `offset` no crea un elemento
        // de accesibilidad.
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

    /// "Contratar a {nombre}, {monto} monedas": propósito + monto CON su
    /// moneda, mismo reparto que arma `PricePill` (el glifo de la moneda es un
    /// dibujo y VoiceOver no lo ve).
    private func spokenLabel(for best: BestHire) -> Text {
        Text(verbatim: String(localized: "quickhire.ax.purpose \(best.displayName)"))
            + Text(verbatim: ", \(String(localized: "price.ax.coins \(best.costText)"))")
    }
}
