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
        // El retrato es una BANDA de la card, no una viñeta dentro de ella: la
        // ocupa entera de arriba abajo contra el borde izquierdo, y el recorte
        // redondeado lo hace la card. Un círculo obliga a inscribir la cabeza en
        // el diámetro y desperdicia las cuatro esquinas — a este tamaño eso es la
        // mitad del arte. `fixedSize` en el texto es lo que decide el alto, y el
        // retrato lo iguala con `maxHeight: .infinity`.
        HStack(spacing: 0) {
            CharacterPortrait(
                faceKey: row.faceKey,
                tier: row.tier,
                name: row.displayName,
                identifier: "upgrades.character.\(row.id).face"
            )

            VStack(alignment: .leading, spacing: 7) {
                Text(verbatim: row.displayName)
                    .font(.system(.title3, design: .rounded).weight(.heavy))
                    .foregroundStyle(Color("PaletteInk"))
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .fixedSize(horizontal: false, vertical: true)

                upgradeLine(
                    text: Text(verbatim: gameState.characterIncomeText(for: row)),
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
            .padding(.horizontal, 11)
            .padding(.vertical, 10)
        }
        // El relleno va detrás y el recorte redondea el retrato contra la
        // esquina; el TRAZO va de overlay al final, encima de todo. Si viaja
        // dentro de `.background` queda debajo del contenido y el fondo opaco
        // del retrato se lo come justo en el borde izquierdo — la card se veía
        // partida en dos, con marco sólo alrededor del texto.
        .background(RoundedRectangle(cornerRadius: 14).fill(Color("PaletteCream")))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color("PaletteInk"), lineWidth: 2))
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
private struct CharacterPortrait: View {
    /// Ancho de la banda. El alto lo pone la card, así que el retrato crece con
    /// el contenido en vez de imponerle un cuadrado. Las caras son PNG de 192 px:
    /// a 104 pt de ancho todavía sobran píxeles en @2x.
    static let width: CGFloat = 104

    let faceKey: String?
    let tier: Int
    let name: String
    let identifier: String

    var body: some View {
        // La base es un rect vacío del tamaño de la banda y el arte va de
        // OVERLAY, no al revés. Con el arte de base, `scaledToFill` desborda y
        // el frame que reporta accesibilidad es el del sprite (un 150×150
        // cuadrado), no el de la banda: `.clipped()` recorta el dibujo pero no
        // corrige esa geometría. Medido el 2026-08-07 — el layout estaba bien y
        // el test leía 150. Con `Color.clear` de base, el rect es el de la banda.
        Color.clear
            .frame(width: Self.width)
            .frame(maxHeight: .infinity)
            .overlay {
                if let faceKey, let face = UIArt.image(faceKey) {
                    // La banda es más alta que ancha y el arte es cuadrado, así
                    // que se recorta a los costados —donde no hay cara— en vez
                    // de dejar franjas de fondo.
                    face.resizable().scaledToFill()
                } else {
                    Color("PaletteYellow").overlay(
                        Text(verbatim: "T\(tier)")
                            .font(.system(.title3, design: .rounded).weight(.heavy))
                            .foregroundStyle(Color("PaletteInk"))
                    )
                }
            }
            // Respaldo crema: el PNG viene con alfa y sin esto se vería el panel
            // a través de la banda.
            .background(Color("PaletteCream"))
            .clipped()
            // Separa el retrato del texto sin encerrarlo: el marco de la card lo
            // rodea por los otros tres lados.
            .overlay(alignment: .trailing) {
                Rectangle().fill(Color("PaletteInk")).frame(width: 2)
            }
            // El identificador va en una capa VACÍA encima, no en el retrato.
            // Medido el 2026-08-07: el frame de accesibilidad de una vista que
            // contiene arte desbordado reporta la geometría del sprite (150×150,
            // el cuadrado de `scaledToFill`) y **no respeta `.clipped()`** —
            // moverlo de lugar en la cadena de modificadores no lo cambia, se
            // probaron tres variantes. Un `Color.clear` sin contenido adentro sí
            // mide la banda, que es lo que el test tiene que juzgar.
            .overlay {
                Color.clear
                    .accessibilityElement()
                    .accessibilityLabel(Text(verbatim: name))
                    .accessibilityIdentifier(identifier)
            }
    }
}
