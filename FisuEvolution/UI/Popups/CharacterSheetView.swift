import EconomyKit
import StoreKit
import SwiftUI

/// La ficha de un personaje: su pinta en grande, cambiarla y despedirlo
/// (PLAN-v2 E3). Es una pantalla con el andamio de FisuJobs —`NavigationStack`
/// + `panelSheet` + la X de la casa— y no una tarjeta suelta.
///
/// El pasivo **no se compra acá** (RF-04): lo vende cada fila de Mejoras.
struct CharacterSheetView: View {
    @Environment(GameState.self) private var gameState
    @Environment(StoreManager.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let sheet: GameState.CharacterSheet
    @State private var selectedID = SkinOption.baseID
    @State private var confirmingDismissal = false

    /// La pinta en grande: hasta 248 pt (216 en el SE), ~2,6× la de la v1.
    static let portraitMaxSide: CGFloat = 248

    private struct SkinOption: Identifiable {
        static let baseID = "base"
        let skin: SkinsConfig.Entry?
        var id: String { skin?.id ?? Self.baseID }
    }

    private var options: [SkinOption] {
        [SkinOption(skin: nil)] + gameState.skinOptions(forCharacterType: sheet.type.id).map(SkinOption.init)
    }

    private var selectedIndex: Int { options.firstIndex { $0.id == selectedID } ?? 0 }
    private var selected: SkinOption { options[selectedIndex] }

    var body: some View {
        // Proyección observada: entitlements, milestones y equipar refrescan la
        // ficha sin observar `PlayerState`.
        let _ = gameState.skinSelectionVersion
        NavigationStack {
            ScrollView {
                VStack(spacing: Tokens.s16) {
                    pager
                    names
                    thumbnails
                    action
                    dismissal
                }
                .padding(.horizontal, WoodPanelBackground.columnInset)
                .padding(.top, Tokens.s8)
                .padding(.bottom, Tokens.s24)
            }
            .scrollBounceBehavior(.basedOnSize)
            .panelSheet { header }
            .navigationTitle(Text(verbatim: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { ArtCloseButton { dismiss() } }
            }
        }
        .overlay {
            if confirmingDismissal {
                GameConfirmCard(
                    titleKey: "character.dismiss.title",
                    message: Text("character.dismiss.message"),
                    confirmTitleKey: "character.dismiss.confirm",
                    confirmSystemImage: "person.fill.xmark",
                    cancelTitleKey: "character.dismiss.cancel",
                    onConfirm: {
                        gameState.dismissCharacter(floorOrdinal: sheet.floorOrdinal, slot: sheet.cellIndex)
                        dismiss()
                    },
                    onCancel: { confirmingDismissal = false }
                )
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: confirmingDismissal)
        .fisuSheet()
        .onAppear {
            selectActiveSkin()
            gameState.audio?.play(.revealWhoosh)
        }
    }

    // MARK: Cabecera

    private var header: some View {
        VStack(spacing: Tokens.s4) {
            PanelTitleBanner(verbatim: sheet.type.localizedName)
            // Los Int se interpolan como %lld y no matchean la clave declarada
            // con %@: van como String.
            Text("character.count \(String(sheet.instanceCount))")
                .font(Tokens.caption)
                .foregroundStyle(Color("PaletteInk").opacity(0.75))
        }
    }

    // MARK: La pinta en grande

    private var pager: some View {
        HStack(spacing: Tokens.s8) {
            PagerChevronButton(direction: .previous, identifier: "character.skin.previous") { move(by: -1) }
                .disabled(selectedIndex == 0)
            TabView(selection: $selectedID) {
                ForEach(options) { option in
                    CharacterPortrait(
                        type: sheet.type,
                        treatment: treatment(for: option),
                        asSilhouette: !owns(option),
                        animated: option.skin == nil
                    )
                    .padding(Tokens.s16)
                    .tag(option.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(maxWidth: Self.portraitMaxSide)
            .aspectRatio(1, contentMode: .fit)
            .background(portraitPlate)
            // El marcador del test de UI: el tamaño real del retrato y qué pinta
            // muestra (de FONDO, como `board.units`).
            .background(
                Color.clear
                    .accessibilityElement()
                    .accessibilityIdentifier("character.portrait")
                    .accessibilityValue(Text(verbatim: selectedID))
            )
            PagerChevronButton(direction: .next, identifier: "character.skin.next") { move(by: 1) }
                .disabled(selectedIndex == options.count - 1)
        }
    }

    private var portraitPlate: some View {
        RoundedRectangle(cornerRadius: CardMaterials.cornerRadius, style: .continuous)
            .fill(Color("PaletteYellow").opacity(0.35))
            .overlay(
                RoundedRectangle(cornerRadius: CardMaterials.cornerRadius, style: .continuous)
                    .strokeBorder(Color("PaletteBrown").opacity(0.7), lineWidth: 2)
            )
    }

    private var names: some View {
        VStack(spacing: 3) {
            Text(verbatim: skinName(selected))
                .font(Tokens.title)
                .foregroundStyle(Color("PaletteInk"))
            Text("character.skin.index \(String(selectedIndex + 1)) \(String(options.count))")
                .font(Tokens.caption)
                .monospacedDigit()
                .foregroundStyle(Color("PaletteInk").opacity(0.65))
        }
    }

    // MARK: La tira de miniaturas

    private var thumbnails: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Tokens.s8) {
                ForEach(options) { option in
                    Button {
                        withAnimation(reduceMotion ? nil : .snappy) { selectedID = option.id }
                    } label: {
                        thumbnail(option)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("character.skin.thumb.\(option.id)")
                    .accessibilityLabel(Text(verbatim: skinName(option)))
                    .accessibilityAddTraits(option.id == selectedID ? .isSelected : [])
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, Tokens.s4)
        }
    }

    private func thumbnail(_ option: SkinOption) -> some View {
        let isSelected = option.id == selectedID
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        return CharacterPortrait(type: sheet.type, treatment: treatment(for: option), asSilhouette: !owns(option))
            .padding(4)
            .frame(width: 52, height: 52)
            .background(shape.fill(Color("PaletteYellow").opacity(isSelected ? 0.55 : 0.2)))
            .overlay(shape.strokeBorder(Color("PaletteBrown").opacity(isSelected ? 0.9 : 0.4), lineWidth: isSelected ? 2.5 : 1.5))
    }

    // MARK: Ponérsela o comprarla

    @ViewBuilder private var action: some View {
        if owns(selected) {
            if isActive(selected) {
                StateBadge(
                    text: String(localized: "skins.equipped"),
                    systemImage: "checkmark.circle.fill",
                    textAlignment: .center,
                    muted: true
                )
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("character.skin.wearing")
            } else {
                ActionPill(
                    titleKey: "character.skin.equip",
                    systemImage: "tshirt.fill",
                    tint: Color("PaletteBlue"),
                    identifier: "character.skin.equip",
                    accessibilityLabel: Text("character.skin.equip.ax \(skinName(selected))")
                ) {
                    gameState.equipSkin(id: selected.skin?.id, forCharacterType: sheet.type.id)
                }
            }
        } else {
            lockedDetails
        }
    }

    @ViewBuilder private var lockedDetails: some View {
        Label("character.skin.locked", systemImage: "lock.fill")
            .font(.system(.body, design: .rounded))
            .foregroundStyle(Color("PaletteInk"))
        Text(unlockDescription)
            .font(.system(.footnote, design: .rounded))
            .foregroundStyle(Color("PaletteInk").opacity(0.75))
            .multilineTextAlignment(.center)
        if let product = selected.skin.flatMap(product(for:)) {
            PricePill(
                text: product.displayPrice,
                currency: .money,
                affordable: true,
                identifier: "character.skin.buy",
                accessibilityPurpose: Text("skins.buy.ax \(skinName(selected))")
            ) {
                Task { await store.purchase(product) }
            }
        }
        if let skin = selected.skin, let price = gameState.content?.skins.oroPrice(of: skin.id) {
            PricePill(
                text: String(price),
                currency: .oro,
                affordable: (gameState.player?.meta.oro ?? 0) >= price,
                identifier: "character.skin.buyOro",
                accessibilityPurpose: Text("skins.buy.ax \(skinName(selected))")
            ) {
                gameState.buySkinWithOro(skinID: skin.id)
            }
        }
    }

    // MARK: Despedir

    @ViewBuilder private var dismissal: some View {
        if sheet.canDismiss {
            // Destructivo pero subordinado: cápsula crema con la firma rosa, no
            // la pill llena — despedir no compite con ponérsela.
            Button { confirmingDismissal = true } label: {
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

    // MARK: Datos

    private func owns(_ option: SkinOption) -> Bool {
        option.skin.map { gameState.ownsSkin($0.id) } ?? true
    }

    private func isActive(_ option: SkinOption) -> Bool {
        gameState.activeSkinID(forCharacterType: sheet.type.id) == option.skin?.id
    }

    private func treatment(for option: SkinOption) -> SkinResolver.Treatment {
        SkinResolver.treatment(
            for: option.skin?.id,
            characterType: sheet.type.id,
            config: gameState.content?.skins ?? SkinsConfig(schemaVersion: 1, skins: [])
        )
    }

    private func skinName(_ option: SkinOption) -> String {
        guard let skin = option.skin else { return String(localized: "character.skin.base") }
        return gameState.skinDisplayName(for: skin)
    }

    private var unlockDescription: String {
        guard let skin = selected.skin else { return "" }
        if let floor = skin.floorReached {
            return String(localized: "character.skin.reach-floor \(gameState.floorDisplayName(for: floor))")
        }
        if let lives = skin.reincarnations { return String(localized: "character.skin.reincarnations \(String(lives))") }
        if gameState.content?.skins.oroPrice(of: skin.id) != nil { return String(localized: "character.skin.oro_shop") }
        return String(localized: "character.skin.store")
    }

    private func product(for skin: SkinsConfig.Entry) -> Product? {
        store.products.first { store.skinId(for: $0.id) == skin.id }
    }

    private func selectActiveSkin() {
        let active = gameState.activeSkinID(forCharacterType: sheet.type.id)
        selectedID = options.first { $0.skin?.id == active }?.id ?? SkinOption.baseID
    }

    private func move(by delta: Int) {
        let target = min(max(selectedIndex + delta, 0), options.count - 1)
        withAnimation(reduceMotion ? nil : .snappy) { selectedID = options[target].id }
    }
}

private struct CharacterPortrait: View {
    let type: CharacterType
    let treatment: SkinResolver.Treatment
    /// Una skin que todavía no tenés no se muestra: se ve su SILUETA en tinta
    /// plena (spec §3.10, "personaje misterioso"). Enseñar el arte a color
    /// regalaría la sorpresa de lo que estás por desbloquear.
    var asSilhouette = false
    /// El video es del cuerpo entero con la pinta canónica: una pinta puesta, o la silueta, no anima.
    var animated = false
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
                } else if animated {
                    AnimatedArtView(clip: .character(type.id), role: .popup) {
                        image
                            .resizable()
                            .scaledToFit()
                            .colorMultiply(tintColor ?? .white)
                    }
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
