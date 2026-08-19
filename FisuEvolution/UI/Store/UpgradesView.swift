import EconomyKit
import SwiftUI

/// Dos bolsillos explícitos: mejoras efímeras por personaje con plata y las
/// siete mejoras globales que sobreviven en ORO.
///
/// Toda fila —de las dos pestañas— dice **qué hace y cuánto**, con el número de
/// ese personaje o de esa línea (RF-04, RF-06). Un "nivel 3/20" no le dice nada
/// a nadie: era la queja principal del playtest.
///
/// El restyle no le tocó una línea a la lógica: las mismas
/// proyecciones (`characterUpgradeRows`, `upgradeLevel/Cost/EffectText/FlavorText`)
/// y los mismos identifiers. Lo que cambió es el idioma visual —`GameCard`,
/// `ProgressBar`, `PricePill`, `Tokens`— y que la cabecera dejó de ser
/// transparente.
struct UpgradesView: View {
    private enum Tab: String, CaseIterable, Identifiable {
        case characters
        case permanent
        var id: Self { self }
    }

    @Environment(GameState.self) private var gameState
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: Tab = .characters

    /// Margen lateral de la columna: el del marco vectorial, publicado por el
    /// componente. Un solo número para las nueve hojas — el marco es el
    /// contenedor y las tarjetas viven ADENTRO (pedido del dueño, 2026-08-18;
    /// antes eran cuatro insets medidos PNG por PNG contra el arte 9-slice,
    /// que además se deformaba al estirarse).
    private static let panelInset: CGFloat = WoodPanelBackground.columnInset

    var body: some View {
        let _ = gameState.effectsVersion
        let _ = gameState.coinsText
        let _ = gameState.oroText

        NavigationStack {
            ScrollView {
                VStack(spacing: Tokens.s12) {
                    if selectedTab == .characters {
                        characterRows
                    } else {
                        permanentRows
                    }
                }
                .padding(.horizontal, Self.panelInset)
                .padding(.top, Tokens.s12)
                .padding(.bottom, Tokens.s24)
            }
            // Madera como el resto de los negocios (pedido del dueño,
            // 2026-08-18: el metal la hacía "de otra familia"). El metal quedó
            // para el Ascensor, que es la única maquinaria de verdad.
            .panelSheet(awning: true) { header }
            .navigationTitle(Text(verbatim: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { ArtCloseButton { dismiss() } }
            }
        }
    }

    // MARK: Cabecera

    /// Título, pestañas y —en Permanentes— el saldo de ORO, ADENTRO del panel
    /// metálico. Sin banda opaca: el `panelSheet` recorta el scroll por debajo
    /// de la cabecera, y la banda tapaba el marco (2026-08-18).
    ///
    /// Las pestañas viven acá y no en el cuerpo del scroll: son el control que
    /// gobierna la lista y quedarse sin ellas al bajar dos filas obligaba a
    /// volver arriba para cambiar de bolsillo.
    private var header: some View {
        VStack(spacing: Tokens.s8) {
            // El mismo glifo que el tab que abre esta hoja, ADENTRO de la
            // cápsula del título (composición de las referencias, igual que
            // Regalos, Pintas y la Tienda). El banner ya lo tapa de VoiceOver.
            PanelTitleBanner(
                titleKey: "upgrades.title",
                icon: AnyView(GameIcon(artKey: "ui_tab_upgrades", size: 26) { VectorTabUpgradesIcon() })
            )
            tabPicker
            if selectedTab == .permanent {
                oroBalance
            }
        }
    }

    /// Lo que hay para gastar en esta pestaña. Sin esto, la única forma de saber
    /// si un precio en ORO estaba a tiro era cerrar la hoja e ir al HUD.
    ///
    /// ⚠️ La moneda va tapada de VoiceOver, como los glifos de las filas: el
    /// texto de al lado ya dice "ORO: 240" y la imagen sola dejaba una parada
    /// muda entre las pestañas y la lista (el mismo defecto, el octavo glifo de
    /// esta pestaña).
    private var oroBalance: some View {
        HStack(spacing: Tokens.s4) {
            OroIcon(size: 18)
                .accessibilityHidden(true)
            Text("upgrades.oro_balance \(gameState.oroText)")
                .font(Tokens.body)
                .monospacedDigit()
                .foregroundStyle(Color("PaletteInk"))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, Tokens.s16)
        .padding(.vertical, 6)
        .background {
            Capsule()
                .fill(Color("PaletteYellow").opacity(0.35))
                .overlay(Capsule().strokeBorder(Color("PaletteBrown").opacity(0.6), lineWidth: 2))
        }
    }

    /// Las dos pestañas. Se moderniza el dibujo —groove hundido, cápsula de
    /// acento y transición— pero los dos identifiers son los que pinean
    /// `BottomMenuUITests`, `TutorialUITests`, `LaunchSmokeTests` y los dos
    /// tests de mejoras: no se tocan.
    ///
    /// ⚠️ El `HStack` no lleva identifier (trampa 9a-bis): lo lleva cada botón.
    private var tabPicker: some View {
        HStack(spacing: Tokens.s4) {
            tabButton(.characters, key: "upgrades.tab.characters", identifier: "upgrades.tab.characters")
            tabButton(.permanent, key: "upgrades.tab.permanent", identifier: "upgrades.tab.permanent")
        }
        .padding(Tokens.s4)
        .background {
            Capsule()
                .fill(Color("PaletteBrown").opacity(0.12))
                .overlay(Capsule().strokeBorder(Color("PaletteBrown").opacity(0.55), lineWidth: 2))
        }
        .animation(.snappy(duration: 0.2), value: selectedTab)
    }

    /// El glifo de cada pestaña (referencia v3: la persona para Personajes, la
    /// estrella para Permanentes). Decoración —el texto de al lado ya lo
    /// dice—, así que va tapado de VoiceOver.
    private static func tabGlyph(_ tab: Tab) -> String {
        switch tab {
        case .characters: "person.fill"
        case .permanent: "star.fill"
        }
    }

    private func tabButton(_ tab: Tab, key: LocalizedStringKey, identifier: String) -> some View {
        let selected = selectedTab == tab
        return Button { selectedTab = tab } label: {
            HStack(spacing: 6) {
                Image(systemName: Self.tabGlyph(tab))
                    .font(.system(size: 13, weight: .black))
                    .accessibilityHidden(true)
                Text(key)
                    .font(Tokens.body)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(selected ? Color.white : Color("PaletteInk").opacity(0.55))
            .shadow(color: .black.opacity(selected ? 0.35 : 0), radius: 1, y: 1)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Tokens.s8)
            .background {
                // Naranja, como la pestaña activa de la referencia (era azul).
                if selected {
                    PillBackground(fill: Color("PaletteOrange"))
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }

    // MARK: Personajes (RF-03, RF-04)

    @ViewBuilder private var characterRows: some View {
        let rows = gameState.characterUpgradeRows
        if rows.isEmpty {
            GameCard {
                Text("upgrades.characters.empty")
                    .font(Tokens.body)
                    .foregroundStyle(Color("PaletteInk"))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Tokens.s12)
            }
            .padding(.top, Tokens.s24)
        } else {
            // Cascada de entrada del panel (spec §11.2). Se recalcula al cambiar
            // de pestaña, que es lo correcto: son otras tarjetas entrando.
            ForEach(Array(rows.enumerated()), id: \.element.id) { offset, row in
                characterRow(row)
                    .staggeredAppearance(index: offset)
            }
        }
    }

    /// Dos compras: una sube el multiplicador y otra abre el ingreso pasivo.
    /// Cada una lleva su precio al lado del renglón que explica qué le hace a
    /// ESTE personaje.
    ///
    /// ⚠️ **No usa `GameCard`** aunque copie su dibujo punto por punto (radio 14,
    /// crema, contorno ink de 2 y la misma sombra). El retrato es una BANDA que
    /// llega hasta los bordes de la tarjeta, y para eso hace falta un
    /// `clipShape` que `GameCard` a propósito no tiene: su sombra vive en el
    /// `background`, así que recortarla la borraría. Los 12 pt de padding de
    /// `GameCard` tampoco dejarían pegar el retrato al borde. El relleno va
    /// detrás, el recorte redondea el retrato contra la esquina y el TRAZO va de
    /// overlay al final, encima de todo: dentro de `.background` queda debajo
    /// del contenido y el fondo opaco del retrato se lo come justo en el borde
    /// izquierdo (la tarjeta se veía partida en dos, con marco sólo alrededor
    /// del texto).
    private func characterRow(_ row: GameState.CharacterUpgradeRow) -> some View {
        let shape = RoundedRectangle(cornerRadius: CardMaterials.cornerRadius, style: .continuous)
        return HStack(spacing: 0) {
            CharacterPortrait(
                faceKey: row.faceKey,
                tier: row.tier,
                name: row.displayName,
                identifier: "upgrades.character.\(row.id).face"
            )

            VStack(alignment: .leading, spacing: 6) {
                // Lo escrito, no lo hablado: **quien DICE el nombre es el
                // retrato**, que es el único elemento de la fila con identifier
                // y frame propios (ver `CharacterPortrait`). Si este `Text`
                // también fuera elemento, VoiceOver leería el nombre dos veces
                // — el defecto del HANDOFF §8 que el spec §6 manda arreglar.
                Text(verbatim: row.displayName)
                    .font(Tokens.title)
                    .foregroundStyle(Color("PaletteInk"))
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityHidden(true)

                upgradeLine(text: gameState.characterIncomeText(for: row), accent: Color("PaletteBlue")) {
                    if row.upgradeMaxed {
                        // Nivel 20/20: la fila deja de vender e informa, con el
                        // MISMO badge y las mismas palabras que una permanente
                        // al máximo ("Al máximo" es una felicitación, no un
                        // límite que el jugador esté chocando — y `purchase`
                        // rechaza con `maxLevelReached`, que sonaría a error).
                        StateBadge(
                            text: String(localized: "upgrades.maxed"),
                            systemImage: "star.circle.fill",
                            textAlignment: .center,
                            muted: false
                        )
                        // El mismo hueco que el `PricePill` (riel de 92): sin él,
                        // el renglón del contador se estira SÓLO en las filas al
                        // tope y la lista baila entre estados.
                        .frame(minWidth: 92, alignment: .trailing)
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("upgrades.character.\(row.id).maxed")
                    } else {
                        PricePill(
                            text: CoinFormatter.string(from: row.upgradeCost),
                            currency: .coins,
                            affordable: row.canAffordUpgrade,
                            identifier: "upgrades.character.\(row.id).multiplier",
                            // Las dos cápsulas de la fila son verdes, dicen un monto
                            // en monedas y están una debajo de la otra: sin decir cuál
                            // es cuál, la única forma de saberlo es el orden de
                            // lectura. El nombre va porque en el rotor las N filas
                            // repiten estos dos botones.
                            accessibilityPurpose: Text("upgrades.ax.multiplier \(row.displayName)")
                        ) {
                            gameState.buyCharacterUpgrade(typeID: row.id)
                        }
                    }
                }

                upgradeLine(text: row.passiveEffectText, accent: Color("PaletteGreen")) {
                    if row.passiveUnlocked {
                        // Comprado: la fila deja de vender y pasa a **informar**,
                        // y eso lo dibuja el `StateBadge` compartido —el mismo
                        // que ya usan FisuJobs, el Shop, la tienda y Regalos—.
                        // Era una cápsula propia de esta pantalla, y encima un
                        // `Button` cuya acción hubo que vaciar porque
                        // `buyPassiveFromMenu` rechaza con `alreadyUnlocked` y
                        // ese rechazo suena a error: tocar "Ya genera", que es la
                        // cápsula de LO QUE SALIÓ BIEN, te retaba. Un badge no es
                        // un control, así que no queda toque que castigar ni
                        // acción vacía que explicar.
                        StateBadge(
                            text: String(localized: "upgrades.character.passive_owned"),
                            systemImage: "checkmark.circle.fill",
                            textAlignment: .center,
                            muted: false
                        )
                        // El badge se sirve en el MISMO hueco que el `PricePill`
                        // (mínimo 92, pegado al borde). Es el riel fijo de
                        // FisuJobs y de Logros —`railWidth`— aplicado en el
                        // llamador, no un resto de la cápsula vieja: el badge
                        // mide 79 pt contra los 92 del precio (medido sobre la
                        // captura del 2026-08-16), y sin el hueco esos 13 pt se
                        // los queda el renglón del efecto SÓLO en las filas
                        // compradas: la lista baila entre estados.
                        .frame(minWidth: 92, alignment: .trailing)
                        // Upgrades navega por PARADAS (la fila colapsada es de
                        // FisuJobs; decisión del controller de no unificar los
                        // dos modelos), y acá el estado no viaja en ningún valor
                        // de fila: este badge es la única parada que lo dice. Por
                        // eso NO va `accessibilityHidden` como en FisuJobs — va
                        // combinado, para que sea UNA parada y el glifo no quede
                        // como una parada muda al lado. Mismo patrón que los
                        // badges de `GiftsView`.
                        //
                        // ⚠️ El identifier ya no es el de la compra: ese
                        // (`upgrades.character.<id>.passive`) sigue en el
                        // `PricePill` de al lado, que es el control de verdad.
                        // Repetirlo acá dejaría el mismo id en dos tipos de
                        // elemento distintos —`button` en un estado y texto en el
                        // otro—, que es una trampa para el próximo test.
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("upgrades.character.\(row.id).passive_owned")
                    } else {
                        PricePill(
                            text: CoinFormatter.string(from: row.passiveCost),
                            currency: .coins,
                            affordable: row.canAffordPassive,
                            identifier: "upgrades.character.\(row.id).passive",
                            accessibilityPurpose: Text("upgrades.ax.passive \(row.displayName)")
                        ) {
                            gameState.buyPassiveFromMenu(typeId: row.id)
                        }
                    }
                }
            }
            .padding(.horizontal, Tokens.s8)
            .padding(.vertical, Tokens.s12)
        }
        .background(shape.fill(Color("PaletteCream")))
        .clipShape(shape)
        .overlay(shape.strokeBorder(Color("PaletteBrown").opacity(0.55), lineWidth: 2))
        .shadow(color: .black.opacity(0.16), radius: 5, y: 2)
    }

    /// Una línea de la fila: el texto explica y la cápsula cobra.
    ///
    /// El efecto va en el color de acento de SU compra —azul el multiplicador,
    /// verde el pasivo— porque desde que las dos cápsulas son `PricePill` las
    /// dos son verdes cuando se pueden pagar: el código de color se mudó del
    /// botón al número, que es lo que se lee primero.
    ///
    /// ⚠️ **`Tokens.caption` y dos renglones, no `Tokens.body` con
    /// `lineLimit(1)`.** Medido sobre una captura: con un renglón forzado el
    /// `minimumScaleFactor` encogía cada fila lo que hiciera falta y el mismo
    /// texto salía a 14,3 pt en El Fisura y a 17 pt en El Trapito —los dos con
    /// la misma clave— porque el número de adentro es más corto. Una lista donde
    /// cada renglón tiene su propio cuerpo tipográfico se lee como un error de
    /// maquetado. A 12 pt los ocho textos del catálogo entran enteros en los
    /// ~102 pt que deja la cápsula, así que el cuerpo es el MISMO en todas las
    /// filas; el que algún día no entre parte en dos y sigue midiendo 12
    /// (mismo criterio que el nombre largo de `FisuJobsView`).
    ///
    /// El espaciado es `s4` y no `s8` por la misma medición: la cápsula crece de
    /// 92 a 95,7 pt cuando el monto tiene cinco caracteres ("10,3K"), y esos 4 pt
    /// eran exactamente los que le faltaban a "+172/s cada uno" para entrar en un
    /// renglón. El aire no se pierde: la cápsula trae 12 pt de padding propio
    /// antes del glifo, así que entre el texto y el número siguen habiendo 16.
    ///
    /// ⚠️ El `minimumScaleFactor` **no contradice lo de arriba**: con dos
    /// renglones los ocho textos entran enteros a 12 pt en todos los cuerpos
    /// normales, así que no se dispara nunca y la lista sigue teniendo UNA
    /// tipografía. Es la red para Dynamic Type grande, donde el mismo texto ya no
    /// entra ni en dos renglones y hoy se cortaba con puntos suspensivos: entre
    /// un renglón un poco más chico y un efecto que no dice cuánto, gana el que
    /// se lee.
    private func upgradeLine<Trailing: View>(
        text: String,
        accent: Color,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: Tokens.s4) {
            Text(verbatim: text)
                .font(Tokens.caption)
                .monospacedDigit()
                .foregroundStyle(accent)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            // Sin prioridad, la cápsula pierde contra un texto que quiere todo
            // el ancho y el precio termina partido o encogido a la mitad.
            trailing().layoutPriority(1)
        }
    }

    // MARK: Permanentes (RF-06)

    @ViewBuilder private var permanentRows: some View {
        let lines = gameState.content?.upgradesConfig.upgrades ?? []
        ForEach(Array(lines.enumerated()), id: \.element.id) { offset, line in
            permanentRow(line)
                .staggeredAppearance(index: offset)
        }
    }

    /// Una de las siete líneas de ORO. La cápsula de precio se fue abajo, al
    /// lado de la barra de nivel: arriba deja el ancho entero para el título y
    /// el efecto, y abajo arma el renglón de acción —cuánto llevás y cuánto
    /// sale el siguiente— de un solo vistazo.
    private func permanentRow(_ line: UpgradesConfig.Line) -> some View {
        let level = gameState.upgradeLevel(of: line.id)
        let cost = gameState.upgradeCost(of: line)
        let maxed = level >= line.maxLevel
        let oroCost = Int(cost.rounded(.up))
        let canAfford = (gameState.player?.meta.oro ?? 0) >= oroCost

        return GameCard {
            VStack(alignment: .leading, spacing: Tokens.s8) {
                HStack(spacing: Tokens.s12) {
                    upgradeIcon(line.iconKey)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(LocalizedStringKey(line.titleKey))
                            .font(Tokens.title)
                            .foregroundStyle(Color("PaletteInk"))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        // La línea numérica sale del JSON (no se puede
                        // desincronizar de un cambio de balance).
                        Text(verbatim: gameState.upgradeEffectText(for: line))
                            .font(Tokens.body)
                            .monospacedDigit()
                            .foregroundStyle(Color("PaletteBlue"))
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // El chiste que la hace memorable, debajo del número.
                Text(verbatim: gameState.upgradeFlavorText(for: line))
                    .font(Tokens.caption)
                    .foregroundStyle(Color("PaletteInk").opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: Tokens.s12) {
                    // ⚠️ Los dos `Int` van por `String(_:)`: interpolar un
                    // número dentro de un `LocalizedStringKey` arma la clave
                    // `upgrades.level %lld %lld`, que no existe en el catálogo,
                    // y termina imprimiendo la clave cruda (trampa 5).
                    ProgressBar(
                        progress: Double(level) / Double(max(line.maxLevel, 1)),
                        tint: Color("PaletteYellow"),
                        labelText: String(localized: "upgrades.level \(String(level)) \(String(line.maxLevel))")
                    )
                    if maxed {
                        // El mismo badge que el pasivo comprado, por la misma
                        // razón: `buyUpgrade` rechaza con `maxLevelReached` y ese
                        // rechazo suena a error. "Al máximo" es una felicitación,
                        // no un límite que el jugador esté chocando.
                        StateBadge(
                            text: String(localized: "upgrades.maxed"),
                            systemImage: "star.circle.fill",
                            textAlignment: .center,
                            muted: false
                        )
                        // El mismo hueco que arriba: sin él la barra de nivel se
                        // estira sólo en las filas al máximo y las siete líneas
                        // dejan de tener la misma barra.
                        .frame(minWidth: 92, alignment: .trailing)
                        .layoutPriority(1)
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("upgrades.permanent.\(line.id).maxed")
                    } else {
                        PricePill(
                            text: String(oroCost),
                            currency: .oro,
                            affordable: canAfford,
                            identifier: "upgrades.permanent.\(line.id)",
                            // Las siete líneas ofrecen el mismo botón de ORO: el
                            // título es lo que dice cuál se está por subir. El
                            // título sale del JSON, así que se resuelve con el
                            // lookup de claves data-driven (`String(localized:)`
                            // sólo acepta literales) y entra como ARGUMENTO.
                            accessibilityPurpose: Text("upgrades.ax.level_up \(GameState.localized(line.titleKey))")
                        ) {
                            gameState.buyUpgrade(lineId: line.id)
                        }
                        .layoutPriority(1)
                    }
                }
            }
        }
    }

    /// El glifo de la línea, encuadrado como el retrato de una tarjeta de
    /// FisuJobs para que las dos pantallas hablen el mismo idioma. Con la clave
    /// fuera del manifest cae a un SF Symbol: la fila no espera al arte.
    ///
    /// ⚠️ **Tapado de VoiceOver**, como el retrato de FisuJobs y la copa de
    /// Logros: es decoración —el título de al lado dice qué línea es— y una
    /// `Image` sin etiqueta deja una parada donde el lector se detiene para no
    /// decir nada. Eran siete, una por línea de ORO. Se tapa el glifo y NO la
    /// fila: el badge "Al máximo" y la cápsula de precio siguen siendo sus
    /// propias paradas (patrón T8: se tapa la info, nunca el control ni el
    /// estado que no viaja en ningún otro lado).
    private func upgradeIcon(_ key: String) -> some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        return Color.clear
            .frame(width: 48, height: 48)
            .overlay {
                Group {
                    if let icon = UIArt.image(key) {
                        icon.resizable().scaledToFit()
                    } else {
                        Image(systemName: "wand.and.stars")
                            .resizable().scaledToFit()
                            .foregroundStyle(Color("PaletteBlue"))
                    }
                }
                .padding(5)
            }
            .background(Color("PaletteYellow").opacity(0.3))
            .clipShape(shape)
            .overlay(shape.strokeBorder(Color("PaletteBrown").opacity(0.7), lineWidth: 2))
            .accessibilityHidden(true)
    }
}

// La `StatePill` privada que ocupaba este lugar se fue al `StateBadge` de
// `GameArtComponents` (mismo camino que `JobStateBadge` en la T11): era la
// tercera cápsula de estado del juego dibujada aparte —cápsula crema con glifo
// de color contra el rectángulo naranja del badge compartido— y dos gramáticas
// para el mismo papel es lo que la regla visual del dueño prohíbe. Los dos
// llamadores están arriba, en `characterRow` y `permanentRow`.

// MARK: - Retrato

/// La carita del personaje en la banda izquierda de la fila (RF-05). Sin entrada
/// en el manifest cae al bloque amarillo con el tier, así la pantalla no espera
/// al arte para poder construirse.
private struct CharacterPortrait: View {
    /// Ancho de la banda. El alto lo pone la card, así que el retrato crece con
    /// el contenido en vez de imponerle un cuadrado. Las caras son PNG de 192 px:
    /// a 104 pt de ancho todavía sobran píxeles en @2x.
    ///
    /// ⚠️ **104 y no los 88 del spec §6.** `UpgradesFaceUITests` asserta el ancho
    /// del retrato contra su propia constante de 104 con tolerancia de 1 pt, y
    /// ese test es intocable en esta tarea. El 88 del spec es el tamaño del
    /// ICONO de una fila de Cow Evolution, que acá es una banda de alto completo
    /// y no un cuadrado: no son la misma medida.
    static let width: CGFloat = 104

    let faceKey: String?
    let tier: Int
    /// El nombre del personaje. Es la etiqueta de accesibilidad de la banda: la
    /// fila lo muestra escrito al lado, pero quien lo DICE es el retrato (ver la
    /// capa de medición, abajo).
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
                Group {
                    if let faceKey, let face = UIArt.image(faceKey) {
                        // La banda es más alta que ancha y el arte es cuadrado,
                        // así que se recorta a los costados —donde no hay cara—
                        // en vez de dejar franjas de fondo.
                        face.resizable().scaledToFill()
                    } else {
                        Color("PaletteYellow").overlay(
                            Text(verbatim: "T\(tier)")
                                .font(Tokens.title)
                                .foregroundStyle(Color("PaletteInk"))
                        )
                    }
                }
                // El dibujo es decoración: quien describe al personaje es la
                // capa de medición de más abajo, que lleva su nombre. Sin esto
                // queda un elemento `Image` SIN etiqueta en el árbol
                // —verificado en el volcado de accesibilidad del 2026-08-15, con
                // la geometría desbordada del sprite (128×128 contra los 104 de
                // la banda)— y VoiceOver se detiene ahí para no decir nada. Va
                // acá adentro y no sobre la cadena entera: la capa de medición
                // tiene que seguir siendo un elemento de accesibilidad.
                .accessibilityHidden(true)
            }
            // Respaldo crema: el PNG viene con alfa y sin esto se vería el panel
            // a través de la banda.
            .background(Color("PaletteCream"))
            .clipped()
            // Separa el retrato del texto sin encerrarlo: el marco de la card lo
            // rodea por los otros tres lados.
            .overlay(alignment: .trailing) {
                Rectangle().fill(Color("PaletteBrown").opacity(0.55)).frame(width: 2)
            }
            // El identificador va en una capa VACÍA encima, no en el retrato.
            // Medido el 2026-08-07: el frame de accesibilidad de una vista que
            // contiene arte desbordado reporta la geometría del sprite (150×150,
            // el cuadrado de `scaledToFill`) y **no respeta `.clipped()`** —
            // moverlo de lugar en la cadena de modificadores no lo cambia, se
            // probaron tres variantes. Un `Color.clear` sin contenido adentro sí
            // mide la banda, que es lo que el test tiene que juzgar.
            //
            // ⚠️⚠️ **Y esta capa es la que DICE el nombre del personaje.** El
            // spec §6 pedía esconder la carita con `.accessibilityHidden(true)`
            // para que VoiceOver dejara de repetir el nombre (defecto del
            // HANDOFF §8), pero esconder ESTA capa la saca del árbol de
            // accesibilidad y con ella el identifier que `UpgradesFaceUITests`
            // usa para MEDIR la banda: el test se caería en el primer assert.
            // Dejarla con identifier y sin etiqueta tampoco sirve: queda un
            // elemento donde VoiceOver se detiene para no decir nada, que es
            // exactamente el defecto que el `.accessibilityHidden` de arriba
            // saca del medio. Así que el nombre vive acá —el único elemento de
            // la fila con identifier y con el frame correcto— y el `Text` de al
            // lado va `.accessibilityHidden(true)`. Resultado: el nombre se dice
            // UNA vez, no hay paradas mudas y el test mide lo mismo que antes.
            .overlay {
                Color.clear
                    .accessibilityElement()
                    .accessibilityLabel(Text(verbatim: name))
                    .accessibilityIdentifier(identifier)
            }
    }
}
