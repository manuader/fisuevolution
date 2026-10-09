import SwiftUI

/// HUD superior estilo Cow Evolution (spec §3): **una** barra contigua con el
/// atajo a la tienda a la izquierda, la plata al centro y el ascensor a la
/// derecha; debajo, la fila compacta de torre y el chip de reencarnación.
///
/// Quedan **dos** closures de las cinco que recibía: bonus, mejoras y ajustes se
/// mudaron a la barra inferior (`BottomMenuBar`) junto con la fila transitoria
/// de cuatro íconos que vivía acá. La tienda ya no está en la barra: la moneda
/// con el `+` es **la** entrada (PLAN-v2 E13, ítem 14).
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

    /// Aire mínimo entre el borde FÍSICO de arriba y la fila principal. Sólo
    /// entra cuando la safe area de arriba se desploma: en el SE, con la barra de
    /// estado oculta (`RootView.statusBarHidden`), es 0 y la fila se iría contra
    /// el bezel. Medido en un SE 3 antes del piso: los botones a 5 pt del borde.
    private static let minimumTopGap: CGFloat = 14

    /// Margen de la botonera contra el borde derecho. En DEBUG la llave del
    /// panel de debug (`GameBoardView.debugButton`) flota justo en ese rincón: la
    /// botonera se corre a su izquierda para que no la tape ni la tape ella.
    private static var elevatorTrailingInset: CGFloat {
        #if DEBUG
        if !GameBoardView.isScreenshotMode { return Tokens.s12 + 52 }
        #endif
        return Tokens.s12
    }

    /// Cuánto baja la fila principal desde el borde de la safe area.
    ///
    /// El diseño la quiere pegada arriba (de ahí el 2), pero nunca más cerca de
    /// `minimumTopGap` del borde físico. En un teléfono con notch el inset solo
    /// ya alcanza y de sobra, así que el `max` devuelve el 2 de siempre y el piso
    /// **no cambia nada**; sólo entra a jugar cuando el inset se desploma.
    private var mainBarTopPadding: CGFloat {
        max(2, ScreenInsets.floorGap(minimum: Self.minimumTopGap, inset: ScreenInsets.shared.top))
    }

    var body: some View {
        VStack(spacing: Tokens.s4) {
            mainBar
                .padding(.horizontal, Tokens.s12)
                .padding(.top, mainBarTopPadding)
                .padding(.bottom, Tokens.s12)
                .playColumn()
                .background { topPanel }
            prestigeIndicator
                .frame(maxWidth: .infinity, minHeight: ElevatorPanel.displayHeight, alignment: .top)
                .overlay(alignment: .topTrailing) {
                    // Contra el borde derecho, debajo del ícono del ascensor
                    // (`hud.map`, que sigue abriendo el mapa). La fila reserva el
                    // alto del display; la persiana desplegada flota por encima
                    // del tablero mientras dura.
                    ElevatorPanel()
                        .padding(.trailing, Self.elevatorTrailingInset)
                }
        }
        .background(ScreenInsetsReader().accessibilityHidden(true))
        // El panel del `panelSheet` ES la hoja: flota sobre el juego atenuado
        // con la banda inferior a la vista (como las seis de la barra, en
        // `RootView`).
        .fisuSheet(isPresented: $showFloorMap) {
            FloorMapView()
        }
        .tutorialAnchor(.hudBar)
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
        // Al 80% el tablero se adivina detrás de la barra (pedido del dueño,
        // 2026-08-19; la inferior va al 90% — el contador de arriba tolera más
        // fondo que los labels chicos de los tabs). El contorno ink queda
        // opaco: es el trazo, no el fondo.
        .fill(Color("PaletteCream").opacity(0.8))
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

    /// La entrada a la tienda: la moneda con el `+` rosa, puesta donde el
    /// jugador mira justo cuando descubre que no le alcanza. Lleva el ancla de la
    /// lección `.store` del tutorial.
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
        .tutorialAnchor(.store)
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
