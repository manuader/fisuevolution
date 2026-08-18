import EconomyKit
import StoreKit
import SwiftUI

/// Ficha por tipo de personaje: apariencia y despedir.
///
/// El pasivo **ya no se compra acá** (RF-04). Se compraba sólo manteniendo
/// apretado un personaje del tablero, un gesto que nadie descubre, y ahora tiene
/// su botón en cada fila del menú de mejoras. Sacada la sección, el long-press
/// —que sigue abriendo esta ficha— pasa a servir únicamente para cambiar la
/// skin, que es lo pedido.
struct CharacterSheetView: View {
    @Environment(GameState.self) private var gameState
    @Environment(StoreManager.self) private var store
    @Environment(\.dismiss) private var dismiss
    let sheet: GameState.CharacterSheet
    @State private var selectedIndex = 0
    @State private var confirmingDismissal = false

    private struct SkinOption: Identifiable {
        let skin: SkinsConfig.Entry?
        var id: String { skin?.id ?? "base" }
    }

    private var options: [SkinOption] {
        [SkinOption(skin: nil)] + gameState.skinOptions(forCharacterType: sheet.type.id).map(SkinOption.init)
    }

    private var selected: SkinOption {
        options.indices.contains(selectedIndex) ? options[selectedIndex] : options[0]
    }

    private var selectedTreatment: SkinResolver.Treatment {
        SkinResolver.treatment(
            for: selected.skin?.id,
            characterType: sheet.type.id,
            config: gameState.content?.skins ?? SkinsConfig(schemaVersion: 1, skins: [])
        )
    }

    private var isSelectedOwned: Bool {
        selected.skin.map { gameState.ownsSkin($0.id) } ?? true
    }

    var body: some View {
        // Proyección observada: entitlements/milestones/equipar refrescan el
        // estado del botón sin observar PlayerState (que cambia 8 veces/s).
        let _ = gameState.skinSelectionVersion
        // El panel se ajusta a su contenido y el Spacer lo empuja arriba: con
        // `.large` a secas el marco decorativo se estiraba a toda la pantalla y
        // quedaba media hoja vacía abajo.
        VStack(spacing: 0) {
            GamePanel(art: "panel_dialog", insets: EdgeInsets(top: 58, leading: 34, bottom: 44, trailing: 34)) {
                ScrollView {
                    VStack(spacing: 12) {
                        header
                        skinPager
                        dismissalSection
                    }
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(16)
        // SÓLo `.large`. Con `.medium` la ficha abría a media pantalla y lo de
        // abajo quedaba tapado por el pliegue: había que descubrir que se
        // scrollea, y no se notaba. Entra todo de una.
        .presentationDetents([.large])
        // El panel ya no ocupa toda la hoja, así que el fondo del sheet dejaba
        // una franja blanca muerta: transparente, el panel flota sobre el juego.
        .presentationBackground(.clear)
        .alert("character.dismiss.title", isPresented: $confirmingDismissal) {
            Button("character.dismiss.confirm", role: .destructive) {
                gameState.dismissCharacter(atCell: sheet.cellIndex)
                dismiss()
            }
            Button("character.dismiss.cancel", role: .cancel) {}
        } message: {
            Text("character.dismiss.message")
        }
        .onAppear { selectActiveSkin() }
    }

    private var header: some View {
        VStack(spacing: 5) {
            CharacterPortrait(
                type: sheet.type,
                treatment: selectedTreatment,
                asSilhouette: !isSelectedOwned
            )
            // El plato de la casa para todo retrato (`JobPortrait`, `SkinCard`):
            // amarillo tenue + borde marrón. El padding va ANTES del frame para
            // que el plato ocupe los mismos 96 pt que ocupaba el retrato pelado
            // y la ficha no cambie de alto. Radio 18 —el de las tarjetas— y no
            // 12 porque acá el retrato no es una celda de lista: es el héroe.
            .padding(6)
            .frame(width: 96, height: 96)
            .background(
                RoundedRectangle(cornerRadius: CardMaterials.cornerRadius, style: .continuous)
                    .fill(Color("PaletteYellow").opacity(0.35))
            )
            .overlay(
                RoundedRectangle(cornerRadius: CardMaterials.cornerRadius, style: .continuous)
                    .strokeBorder(Color("PaletteBrown").opacity(0.7), lineWidth: 2)
            )
            Text(sheet.type.displayName)
                .font(.system(.title2, design: .rounded).weight(.black))
                .foregroundStyle(Color("PaletteInk"))
            // Los Int se interpolan como %lld y no matchean la clave declarada
            // con %@: se pasan como String, igual que `passive.explainer`.
            Text("character.count \(String(sheet.instanceCount))")
                .font(Tokens.body)
                .foregroundStyle(Color("PaletteInk").opacity(0.65))
        }
    }

    private var skinPager: some View {
        // `GameCard` y no el crema translúcido a mano de antes: sobre el
        // pergamino del panel v3 la que despega es la tarjeta de la casa
        // (mismo radio, borde marrón y sombra que todas las filas del juego).
        // El padding interno no cambia: `GameCard` pone los mismos 12.
        GameCard {
            VStack(spacing: 9) {
                HStack(spacing: 14) {
                    Button { moveSelection(by: -1) } label: {
                        PagerChevronLabel(systemName: "chevron.left")
                    }
                    .buttonStyle(.plain)
                    .disabled(selectedIndex == 0)
                    .accessibilityIdentifier("character.skin.previous")

                    VStack(spacing: 3) {
                        Text(skinName)
                            .font(.system(.headline, design: .rounded))
                            .foregroundStyle(Color("PaletteInk"))
                        Text("character.skin.index \(String(selectedIndex + 1)) \(String(options.count))")
                            .font(Tokens.caption)
                            .monospacedDigit()
                            .foregroundStyle(Color("PaletteInk").opacity(0.65))
                    }
                    .frame(maxWidth: .infinity)

                    Button { moveSelection(by: 1) } label: {
                        PagerChevronLabel(systemName: "chevron.right")
                    }
                    .buttonStyle(.plain)
                    .disabled(selectedIndex == options.count - 1)
                    .accessibilityIdentifier("character.skin.next")
                }

                if isSelectedOwned {
                    // El Button y su `.disabled` se conservan tal cual —los
                    // tests pinean esa semántica—: el v3 vive en el label, que
                    // lee `isEnabled` y dibuja cápsula caramelo o badge gris.
                    Button {
                        gameState.equipSkin(id: selected.skin?.id, forCharacterType: sheet.type.id)
                    } label: {
                        EquipButtonLabel(
                            titleKey: isSelectedActive ? "character.skin.equipped" : "character.skin.equip"
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isSelectedActive)
                    .accessibilityIdentifier("character.skin.equip")
                } else {
                    lockedSkinDetails
                }
            }
        }
    }

    @ViewBuilder private var lockedSkinDetails: some View {
        Label("character.skin.locked", systemImage: "lock.fill")
            .font(.system(.body, design: .rounded))
            .foregroundStyle(Color("PaletteInk"))
        Text(unlockDescription)
            .font(.system(.footnote, design: .rounded))
            .foregroundStyle(Color("PaletteInk").opacity(0.75))
            .multilineTextAlignment(.center)
        if let product = selected.skin.flatMap(product(for:)) {
            // La misma cápsula que cobra en toda la casa; gana identifier
            // (regla: todo control interactivo lleva el suyo — este no tenía).
            PricePill(
                text: product.displayPrice,
                currency: .money,
                affordable: true,
                identifier: "character.skin.buy",
                accessibilityPurpose: Text("skins.buy.ax \(skinName)")
            ) {
                Task { await store.purchase(product) }
            }
        }
    }

    @ViewBuilder private var dismissalSection: some View {
        if sheet.canDismiss {
            // Destructivo pero subordinado: cápsula crema de la casa con la
            // firma rosa (texto y borde), no la pill llena — despedir no puede
            // competir con equipar. Button + role intactos: los tests lo listan.
            Button(role: .destructive) { confirmingDismissal = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "person.fill.xmark")
                        .font(.system(size: 14, weight: .black))
                    Text("character.dismiss")
                        .font(Tokens.body)
                }
                .foregroundStyle(Color("PalettePink").deepened(0.25))
                .padding(.horizontal, Tokens.s12)
                .padding(.vertical, Tokens.s8)
                .frame(maxWidth: .infinity)
                .background(
                    PillBackground(
                        fill: Color("PaletteCream"),
                        border: Color("PalettePink").deepened(0.15).opacity(0.75)
                    )
                )
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("character.dismiss")
        }
    }

    private var skinName: String {
        guard let skin = selected.skin else { return String(localized: "character.skin.base") }
        // La resolución (clave del catálogo, o el id embellecido si la skin no
        // declara nombre) vive en el estado desde la T11: el Customization Shop
        // muestra los mismos nombres y dos copias divergen.
        return gameState.skinDisplayName(for: skin)
    }

    private var isSelectedActive: Bool {
        gameState.activeSkinID(forCharacterType: sheet.type.id) == selected.skin?.id
    }

    private var unlockDescription: String {
        guard let skin = selected.skin else { return "" }
        // El id crudo del piso ("urban") no es un nombre: se muestra el
        // localizado, el mismo que usa la pill de la torre.
        if let floor = skin.floorReached {
            return String(localized: "character.skin.reach-floor \(TowerNaming.floorName(for: floor))")
        }
        if let lives = skin.reincarnations { return String(localized: "character.skin.reincarnations \(String(lives))") }
        return String(localized: "character.skin.store")
    }

    private func product(for skin: SkinsConfig.Entry) -> Product? {
        store.products.first { store.skinId(for: $0.id) == skin.id }
    }

    private func selectActiveSkin() {
        let active = gameState.activeSkinID(forCharacterType: sheet.type.id)
        selectedIndex = options.firstIndex { $0.skin?.id == active } ?? 0
    }

    private func moveSelection(by delta: Int) {
        selectedIndex = min(max(selectedIndex + delta, 0), options.count - 1)
    }
}

private struct CharacterPortrait: View {
    let type: CharacterType
    let treatment: SkinResolver.Treatment
    /// Una skin que todavía no tenés no se muestra: se ve su SILUETA en tinta
    /// plena (spec §3.10, "personaje misterioso"). Enseñar el arte a color
    /// regalaría la sorpresa de lo que estás por desbloquear.
    var asSilhouette = false
    @Environment(GameState.self) private var gameState

    var body: some View {
        Group {
            if let image = portrait {
                if asSilhouette {
                    image
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFit()
                        .foregroundStyle(Color("PaletteInk"))
                } else {
                    image
                        .resizable()
                        .scaledToFit()
                        .colorMultiply(tintColor ?? .white)
                }
            } else {
                Image(systemName: "person.fill")
                    .resizable()
                    .scaledToFit()
                    .padding(20)
                    .foregroundStyle(asSilhouette ? Color("PaletteInk") : (tintColor ?? Color("PaletteInk")))
            }
        }
        .accessibilityHidden(true)
    }

    /// Mismo criterio que el tablero (`PlaceholderRenderer`): una skin catalogada
    /// cuyo arte todavía no existe cae al retrato BASE, no al SF Symbol — el
    /// catálogo puede shippear antes que el arte sin que la ficha se degrade.
    private var portrait: Image? {
        guard let asset = gameState.content?.manifest.characters[type.id] else { return nil }
        if let textureKey,
           let skinImage = UIArt.characterImage(atlas: asset.atlas, key: textureKey) {
            return skinImage
        }
        return UIArt.characterImage(atlas: asset.atlas, key: asset.key)
    }

    private var textureKey: String? {
        guard case let .texture(key) = treatment else { return nil }
        return key
    }

    private var tintColor: Color? {
        SkinResolver.swiftUITint(for: treatment)
    }
}

// MARK: - Labels v3 de los controles de sistema

/// La cara v3 del chevron del pager. El `Button` de afuera conserva su
/// `.disabled` —`LaunchSmokeTests` pinea que el del borde está deshabilitado—
/// así que el estado se dibuja acá, leyendo `isEnabled`, sin depender del
/// dimming del sistema (que deja el glifo ilegible, la razón por la que la
/// casa evita `.disabled` en todo lo demás).
private struct PagerChevronLabel: View {
    let systemName: String
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 15, weight: .black))
            .foregroundStyle(Color("PaletteInk").opacity(isEnabled ? 1 : 0.3))
            .frame(width: 34, height: 34)
            .background(
                Circle()
                    .fill(Color("PaletteCream"))
                    .overlay(
                        Circle().strokeBorder(
                            Color("PaletteBrown").opacity(isEnabled ? 0.7 : 0.3),
                            lineWidth: 2
                        )
                    )
            )
            .contentShape(Circle())
    }
}

/// El botón de ponerse la pinta: cápsula caramelo azul cuando se puede, y el
/// gris de estado de la casa cuando ya está puesta — el mismo lenguaje que el
/// par ActionPill/StateBadge de Pintas, pero acá sigue siendo UN `Button`
/// deshabilitado porque los tests pinean esa semántica.
private struct EquipButtonLabel: View {
    let titleKey: LocalizedStringKey
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isEnabled ? "tshirt.fill" : "checkmark.circle.fill")
                .font(.system(size: 15, weight: .black))
            Text(titleKey)
                .font(Tokens.body)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .foregroundStyle(isEnabled ? .white : Color("PaletteInk").opacity(0.6))
        .shadow(color: .black.opacity(isEnabled ? 0.45 : 0), radius: 1, y: 1)
        .padding(.horizontal, Tokens.s12)
        .padding(.vertical, Tokens.s8)
        .frame(minWidth: 92)
        .background {
            if isEnabled {
                PillBackground(fill: Color("PaletteBlue"))
            } else {
                Capsule()
                    .fill(CardMaterials.lockedFill)
                    .overlay(Capsule().strokeBorder(CardMaterials.lockedBorder, lineWidth: 2))
            }
        }
        .contentShape(Capsule())
    }
}
