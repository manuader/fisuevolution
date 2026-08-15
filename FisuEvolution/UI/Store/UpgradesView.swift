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

    /// Margen lateral de la lista. **Medido sobre el arte**, no elegido: el
    /// marco metálico de `panel_upgrades` ocupa de 27,5 a 41,2 pt de cada borde
    /// una vez que el 9-slice lo dibuja (la esquina va a tamaño natural, así que
    /// el píxel `x` del PNG cae en `x / (ancho / 200)` puntos). Con los 22 pt
    /// que había, las tarjetas le pasaban por encima al marco entero y sólo
    /// asomaba en los huecos entre fila y fila. Es el mismo método con el que
    /// `FisuJobsView` sacó sus 30 pt contra `panel_store` —donde el poste de
    /// madera termina en 31,2— así que los dos números salen de la misma regla y
    /// no de dos gustos distintos. Si el arte se re-exporta, se vuelve a medir.
    private static let panelInset: CGFloat = 40

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
                .padding(.top, Tokens.s8)
                .padding(.bottom, Tokens.s24)
            }
            .background { PanelBackground(art: "panel_upgrades") }
            .safeAreaInset(edge: .top) { header }
            .navigationTitle(Text(verbatim: ""))
            .navigationBarTitleDisplayMode(.inline)
            // La barra de navegación aparece recién al scrollear y de fábrica lo
            // hace con el material blanco del sistema: contra el marco metálico
            // quedaba una banda blanca cruzando el panel. Pintada de crema
            // empalma con la cabecera de abajo y las dos se leen como UNA barra
            // fija. Mismo arreglo que `FisuJobsView`.
            .toolbarBackground(Color("PaletteCream"), for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { ArtCloseButton { dismiss() } }
            }
        }
    }

    // MARK: Cabecera

    /// Título, pestañas y —en Permanentes— el saldo de ORO, fijos arriba de la
    /// lista.
    ///
    /// ⚠️ **El fondo opaco no es decoración.** Un `safeAreaInset` recorta el área
    /// segura pero el contenido del scroll sigue pasando POR DEBAJO: con la banda
    /// transparente las tarjetas desfilaban a través del título y asomaban a los
    /// costados de la cápsula. Es el defecto que el HANDOFF §8 anota para "el
    /// título flotante de los paneles" —el de todas las hojas—, y acá se corta
    /// igual que en `FisuJobsView`.
    ///
    /// Las pestañas subieron acá desde el cuerpo del scroll: son el control que
    /// gobierna la lista y quedarse sin ellas al bajar dos filas obligaba a
    /// volver arriba para cambiar de bolsillo.
    private var header: some View {
        VStack(spacing: Tokens.s8) {
            PanelTitleBanner(titleKey: "upgrades.title")
            tabPicker
            if selectedTab == .permanent {
                oroBalance
            }
        }
        .padding(.horizontal, Self.panelInset)
        .padding(.top, 6)
        .padding(.bottom, Tokens.s12)
        .frame(maxWidth: .infinity)
        .background {
            Color("PaletteCream")
                .shadow(color: .black.opacity(0.14), radius: 5, y: 3)
        }
    }

    /// Lo que hay para gastar en esta pestaña. Sin esto, la única forma de saber
    /// si un precio en ORO estaba a tiro era cerrar la hoja e ir al HUD.
    private var oroBalance: some View {
        HStack(spacing: Tokens.s4) {
            OroIcon(size: 18)
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
                .overlay(Capsule().strokeBorder(Color("PaletteInk"), lineWidth: 2))
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
                .fill(Color("PaletteInk").opacity(0.09))
                .overlay(Capsule().strokeBorder(Color("PaletteInk"), lineWidth: 3))
        }
        .animation(.snappy(duration: 0.2), value: selectedTab)
    }

    private func tabButton(_ tab: Tab, key: LocalizedStringKey, identifier: String) -> some View {
        let selected = selectedTab == tab
        return Button { selectedTab = tab } label: {
            Text(key)
                .font(Tokens.body)
                .foregroundStyle(selected ? Color.white : Color("PaletteInk").opacity(0.7))
                .shadow(color: .black.opacity(selected ? 0.35 : 0), radius: 1, y: 1)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Tokens.s8)
                .background {
                    if selected {
                        Capsule()
                            .fill(Color("PaletteBlue"))
                            .overlay(Capsule().strokeBorder(Color("PaletteInk"), lineWidth: 2))
                            .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
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
            ForEach(rows) { row in
                characterRow(row)
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
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        return HStack(spacing: 0) {
            CharacterPortrait(
                faceKey: row.faceKey,
                tier: row.tier,
                identifier: "upgrades.character.\(row.id).face"
            )

            VStack(alignment: .leading, spacing: 6) {
                Text(verbatim: row.displayName)
                    .font(Tokens.title)
                    .foregroundStyle(Color("PaletteInk"))
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                upgradeLine(text: gameState.characterIncomeText(for: row), accent: Color("PaletteBlue")) {
                    PricePill(
                        text: CoinFormatter.string(from: row.upgradeCost),
                        currency: .coins,
                        affordable: row.canAffordUpgrade,
                        identifier: "upgrades.character.\(row.id).multiplier"
                    ) {
                        gameState.buyCharacterUpgrade(typeID: row.id)
                    }
                }

                upgradeLine(text: row.passiveEffectText, accent: Color("PaletteGreen")) {
                    if row.passiveUnlocked {
                        // Sigue siendo un botón —y con el MISMO identifier— para
                        // no cambiarle el tipo de elemento al árbol de AX: hoy
                        // también lo era, sólo que `.disabled`. La acción es la
                        // misma y `applyPassiveUnlock` la rechaza con
                        // `alreadyUnlocked`, así que un toque de más no cobra
                        // nada: suena el "no" y listo.
                        StatePill(
                            titleKey: "upgrades.character.passive_owned",
                            systemImage: "checkmark.circle.fill",
                            tint: Color("PaletteGreen"),
                            identifier: "upgrades.character.\(row.id).passive"
                        ) {
                            gameState.buyPassiveFromMenu(typeId: row.id)
                        }
                    } else {
                        PricePill(
                            text: CoinFormatter.string(from: row.passiveCost),
                            currency: .coins,
                            affordable: row.canAffordPassive,
                            identifier: "upgrades.character.\(row.id).passive"
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
        .overlay(shape.strokeBorder(Color("PaletteInk"), lineWidth: 2))
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
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            // Sin prioridad, la cápsula pierde contra un texto que quiere todo
            // el ancho y el precio termina partido o encogido a la mitad.
            trailing().layoutPriority(1)
        }
    }

    // MARK: Permanentes (RF-06)

    @ViewBuilder private var permanentRows: some View {
        ForEach(gameState.content?.upgradesConfig.upgrades ?? []) { line in
            permanentRow(line)
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
                        StatePill(
                            titleKey: "upgrades.maxed",
                            systemImage: "star.circle.fill",
                            tint: Color("PaletteYellow"),
                            identifier: "upgrades.permanent.\(line.id)"
                        ) {
                            gameState.buyUpgrade(lineId: line.id)
                        }
                        .layoutPriority(1)
                    } else {
                        PricePill(
                            text: String(oroCost),
                            currency: .oro,
                            affordable: canAfford,
                            identifier: "upgrades.permanent.\(line.id)"
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
            .background(Color("PaletteYellow").opacity(0.35))
            .clipShape(shape)
            .overlay(shape.strokeBorder(Color("PaletteInk"), lineWidth: 2))
    }
}

// MARK: - Cápsula de estado

/// La cápsula que ocupa el lugar del precio cuando ya no hay nada que comprar:
/// el pasivo ya abierto y la línea de ORO al máximo.
///
/// ⚠️ **Es un `Button` y lleva el identifier de la compra**, no una etiqueta:
/// `upgrades.permanent.<id>` está pineado como botón por `LaunchSmokeTests` y
/// `upgrades.character.<id>.passive` por `UpgradesMenuUITests`. Dejarlo de ser
/// botón en un estado los rompería el día que el fixture llegue a ese estado.
/// La acción es la misma que la de la cápsula de precio y la economía la
/// rechaza sola (`alreadyUnlocked` / `maxLevelReached`), así que no hay camino
/// para cobrar dos veces.
///
/// Comparte la geometría de `PricePill` (mínimo 92, padding 12/8, cápsula con
/// contorno de 3) para que las filas de una lista no bailen entre estados.
private struct StatePill: View {
    let titleKey: LocalizedStringKey
    let systemImage: String
    let tint: Color
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(tint)
                Text(titleKey)
                    .font(Tokens.caption)
                    .foregroundStyle(Color("PaletteInk"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            // El padding es `s8` y no el `s12` de `PricePill`: con "Ya genera"
            // adentro la cápsula se iba a 105 pt —13 más que un precio— y esos
            // 13 se los sacaba al renglón del efecto, que partía en dos SÓLO en
            // las filas ya compradas. Medido el 2026-08-15.
            .padding(.horizontal, Tokens.s8)
            .padding(.vertical, Tokens.s8)
            .frame(minWidth: 92)
            .background {
                Capsule()
                    .fill(Color("PaletteCream"))
                    .overlay(Capsule().strokeBorder(Color("PaletteInk").opacity(0.45), lineWidth: 3))
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }
}

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
                // El dibujo es decoración: quien lo describe es el nombre de la
                // fila. Sin esto queda un elemento `Image` SIN etiqueta en el
                // árbol —verificado en el volcado de accesibilidad del
                // 2026-08-15, con la geometría desbordada del sprite (128×128
                // contra los 104 de la banda)— y VoiceOver se detiene ahí para
                // no decir nada. Va acá adentro y no sobre la cadena entera: la
                // capa de medición de más abajo tiene que seguir siendo un
                // elemento de accesibilidad.
                .accessibilityHidden(true)
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
            //
            // ⚠️⚠️ **Y esta capa NO lleva etiqueta.** Tenía el nombre del
            // personaje, que el `Text` de al lado ya dice: VoiceOver lo
            // anunciaba dos veces (defecto del HANDOFF §8). El spec §6 pedía
            // `.accessibilityHidden(true)`, pero eso saca el elemento del árbol
            // de accesibilidad y con él el identifier que `UpgradesFaceUITests`
            // usa para MEDIR la banda: el test se caería. Sin etiqueta, el
            // elemento sigue existiendo para XCUITest —mismo patrón que
            // `board.units` en `RootView`, que tampoco tiene label— y VoiceOver
            // no tiene nada que leer, así que el nombre se dice una sola vez.
            .overlay {
                Color.clear
                    .accessibilityElement()
                    .accessibilityIdentifier(identifier)
            }
    }
}
