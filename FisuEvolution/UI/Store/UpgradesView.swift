import EconomyKit
import SwiftUI

/// Dos bolsillos explícitos: mejoras efímeras por personaje con plata y las
/// siete mejoras globales que sobreviven en ORO.
///
/// Toda fila —de las dos pestañas— dice **qué hace y cuánto**, con el número de
/// ese personaje o de esa línea (RF-04, RF-06). Un "nivel 3/20" no le dice nada
/// a nadie: era la queja principal del playtest.
struct UpgradesView: View {
    private enum Tab: String, CaseIterable, Identifiable {
        case characters
        case permanent
        var id: Self { self }
    }

    @Environment(GameState.self) private var gameState
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: Tab = .characters

    var body: some View {
        let _ = gameState.effectsVersion
        let _ = gameState.coinsText
        let _ = gameState.oroText

        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    tabPicker
                    if selectedTab == .characters {
                        characterRows
                    } else {
                        permanentRows
                    }
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 10)
            }
            .background { PanelBackground(art: "panel_upgrades") }
            .safeAreaInset(edge: .top) {
                VStack(spacing: 7) {
                    PanelTitleBanner(titleKey: "upgrades.title")
                    if selectedTab == .permanent {
                        HStack(spacing: 5) {
                            OroIcon(size: 18)
                            Text("upgrades.oro_balance \(gameState.oroText)")
                                .font(.subheadline.weight(.heavy))
                        }
                        .foregroundStyle(Color("PaletteInk"))
                    }
                }
                .padding(.top, 6)
                .padding(.bottom, 4)
            }
            .navigationTitle(Text(verbatim: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { ArtCloseButton { dismiss() } }
            }
        }
    }

    private var tabPicker: some View {
        HStack(spacing: 8) {
            tabButton(.characters, key: "upgrades.tab.characters", identifier: "upgrades.tab.characters")
            tabButton(.permanent, key: "upgrades.tab.permanent", identifier: "upgrades.tab.permanent")
        }
        .padding(4)
        .background(Capsule().fill(Color("PaletteCream")).overlay(Capsule().stroke(Color("PaletteInk"), lineWidth: 2)))
    }

    private func tabButton(_ tab: Tab, key: LocalizedStringKey, identifier: String) -> some View {
        Button { selectedTab = tab } label: {
            Text(key)
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(selectedTab == tab ? Color.white : Color("PaletteInk"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Capsule().fill(selectedTab == tab ? Color("PaletteBlue") : .clear))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }

    // MARK: Personajes (RF-03, RF-04)

    @ViewBuilder private var characterRows: some View {
        let rows = gameState.characterUpgradeRows
        if rows.isEmpty {
            Text("upgrades.characters.empty")
                .font(.body.weight(.semibold))
                .foregroundStyle(Color("PaletteInk"))
                .padding(.top, 36)
        } else {
            ForEach(rows) { row in
                characterRow(row)
            }
        }
    }

    /// Dos botones: uno compra el ingreso pasivo y otro sube el multiplicador.
    /// Cada uno lleva su costo y arriba dice, en plata y por segundo, qué le hace
    /// a ESTE personaje.
    private func characterRow(_ row: GameState.CharacterUpgradeRow) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            // El encabezado es la vidriera del arte (RF-05): la carita ocupa el
            // doble que antes y el nombre creció con ella para que la cabecera no
            // quede desbalanceada. Las dos líneas de abajo siguen a ancho
            // completo, así que agrandar la cara no le come lugar a lo que
            // explica los botones (RF-04, RF-06).
            HStack(spacing: 12) {
                CharacterFace(
                    faceKey: row.faceKey,
                    tier: row.tier,
                    name: row.displayName,
                    identifier: "upgrades.character.\(row.id).face"
                )
                Text(verbatim: row.displayName)
                    .font(.system(.title3, design: .rounded).weight(.heavy))
                    .foregroundStyle(Color("PaletteInk"))
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
            }

            upgradeLine(
                text: Text("upgrades.character.income \(row.multiplierText) \(row.nextMultiplierText) \(row.displayName)"),
                identifier: "upgrades.character.\(row.id).multiplier",
                enabled: row.canAffordUpgrade,
                tint: Color("PaletteBlue")
            ) {
                gameState.buyCharacterUpgrade(typeID: row.id)
            } label: {
                CoinIcon(size: 16)
                Text(verbatim: CoinFormatter.string(from: row.upgradeCost)).monospacedDigit()
            }

            upgradeLine(
                text: Text(verbatim: row.passiveEffectText),
                identifier: "upgrades.character.\(row.id).passive",
                enabled: row.canAffordPassive && !row.passiveUnlocked,
                tint: Color("PaletteGreen")
            ) {
                gameState.buyPassiveFromMenu(typeId: row.id)
            } label: {
                if row.passiveUnlocked {
                    Image(systemName: "checkmark")
                    Text("upgrades.character.passive_owned")
                } else {
                    CoinIcon(size: 16)
                    Text(verbatim: CoinFormatter.string(from: row.passiveCost)).monospacedDigit()
                }
            }
        }
        .padding(10)
        .background(cardBackground)
    }

    /// Una línea de explicación + su botón. El texto explica; el botón cobra.
    private func upgradeLine<Label: View>(
        text: Text,
        identifier: String,
        enabled: Bool,
        tint: Color,
        action: @escaping () -> Void,
        @ViewBuilder label: () -> Label
    ) -> some View {
        HStack(spacing: 8) {
            text
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color("PaletteInk"))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: action) {
                HStack(spacing: 4) { label() }
                    .font(.subheadline.weight(.heavy))
                    .padding(.horizontal, 9).padding(.vertical, 7)
            }
            .buttonStyle(.borderedProminent).tint(tint).disabled(!enabled)
            .accessibilityIdentifier(identifier)
        }
    }

    // MARK: Permanentes (RF-06)

    @ViewBuilder private var permanentRows: some View {
        ForEach(gameState.content?.upgradesConfig.upgrades ?? []) { line in
            permanentRow(line)
        }
    }

    private func permanentRow(_ line: UpgradesConfig.Line) -> some View {
        let level = gameState.upgradeLevel(of: line.id)
        let cost = gameState.upgradeCost(of: line)
        let maxed = level >= line.maxLevel
        let canAfford = (gameState.player?.meta.oro ?? 0) >= Int(cost.rounded(.up))
        return upgradeCard(leading: {
            if let icon = UIArt.image(line.iconKey) { icon.resizable().scaledToFit().frame(width: 38, height: 38) }
        }, center: {
            Text(LocalizedStringKey(line.titleKey)).font(.headline)
            // La línea numérica sale del JSON (no se puede desincronizar de un
            // cambio de balance); debajo, el chiste que la hace memorable.
            Text(verbatim: gameState.upgradeEffectText(for: line))
                .font(.footnote.weight(.heavy)).foregroundStyle(Color("PaletteInk"))
            Text(verbatim: gameState.upgradeFlavorText(for: line))
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("upgrades.level \(String(level)) \(String(line.maxLevel))")
                .font(.caption2).foregroundStyle(.secondary)
        }, action: {
            gameState.buyUpgrade(lineId: line.id)
        }, cost: {
            OroIcon(size: 16)
            Text(verbatim: String(Int(cost.rounded(.up)))).monospacedDigit()
        }, identifier: "upgrades.permanent.\(line.id)", enabled: canAfford && !maxed)
    }

    private func upgradeCard<Leading: View, Center: View, Cost: View>(
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder center: () -> Center,
        action: @escaping () -> Void,
        @ViewBuilder cost: () -> Cost,
        identifier: String,
        enabled: Bool
    ) -> some View {
        HStack(spacing: 10) {
            leading().frame(width: 40)
            VStack(alignment: .leading, spacing: 3) { center() }
            Spacer(minLength: 4)
            Button(action: action) {
                HStack(spacing: 4) { cost() }
                    .font(.subheadline.weight(.heavy))
                    .padding(.horizontal, 9).padding(.vertical, 7)
            }
            .buttonStyle(.borderedProminent).tint(Color("PaletteBlue")).disabled(!enabled)
            .accessibilityIdentifier(identifier)
        }
        .padding(10)
        .background(cardBackground)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 14).fill(Color("PaletteCream"))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color("PaletteInk"), lineWidth: 2))
    }
}

/// La carita del personaje en el círculo de la fila (RF-05). Sin entrada en el
/// manifest cae al círculo amarillo con el tier, así la pantalla no espera al
/// arte para poder construirse.
private struct CharacterFace: View {
    /// Medía 38 pt hasta el 2026-08-07. El dueño pidió el **doble** para que se
    /// aprecie el arte, y el arte lo banca: las caras son PNG de 192 px, o sea
    /// que a 76 pt todavía sobran píxeles en un @2x.
    static let side: CGFloat = 76

    let faceKey: String?
    let tier: Int
    let name: String
    let identifier: String

    var body: some View {
        Group {
            if let faceKey, let face = UIArt.image(faceKey) {
                face.resizable().scaledToFill()
            } else {
                Color("PaletteYellow").overlay(
                    Text(verbatim: "T\(tier)")
                        .font(.system(.title3, design: .rounded).weight(.heavy))
                        .foregroundStyle(Color("PaletteInk"))
                )
            }
        }
        .frame(width: Self.side, height: Self.side)
        // Respaldo crema: al doble de tamaño, cualquier margen transparente del
        // PNG dejaría ver el fondo de la tarjeta por dentro del círculo.
        .background(Circle().fill(Color("PaletteCream")))
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(Color("PaletteInk"), lineWidth: 3))
        .shadow(color: Color("PaletteInk").opacity(0.22), radius: 3, y: 2)
        // Es un elemento de accesibilidad y no decoración escondida porque el
        // pedido del dueño es un TAMAÑO: una constante en el código no prueba
        // que la fila no lo haya apretado, y el test de UI mide este frame.
        .accessibilityElement()
        .accessibilityLabel(Text(verbatim: name))
        .accessibilityIdentifier(identifier)
    }
}
