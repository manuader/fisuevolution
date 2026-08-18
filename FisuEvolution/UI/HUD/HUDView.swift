import SwiftUI

/// HUD superior estilo Cow Evolution (spec §3): **una** barra contigua con el
/// atajo a la tienda a la izquierda, la plata al centro y el ascensor a la
/// derecha; debajo, la fila compacta de torre y el chip de reencarnación.
///
/// Quedan **dos** closures de las cinco que recibía: bonus, mejoras y ajustes se
/// mudaron a la barra inferior (`BottomMenuBar`) junto con la fila transitoria
/// de cuatro íconos que vivía acá. La tienda sobrevive porque el HUD conserva su
/// propio atajo —la moneda con el `+`—, que apunta al mismo destino que el tab.
///
/// Observa **proyecciones** de `GameState` (`coinsText`, `towerNavigation`,
/// `towerIncomePerSecondText`, `prestigePreview`), nunca `PlayerState`.
struct HUDView: View {
    @Environment(GameState.self) private var gameState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var onStoreTap: () -> Void = {}
    /// El mapa se abre desde acá (ver `elevatorButton`), así que el tutorial no
    /// tiene otra forma de enterarse de que su paso se cumplió.
    var onMapOpen: () -> Void = {}
    /// El mapa se presenta desde acá y no desde `RootView` a propósito: vive
    /// pegado a la navegación de la torre, que es lo único que reemplaza.
    @State private var showFloorMap = false
    /// El inset superior REAL de la pantalla, leído de la ventana al aparecer.
    ///
    /// Arranca en 44 —el notch más chico que existe— y **no** en 0 a propósito:
    /// el valor de verdad recién llega con el `onAppear`, y arrancando en 0 los
    /// teléfonos con notch dibujarían un frame con el piso aplicado y pegarían un
    /// salto de 12 pt al asentarse. Con 44, el caso común sale bien desde el
    /// frame uno y el único que se acomoda es el SE.
    @State private var windowTopInset: CGFloat = 44

    /// Aire mínimo entre el borde FÍSICO de arriba y la fila principal.
    ///
    /// Existe por los teléfonos sin notch (SE 2/3, que `TARGETED_DEVICE_FAMILY: 1`
    /// + iOS 17 siguen incluyendo): ahí la safe area superior **es** la barra de
    /// estado, así que al esconderla (`RootView.statusBarHidden`) el inset se
    /// desploma de 20 a 0 y la fila se va contra el bezel. Medido en un SE 3 antes
    /// del piso: panel de 80 pt y los botones de 60 a 5 pt del borde.
    private static let minimumTopGap: CGFloat = 14

    /// Cuánto baja la fila principal desde el borde de la safe area.
    ///
    /// El diseño la quiere pegada arriba (de ahí el 2), pero nunca más cerca de
    /// `minimumTopGap` del borde físico. En un teléfono con notch el inset solo
    /// ya alcanza y de sobra, así que el `max` devuelve el 2 de siempre y el piso
    /// **no cambia nada**; sólo entra a jugar cuando el inset se desploma.
    private var mainBarTopPadding: CGFloat {
        max(2, Self.minimumTopGap - windowTopInset)
    }

    var body: some View {
        VStack(spacing: Tokens.s4) {
            mainBar
                .padding(.horizontal, Tokens.s12)
                .padding(.top, mainBarTopPadding)
                .padding(.bottom, Tokens.s12)
                .frame(maxWidth: .infinity)
                .background { topPanel }
            prestigeIndicator
        }
        .onAppear { windowTopInset = Self.screenTopSafeArea }
        .sheet(isPresented: $showFloorMap) {
            FloorMapView()
                // El panel del `panelSheet` ES la hoja: flota sobre el juego
                // atenuado con la banda inferior a la vista (como las seis de
                // la barra, en `RootView`).
                .presentationBackground(.clear)
        }
        .tutorialAnchor(.hudBar)
    }

    /// El inset superior de la **pantalla**, preguntado a la ventana.
    ///
    /// ⚠️ Se lee de UIKit y **no** con un `GeometryReader`, que sería lo natural:
    /// `RootView` ya consumió la safe area antes de que el HUD exista, así que acá
    /// adentro un proxy reporta 0 en TODOS los teléfonos —incluso ignorando la
    /// safe area para estirar la sonda hasta el borde físico, que es el truco
    /// habitual—. Medido con captura: con la sonda de `GeometryReader`, el piso se
    /// aplicaba también en un 16 Pro y bajaba la fila 12 pt de más (panel de 148
    /// en vez de 136). La ventana es el único lugar donde el número sigue siendo
    /// el de la pantalla y no el que sobró después de repartirlo.
    ///
    /// No es reactivo, y no hace falta: la app es sólo portrait
    /// (`UISupportedInterfaceOrientations`), así que este inset no cambia en toda
    /// la sesión.
    @MainActor private static var screenTopSafeArea: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .safeAreaInsets.top ?? 0
    }

    /// El panel crema que reemplazó al scrim degradado y a la isla crema.
    ///
    /// Opaco y **fundido con el borde físico de arriba**: el `ignoresSafeArea`
    /// lo estira por debajo de la barra de estado, así que el reloj y la batería
    /// se apoyan sobre el panel en vez de sobre el tablero. Es lo que el scrim
    /// translúcido nunca logró — dejaba pasar el tendedero y el graffiti, y ahí
    /// arriba el contraste dependía de qué piso estuviera a la vista.
    ///
    /// Es el **gemelo** del `bottomPanel` de `GameTabBar`, y eso es el requisito,
    /// no un parecido: mismo crema, mismo contorno ink de 3 pt, mismas esquinas
    /// de 24. El panel ink de la primera vuelta partía la pantalla en tres tonos
    /// —oscuro arriba, tablero al medio, crema abajo— y el dueño lo re-decidió
    /// con las capturas en mano: las dos franjas encuadran el tablero sólo si son
    /// la misma cosa.
    ///
    /// Redondea **sólo abajo**: arriba no hay esquina que mostrar (está fuera de
    /// pantalla) y curvarla dejaría dos muescas del tablero asomando en los
    /// vértices superiores. Y el contorno se sale por los tres lados que no dan
    /// al tablero (de eso se ocupan los paddings negativos), así que lo único que
    /// se ve del trazo es el borde de abajo: un panel fundido no puede tener una
    /// línea encerrándolo.
    private var topPanel: some View {
        UnevenRoundedRectangle(
            bottomLeadingRadius: 24, bottomTrailingRadius: 24, style: .continuous
        )
        .fill(Color("PaletteCream"))
        .overlay(
            UnevenRoundedRectangle(
                bottomLeadingRadius: 24, bottomTrailingRadius: 24, style: .continuous
            )
            .strokeBorder(Color("PaletteInk"), lineWidth: 3)
            .padding(.horizontal, -3)
            .padding(.top, -3)
        )
        .shadow(color: .black.opacity(0.2), radius: 6, y: 2)
        .ignoresSafeArea(edges: .top)
    }

    // MARK: - Barra contigua

    /// La fila principal del HUD: atajo a la tienda, plata y ascensor.
    ///
    /// Ya **no** es una `GameCard`: la tarjeta crema con contorno la dibujaba
    /// como una isla flotando, y el rediseño la quiere fundida con el borde de
    /// arriba. El fondo lo pone `topPanel` desde el `body`, que es quien puede
    /// estirarse hasta atrás de la barra de estado; acá adentro queda el `HStack`
    /// pelado.
    private var mainBar: some View {
        HStack(spacing: Tokens.s8) {
            coinsPlusButton
            Spacer(minLength: Tokens.s4)
            coinsColumn
            Spacer(minLength: Tokens.s4)
            elevatorButton
        }
        .frame(maxWidth: .infinity)
    }

    /// Atajo a la tienda: la moneda con el `+` rosa. Mismo destino que el
    /// carrito (`onStoreTap`), pero puesto donde el jugador mira justo cuando
    /// descubre que no le alcanza.
    private var coinsPlusButton: some View {
        IconButton(
            artKey: "ui_coin_plus",
            fallback: { AnyView(VectorCoinPlusIcon()) },
            // El 0,85 del primer tamaño grande (66): el dueño los quiso apenas
            // más discretos después de verlos en pantalla (2026-08-18).
            size: 56,
            showsPlate: false,
            tint: Color("PaletteYellow"),
            labelKey: "hud.coins.plus.label",
            identifier: "hud.coins.plus",
            action: onStoreTap
        )
    }

    /// El centro de la barra. El `VStack` **no** lleva identifier: adentro hay
    /// DOS elementos de accesibilidad (monto e ingreso) y un id en un contenedor
    /// pelado se propaga y los pisa a los dos, dejando uno solo en el árbol
    /// (trampa 9a-bis del handoff).
    private var coinsColumn: some View {
        VStack(spacing: 0) {
            coinsAmount
            incomeRate
        }
    }

    /// El contador rueda: los dígitos que cambian salen y entran en vertical en
    /// vez de saltar (spec §11.2). `monospacedDigit` **no** pelea con la
    /// transición —al revés, es lo que la hace posible: sin ancho fijo, cada
    /// dígito nuevo correría el resto del número mientras rueda.
    ///
    /// ⚠️ La duración es corta a propósito. `refreshProjections` publica
    /// `coinsText` a 8 Hz, así que con la `.snappy` de fábrica (0,5 s) el
    /// contador nunca terminaría un rodado antes de que llegue el siguiente y el
    /// número quedaría permanentemente borroso mientras el jugador toca. A 0,22 s
    /// alcanza a asentarse entre refrescos.
    private var coinsAmount: some View {
        HStack(spacing: Tokens.s4) {
            CoinIcon(size: 36)
            Text(verbatim: gameState.coinsText)
                .font(Tokens.display)
                .monospacedDigit()
                .contentTransition(reduceMotion ? .identity : .numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                // Ink sobre crema, como cualquier texto del juego: desde que el
                // panel es el gemelo del de abajo, el número ya no vive sobre un
                // fondo oscuro. Y sin fondo oscuro tampoco hace falta la sombra
                // que lo despegaba: sobre crema sólo lo ensuciaba.
                .foregroundStyle(Color("PaletteInk"))
        }
        .animation(reduceMotion ? nil : .snappy(duration: 0.22), value: gameState.coinsText)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("hud.coins")
        .accessibilityLabel(Text("hud.coins.label"))
        .accessibilityValue(Text(verbatim: gameState.coinsText))
        // El tutorial le abre una ventana en el scrim mientras pide juntar
        // plata: sin ver el contador, "tocá hasta que alcance" no se entiende.
        .tutorialAnchor(.coins)
    }

    /// El `X/s` que antes vivía apretado en la píldora de la torre. Acá está
    /// pegado al monto, que es con lo que se compara.
    ///
    /// Es un elemento de **estado**, no un control: el trío
    /// `children: .ignore` + identifier + value es lo que lo hace legible por
    /// `.value` desde un test. El `HStack` de un solo hijo existe para que el
    /// elemento resultante sea un `otherElement`, como el resto de los estados
    /// del HUD (`hud.coins`, `tower.pill`, `hud.prestige.multiplier`).
    private var incomeRate: some View {
        let rate = "\(gameState.towerIncomePerSecondText)/s"
        return HStack(spacing: 0) {
            Text(verbatim: rate)
                .font(Tokens.caption)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(Color("PaletteInk").opacity(0.7))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("hud.income")
        .accessibilityLabel(Text("hud.income.label"))
        .accessibilityValue(Text(verbatim: rate))
    }

    /// El ascensor abre el mapa de pisos. Conserva id, label y ancla del botón
    /// viejo: es el mismo destino con otra cara.
    private var elevatorButton: some View {
        IconButton(
            artKey: "ui_elevator",
            fallback: { AnyView(VectorElevatorIcon()) },
            // El 0,85 del primer tamaño grande (72), como la moneda.
            size: 61,
            showsPlate: false,
            // La cabina del arte es angosta: estirada a 0,86 del alto queda el
            // ascensor ancho que pidió el dueño (2026-08-18), sin que el trazo
            // ink se note deformado.
            glyphAspect: 0.86,
            tint: Color("PaletteOrange"),
            labelKey: "map.hud.label",
            identifier: "hud.map"
        ) {
            showFloorMap = true
            onMapOpen()
        }
        .tutorialAnchor(.map)
    }

    // MARK: - Reencarnación

    /// RF-16: cuánto potenciador te da reencarnar, siempre a la vista. Lee la
    /// proyección `prestigePreview` que `refreshProjections` publica a 8 Hz —
    /// **nunca** `PlayerState`, que cambia decenas de veces por segundo.
    /// La flecha aparece sólo cuando hay ORO por cobrar: sin nada que ganar, el
    /// "después" sería el "antes" y prometería un salto que no existe.
    private var prestigeIndicator: some View {
        let preview = gameState.prestigePreview
        return HStack(spacing: 5) {
            Image(systemName: "sparkles")
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(Color("PalettePink"))
            Text(verbatim: "×\(preview.multiplierBeforeText)")
            if preview.isWorthIt {
                Image(systemName: "arrow.right")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(Color("PaletteInk").opacity(0.45))
                Text(verbatim: "×\(preview.multiplierAfterText)")
                    .foregroundStyle(Color("PalettePink"))
            }
        }
        .font(Tokens.caption)
        .monospacedDigit()
        .lineLimit(1)
        .foregroundStyle(Color("PaletteInk"))
        .padding(.horizontal, 10)
        .padding(.vertical, 3)
        .background(
            Capsule().fill(Color("PaletteCream"))
                .overlay(Capsule().strokeBorder(Color("PaletteBrown").opacity(0.6), lineWidth: 1.5))
        )
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("hud.prestige.multiplier")
        .accessibilityLabel(Text("hud.prestige.multiplier.label"))
        .accessibilityValue(Text(verbatim: preview.isWorthIt
            ? "×\(preview.multiplierBeforeText) → ×\(preview.multiplierAfterText)"
            : "×\(preview.multiplierBeforeText)"))
    }

}
