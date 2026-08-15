import SwiftUI

/// HUD superior estilo Cow Evolution (spec §3): **una** barra contigua con el
/// atajo a la tienda a la izquierda, la plata al centro y el ascensor a la
/// derecha; debajo, la fila compacta de torre y el chip de reencarnación.
///
/// La firma no cambia: sigue recibiendo las cinco closures que `RootView` cablea
/// (`RootView.swift:119-128`). Lo que se reescribió es el cuerpo.
///
/// Observa **proyecciones** de `GameState` (`coinsText`, `towerNavigation`,
/// `towerIncomePerSecondText`, `prestigePreview`), nunca `PlayerState`.
struct HUDView: View {
    @Environment(GameState.self) private var gameState
    var onStoreTap: () -> Void = {}
    var onBonusTap: () -> Void = {}
    var onUpgradesTap: () -> Void = {}
    var onSettingsTap: () -> Void = {}
    /// El mapa se abre desde acá (ver `elevatorButton`), así que el tutorial no
    /// tiene otra forma de enterarse de que su paso se cumplió.
    var onMapOpen: () -> Void = {}
    /// El mapa se presenta desde acá y no desde `RootView` a propósito: vive
    /// pegado a la navegación de la torre, que es lo único que reemplaza.
    @State private var showFloorMap = false

    var body: some View {
        VStack(spacing: Tokens.s4) {
            mainBar
            towerNavigator
            prestigeIndicator
            legacyActionsRow
        }
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 6)
        // Scrim crema translúcido: despega el HUD del arte de fondo (tendedero,
        // graffiti) para que la barra siempre se lea.
        .background {
            LinearGradient(
                colors: [Color("PaletteCream").opacity(0.55), Color("PaletteCream").opacity(0.0)],
                startPoint: .top, endPoint: .bottom
            )
            .padding(.top, -60)   // extiende el scrim bajo la barra de estado
            .allowsHitTesting(false)
        }
        .sheet(isPresented: $showFloorMap) { FloorMapView() }
        .tutorialAnchor(.hudBar)
    }

    // MARK: - Barra contigua

    /// La pieza principal del HUD: **una sola** tarjeta crema de ancho completo.
    /// Reemplaza a la fila de botones sueltos + píldora de monedas de antes, que
    /// se leía como cinco objetos distintos flotando sobre el tablero.
    ///
    /// Usa `GameCard` y no un fondo propio: es exactamente el panel crema con
    /// contorno ink del design system v2, y duplicarlo acá sería un estilo más
    /// que mantener.
    private var mainBar: some View {
        GameCard {
            HStack(spacing: Tokens.s8) {
                coinsPlusButton
                Spacer(minLength: Tokens.s4)
                coinsColumn
                Spacer(minLength: Tokens.s4)
                elevatorButton
            }
            .frame(maxWidth: .infinity)
        }
    }

    /// Atajo a la tienda: la moneda con el `+` rosa. Mismo destino que el
    /// carrito (`onStoreTap`), pero puesto donde el jugador mira justo cuando
    /// descubre que no le alcanza.
    private var coinsPlusButton: some View {
        IconButton(
            artKey: "ui_coin_plus",
            fallback: { AnyView(VectorCoinPlusIcon()) },
            size: 52,
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

    private var coinsAmount: some View {
        HStack(spacing: Tokens.s4) {
            CoinIcon(size: 26)
            Text(verbatim: gameState.coinsText)
                .font(Tokens.display)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .foregroundStyle(Color("PaletteInk"))
        }
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
            size: 52,
            tint: Color("PaletteOrange"),
            labelKey: "map.hud.label",
            identifier: "hud.map"
        ) {
            showFloorMap = true
            onMapOpen()
        }
        .tutorialAnchor(.map)
    }

    // MARK: - Fila de torre

    /// Bajar · piso · subir. El coins/sec se mudó a la barra de arriba, así que
    /// acá queda lo que describe al piso: cómo se llama y cuánta gente entra.
    private var towerNavigator: some View {
        let navigation = gameState.towerNavigation
        // ⚠️ Trampa 5 del handoff, viva hasta hoy en esta línea: la versión
        // anterior metía cuatro `Int` en un `Text(_:)`, que arma la clave
        // `%lld/%lld · …` y jamás encuentra la del catálogo (que es `%@`) — la
        // clave `%@/%@ · %@/%@ · %@/s` estaba MUERTA y se borró con este commit.
        // Un cociente de números no se traduce: va `verbatim`, sin clave y sin
        // lookup posible. El tipo va anotado para que nadie lo vuelva a
        // convertir en `LocalizedStringKey` sin darse cuenta.
        let occupancy: String = "\(navigation.occupied)/\(navigation.capacity)"
        return HStack(spacing: Tokens.s8) {
            towerArrow(systemName: "chevron.down", direction: -1, enabled: navigation.canNavigateDown, identifier: "tower.arrow.down")
            HStack(spacing: 6) {
                Text(floorNameKey(for: navigation.floorID))
                    .font(Tokens.body)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(verbatim: occupancy)
                    .font(Tokens.caption)
                    .monospacedDigit()
                    .lineLimit(1)
                    .foregroundStyle(Color("PaletteInk").opacity(0.65))
            }
            .foregroundStyle(Color("PaletteInk"))
            .frame(minWidth: 120)
            .accessibilityElement(children: .ignore)
            .accessibilityIdentifier("tower.pill")
            .accessibilityLabel(Text(floorNameKey(for: navigation.floorID)))
            .accessibilityValue(Text(verbatim: occupancy))
            towerArrow(systemName: "chevron.up", direction: 1, enabled: navigation.canNavigateUp, identifier: "tower.arrow.up")
        }
        .padding(.horizontal, Tokens.s8)
        .padding(.vertical, 5)
        .background(Capsule().fill(Color("PaletteCream")).overlay(Capsule().strokeBorder(Color("PaletteInk"), lineWidth: 2)))
    }

    private func towerArrow(systemName: String, direction: Int, enabled: Bool, identifier: String) -> some View {
        Button {
            _ = gameState.moveVisibleFloor(by: direction)
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(enabled ? Color("PaletteBlue") : Color("PaletteInk").opacity(0.28))
                .frame(width: 26, height: 26)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityIdentifier(identifier)
        .accessibilityLabel(Text(direction > 0 ? "tower.navigate.up" : "tower.navigate.down"))
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
                .overlay(Capsule().strokeBorder(Color("PaletteInk").opacity(0.6), lineWidth: 1.5))
        )
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("hud.prestige.multiplier")
        .accessibilityLabel(Text("hud.prestige.multiplier.label"))
        .accessibilityValue(Text(verbatim: preview.isWorthIt
            ? "×\(preview.multiplierBeforeText) → ×\(preview.multiplierAfterText)"
            : "×\(preview.multiplierBeforeText)"))
    }

    private func floorNameKey(for floorID: String) -> LocalizedStringKey {
        TowerNaming.floorNameKey(for: floorID)
    }

    // MARK: - Transitorio

    // TRANSITORIO: estos 4 botones se mudan a la barra inferior en la tarea siguiente (no estilar)
    private var legacyActionsRow: some View {
        HStack(spacing: 8) {
            hudIconButton(systemName: "cart.fill", tint: Color("PaletteOrange"), labelKey: "hud.store.label", identifier: "hud.store", action: onStoreTap)
            hudIconButton(systemName: "arrow.up.circle.fill", tint: Color("PaletteGreen"), labelKey: "hud.upgrades.label", identifier: "hud.upgrades", action: onUpgradesTap)
                .tutorialAnchor(.upgrades)
            hudIconButton(systemName: "gift.fill", tint: Color("PalettePink"), labelKey: "hud.bonus.label", identifier: "hud.bonus", action: onBonusTap)
            hudIconButton(systemName: "gearshape.fill", tint: Color("PaletteBlue"), labelKey: "hud.settings.label", identifier: "hud.settings", action: onSettingsTap)
        }
    }

    /// Botón de icono unificado: misma base (círculo crema + borde ink), mismo
    /// tamaño; el color del glifo codifica la función.
    // TRANSITORIO: se va con `legacyActionsRow` en la tarea siguiente (no estilar)
    private func hudIconButton(systemName: String, tint: Color, labelKey: String, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 52, height: 52)
                .background(
                    Circle().fill(Color("PaletteCream"))
                        .overlay(Circle().strokeBorder(Color("PaletteInk"), lineWidth: 3))
                        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
        .accessibilityLabel(Text(LocalizedStringKey(labelKey)))
    }
}
