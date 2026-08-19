import SwiftUI

/// **Estadísticas** — la foto de la cuenta (spec §10.2): cuatro tarjetas con los
/// 18 números que el juego lleva contados, agrupados por lo que cuentan.
///
/// Lo que la vista hace es **elegir el orden y las etiquetas**; nada más. Todos
/// los valores llegan como texto desde `statsSnapshot`, así que acá no hay un
/// solo `CoinFormatter`, ni un `String(...)`, ni una clave de piso resuelta a
/// mano. Es la misma regla que sostiene FisuJobs con `jobRows`, y acá importa
/// más: `incomePerSecond` tiene una regla de formato propia que ya aplica el
/// HUD, y dos formateos paralelos serían dos pantallas del mismo juego diciendo
/// números distintos.
///
/// ⚠️ **Los cinco de "Currículum" son HISTÓRICOS.** No son el "N contratados"
/// de FisuJobs, que es el contador de la RUN (el que mueve el precio) y vuelve a
/// cero al reencarnar. La nota al pie lo dice en pantalla porque, sin ella, un
/// jugador que reencarna ve "Contrataciones: 240" al lado de una torre vacía y
/// piensa que uno de los dos números miente.
struct StatsView: View {
    @Environment(GameState.self) private var gameState
    /// Cierra la HOJA entera (ver el docstring de `MenuView`: acá `dismiss`
    /// desapilaría en vez de cerrar).
    let close: () -> Void

    var body: some View {
        // Las tres cosas que mueven un stat, leídas explícitamente para que la
        // pantalla se invalide contra ELLAS: la plata (`coinsText`), la torre
        // (`boardVersion`) y los efectos/prestigio (`effectsVersion`).
        let _ = gameState.coinsText
        let _ = gameState.boardVersion
        let _ = gameState.effectsVersion

        // ⚠️ UNA lectura por evaluación del body: el snapshot recorre cuatro
        // catálogos para armar los ratios de colección.
        let stats = gameState.statsSnapshot

        ScrollView {
            // `VStack` y no `LazyVStack`: son cuatro tarjetas contadas y sus 18
            // filas tienen que existir en el árbol de accesibilidad sin
            // scrollear — es lo que ejerce `MenuUITests`, que no desliza.
            VStack(spacing: Tokens.s12) {
                SectionHeader("stats.section.career")
                    .padding(.top, Tokens.s4)
                GameCard(style: .normal) {
                    VStack(spacing: 0) {
                        StatRow(key: "prestige_level", label: "stats.row.prestige_level", value: stats.prestigeLevel)
                        RowDivider()
                        // ⚠️ Esta fila es la ÚNICA del grupo que cuenta la RUN, y
                        // queda entre dos históricas. La decisión es que lo diga
                        // la ETIQUETA —"Tier más alto (esta vida)"— y no moverla:
                        // el tier máximo es un dato de carrera y en cualquier otro
                        // grupo se lee peor. Sin la aclaración, el jugador que
                        // reencarna lee "Reencarnaciones: 1 / Tier más alto: 1 /
                        // Piso más alto: Reino de Dios" y piensa que el del medio
                        // se rompió. El arreglo de fondo es un `maxTierEver` en
                        // `MetaStats`, que es tocar el formato del save.
                        StatRow(key: "max_tier", label: "stats.row.max_tier", value: stats.maxTier)
                        RowDivider()
                        StatRow(key: "max_floor", label: "stats.row.max_floor", value: stats.maxFloorName)
                        RowDivider()
                        StatRow(key: "floors_unlocked", label: "stats.row.floors_unlocked", value: stats.floorsUnlocked)
                    }
                }

                SectionHeader("stats.section.production")
                GameCard(style: .normal) {
                    VStack(spacing: 0) {
                        StatRow(key: "lifetime_earnings", label: "stats.row.lifetime_earnings",
                                value: stats.lifetimeEarnings, glyph: .coins)
                        RowDivider()
                        StatRow(key: "income_per_second", label: "stats.row.income_per_second",
                                value: stats.incomePerSecond, glyph: .coins)
                        RowDivider()
                        StatRow(key: "oro", label: "stats.row.oro", value: stats.oro, glyph: .oro)
                        RowDivider()
                        StatRow(key: "oro_lifetime", label: "stats.row.oro_lifetime",
                                value: stats.oroLifetime, glyph: .oro)
                    }
                }

                SectionHeader("stats.section.collection")
                GameCard(style: .normal) {
                    VStack(spacing: 0) {
                        StatRow(key: "unit_count", label: "stats.row.unit_count", value: stats.unitCount)
                        RowDivider()
                        StatRow(key: "seen_types", label: "stats.row.seen_types", value: stats.seenTypes)
                        RowDivider()
                        StatRow(key: "skins", label: "stats.row.skins", value: stats.skins)
                        RowDivider()
                        StatRow(key: "specials", label: "stats.row.specials", value: stats.specials)
                    }
                }

                SectionHeader("stats.section.activity")
                GameCard(style: .normal) {
                    VStack(spacing: 0) {
                        StatRow(key: "total_merges", label: "stats.row.total_merges", value: stats.totalMerges)
                        RowDivider()
                        StatRow(key: "total_hires", label: "stats.row.total_hires", value: stats.totalHires)
                        RowDivider()
                        StatRow(key: "total_taps", label: "stats.row.total_taps", value: stats.totalTaps)
                        RowDivider()
                        StatRow(key: "videos_watched", label: "stats.row.videos_watched", value: stats.videosWatched)
                        RowDivider()
                        StatRow(key: "boosts_activated", label: "stats.row.boosts_activated",
                                value: stats.boostsActivated)
                        RowDivider()
                        StatRow(key: "shares", label: "stats.row.shares", value: stats.shares)
                    }
                }

                Text("stats.footnote")
                    .font(Tokens.caption)
                    .foregroundStyle(Color("PaletteInk").opacity(0.65))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .padding(.horizontal, Tokens.s8)
            }
            .padding(.horizontal, MenuView.panelInset)
            .padding(.top, Tokens.s12)
            .padding(.bottom, Tokens.s24)
        }
        .panelSheet { header }
        .navigationTitle(Text(verbatim: ""))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { ArtCloseButton(action: close) }
        }
    }

    /// El título, ADENTRO del pergamino. Sin banda opaca: el `panelSheet`
    /// recorta la lista por debajo de la cabecera (2026-08-18).
    private var header: some View {
        PanelTitleBanner(titleKey: "stats.title")
    }
}

// MARK: - Fila

/// Una fila "etiqueta / valor".
///
/// ⚠️ **`label` es un `LocalizedStringKey` que llega como literal desde el call
/// site, y `key` es un `String` aparte.** Podrían parecer el mismo dato —de
/// hecho el identifier `stats.row.total_merges` es la clave del catálogo— pero
/// armar `LocalizedStringKey("stats.row.\(key)")` es la trampa 5 del HANDOFF: la
/// interpolación construye la clave **`stats.row.%@`**, que no existe, y en
/// pantalla se lee literal "stats.row.total_merges". El identifier sí se
/// interpola sin problema: es un `String` y no una clave de localización.
private struct StatRow: View {
    /// Glifo de moneda a la izquierda del valor, cuando el número es plata.
    enum Glyph {
        case coins
        case oro
    }

    let key: String
    let label: LocalizedStringKey
    let value: String
    var glyph: Glyph?

    var body: some View {
        HStack(spacing: Tokens.s8) {
            Text(label)
                .font(Tokens.body)
                .foregroundStyle(Color("PaletteInk").opacity(0.85))
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 5) {
                glyphIcon
                Text(verbatim: value)
                    .font(Tokens.title)
                    .monospacedDigit()
                    .foregroundStyle(Color("PaletteInk"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
        .padding(.vertical, 7)
        // Una parada de VoiceOver por fila, con la etiqueta y el número
        // separados como corresponde. No hay ningún control adentro, así que el
        // elemento puede ir arriba sin tragarse nada (a diferencia de las filas
        // de FisuJobs, que llevan un botón y necesitan la capa trasera).
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("stats.row.\(key)")
        .accessibilityLabel(Text(label))
        .accessibilityValue(Text(verbatim: value))
    }

    @ViewBuilder private var glyphIcon: some View {
        if let glyph {
            switch glyph {
            case .coins: CoinIcon(size: 18)
            case .oro: OroIcon(size: 18)
            }
        }
    }
}
