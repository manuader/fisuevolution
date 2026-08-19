import SwiftUI

// MARK: - Idioma

/// El idioma con el que arranca el juego (spec §10.4): el del teléfono, o uno
/// elegido a mano.
///
/// ⚠️ **Hay una clave propia (`settings.language`) además de `AppleLanguages`, y
/// no es redundancia.** `AppleLanguages` vive en el dominio global de
/// `UserDefaults`, así que `stringArray(forKey:)` devuelve **la lista de idiomas
/// del sistema** aunque la app no haya escrito nunca nada. Leyendo sólo esa
/// clave, "Sistema" se vería tildado como "Español" en cualquier teléfono en
/// español y el jugador vería marcada una opción que no eligió. La clave propia
/// responde la única pregunta que la pantalla necesita: *¿el jugador eligió?*
///
/// `AppleLanguages` sigue siendo la que **hace** el cambio: iOS la lee al
/// arrancar el proceso, y por eso la elección pide reiniciar el juego.
enum LanguagePreference: String, CaseIterable, Identifiable {
    case system
    case es
    case en

    /// La clave que decide de verdad qué idioma carga iOS.
    static let systemKey = "AppleLanguages"
    /// La constancia de que la elección fue del jugador.
    static let defaultsKey = "settings.language"

    var id: String { rawValue }
    /// Los tres identifiers del spec §10.4.
    var identifier: String { "settings.language.\(rawValue)" }
    var titleKey: LocalizedStringKey { LocalizedStringKey(identifier) }

    /// Qué se escribe en `AppleLanguages`. `nil` es "sacá la clave".
    var languageCodes: [String]? {
        switch self {
        case .system: nil
        case .es: ["es"]
        case .en: ["en"]
        }
    }

    static func current(in defaults: UserDefaults = .standard) -> LanguagePreference {
        LanguagePreference(rawValue: defaults.string(forKey: defaultsKey) ?? "") ?? .system
    }

    func apply(to defaults: UserDefaults = .standard) {
        guard let languageCodes else {
            // Volver a "Sistema" **remueve**: con un valor puesto, el juego
            // seguiría ignorando el idioma del teléfono para siempre.
            defaults.removeObject(forKey: Self.systemKey)
            defaults.removeObject(forKey: Self.defaultsKey)
            return
        }
        defaults.set(languageCodes, forKey: Self.systemKey)
        defaults.set(rawValue, forKey: Self.defaultsKey)
    }
}

// MARK: - La pantalla

/// **Ajustes** (spec §10.4): idioma, audio, lo que se ve y se siente,
/// notificaciones, compras, legales y de quién es esto.
///
/// Es la cuarta sub-vista **empujada** del `NavigationStack` del menú y copia el
/// andamio de Estadísticas y Logros: `WoodPanelBackground` con el margen de 34 pt
/// medido en la T15, cabecera crema opaca, `SectionHeader` por grupo, `GameCard`
/// por grupo y `ArtCloseButton` que cierra la HOJA (acá `dismiss` desapilaría —
/// ver el docstring de `MenuView`).
///
/// **Seis cintas para las siete secciones del spec**: "Partículas" y
/// "Notificaciones" comparten la de "En el juego". Los identifiers —que es lo
/// que el spec fija— son los siete de la lista; lo que se agrupa es el dibujo,
/// porque dos cintas naranjas con una fila cada una debajo hacen ruido y no
/// jerarquía (Estadísticas tiene cuatro cintas para dieciocho filas).
///
/// ⚠️ **Los valores de accesibilidad de los controles van SIN traducir**
/// (`on`/`off`, `selected`): el runner corre la app en inglés (trampa 6 del
/// HANDOFF) y un valor traducido haría pasar al test de UI por la razón
/// equivocada. Es el mismo criterio que `AchievementsView.axValue`.
struct SettingsView: View {
    @Environment(AudioManager.self) private var audio
    @Environment(HapticsManager.self) private var haptics
    @Environment(NotificationsManager.self) private var notifications
    @Environment(StoreManager.self) private var store
    /// Cierra la HOJA entera.
    let close: () -> Void

    /// El toggle de partículas. `@AppStorage` con default `true` es la otra
    /// mitad de `ParticlePool.particlesEnabled(in:)`: los dos leen la misma
    /// clave y los dos entienden "no escrita" como "prendido".
    @AppStorage(ParticlePool.particlesDefaultsKey) private var particlesEnabled = true
    @State private var language = LanguagePreference.current()
    @State private var showRestartAlert = false
    @State private var restore = RestoreOutcome.idle

    var body: some View {
        // Los volúmenes son `var` del manager y persisten solos en su `didSet`:
        // el slider escribe directo y no hay estado local que pueda desfasarse.
        @Bindable var audio = audio

        ScrollView {
            // `VStack` y no `LazyVStack`: son ~14 filas contadas y todas tienen
            // que existir en el árbol de accesibilidad sin scrollear, que es lo
            // que ejerce `MenuUITests` (misma razón que Estadísticas).
            VStack(spacing: Tokens.s12) {
                languageSection
                audioSection(music: $audio.musicVolume, sfx: $audio.sfxVolume)
                gameSection
                purchasesSection
                legalSection
                aboutSection
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
        // Los legales se **empujan** en la misma pila del menú: son la cuarta
        // pantalla de un viaje, no una hoja nueva encima de otra hoja.
        .navigationDestination(for: LegalDocument.Kind.self) { document in
            LegalView(document: document, close: close)
        }
        .alert("settings.restart.title", isPresented: $showRestartAlert) {
            Button("settings.restart.ok", role: .cancel) {}
        } message: {
            Text("settings.restart.body")
        }
        // El permiso de notificaciones se puede revocar desde Ajustes de iOS sin
        // que la app se entere: al abrir la pantalla, el toggle se re-sincroniza
        // contra el sistema antes de que el jugador lo mire.
        .task { await notifications.syncWithSystem() }
    }

    // MARK: Cabecera

    /// El título y la bajada, ADENTRO del pergamino. Sin banda opaca: el
    /// `panelSheet` recorta la lista por debajo de la cabecera (2026-08-18).
    private var header: some View {
        VStack(spacing: Tokens.s4) {
            PanelTitleBanner(titleKey: "settings.title")
            Text("settings.subtitle")
                .font(Tokens.caption)
                .foregroundStyle(Color("PaletteInk").opacity(0.75))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, Tokens.s24)
        }
    }

    // MARK: Idioma

    private var languageSection: some View {
        VStack(spacing: Tokens.s12) {
            SectionHeader("settings.language")
                .padding(.top, Tokens.s4)
            GameCard(style: .normal) {
                VStack(spacing: 0) {
                    ForEach(Array(LanguagePreference.allCases.enumerated()), id: \.element) { index, option in
                        if index > 0 { RowDivider() }
                        LanguageRow(option: option, selected: option == language) {
                            select(option)
                        }
                    }
                    RowDivider()
                    Text("settings.language.hint")
                        .font(Tokens.caption)
                        .foregroundStyle(Color("PaletteInk").opacity(0.65))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, Tokens.s8)
                }
            }
        }
    }

    /// Elegir idioma escribe la preferencia y avisa que hay que reiniciar. **No**
    /// se intenta recargar el bundle en caliente: SwiftUI ya resolvió cada
    /// `LocalizedStringKey` de la sesión, así que un recambio en vivo dejaría
    /// media app en un idioma y media en el otro. Un aviso honesto es mejor que
    /// una pantalla mitad y mitad.
    private func select(_ option: LanguagePreference) {
        guard option != language else { return }
        language = option
        option.apply()
        showRestartAlert = true
    }

    // MARK: Audio

    private func audioSection(music: Binding<Double>, sfx: Binding<Double>) -> some View {
        VStack(spacing: Tokens.s12) {
            SectionHeader("settings.section.audio")
            GameCard(style: .normal) {
                VStack(spacing: 0) {
                    SliderRow(
                        titleKey: "settings.music",
                        identifier: "settings.music",
                        systemImage: "music.note",
                        value: music
                    )
                    RowDivider()
                    SliderRow(
                        titleKey: "settings.sfx",
                        identifier: "settings.sfx",
                        systemImage: "speaker.wave.2.fill",
                        value: sfx
                    )
                    RowDivider()
                    ToggleRow(
                        titleKey: "settings.haptics",
                        identifier: "settings.haptics",
                        isOn: haptics.isEnabled
                    ) { haptics.isEnabled = $0 }
                }
            }
        }
    }

    // MARK: En el juego

    private var gameSection: some View {
        VStack(spacing: Tokens.s12) {
            SectionHeader("settings.section.game")
            GameCard(style: .normal) {
                VStack(spacing: 0) {
                    ToggleRow(
                        titleKey: "settings.particles",
                        identifier: "settings.particles",
                        hintKey: "settings.particles.hint",
                        isOn: particlesEnabled
                    ) { particlesEnabled = $0 }
                    RowDivider()
                    ToggleRow(
                        titleKey: "settings.notifications",
                        identifier: "settings.notifications",
                        // Se dice a qué hora y cuántas: un toggle de
                        // notificaciones sin eso es un cheque en blanco.
                        hintKey: notifications.permissionDenied
                            ? "settings.notifications.denied"
                            : "settings.notifications.hint",
                        isOn: notifications.isEnabled
                    ) { wantsOn in
                        // El estado lo decide el manager (y iOS), no el toque:
                        // si el permiso se niega, el toggle vuelve solo.
                        if wantsOn {
                            Task { await notifications.requestAndSchedule() }
                        } else {
                            notifications.disable()
                        }
                    }
                }
            }
        }
    }

    // MARK: Compras

    private var purchasesSection: some View {
        VStack(spacing: Tokens.s12) {
            SectionHeader("settings.section.purchases")
            GameCard(style: .normal) {
                VStack(spacing: Tokens.s8) {
                    Text("settings.restore.hint")
                        .font(Tokens.caption)
                        .foregroundStyle(Color("PaletteInk").opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    // Azul y no verde: no cobra nada. Mismo botón, mismo color y
                    // mismo identifier que el de la cabecera de la tienda.
                    ActionPill(
                        titleKey: "settings.restore",
                        systemImage: "arrow.clockwise",
                        tint: Color("PaletteBlue"),
                        identifier: "settings.restore"
                    ) {
                        Task { await runRestore() }
                    }
                    restoreFeedback
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    /// Qué pasó con el último "Restaurar compras".
    ///
    /// Existe porque `StoreManager` sólo publica el **error**: sin esto, un
    /// restore exitoso —o uno que no encontró nada— no dice absolutamente nada y
    /// el jugador toca tres veces pensando que el botón está roto. Es un estado
    /// de la vista y no del manager porque muere con la pantalla.
    private enum RestoreOutcome: Equatable {
        case idle
        case running
        case done(Int)
        case failed(String)
    }

    @ViewBuilder private var restoreFeedback: some View {
        switch restore {
        case .idle:
            EmptyView()
        case .running:
            ProgressView()
                .tint(Color("PaletteInk"))
        case .done(let count):
            // El conteo va como `String` ANTES de entrar en la clave: con un
            // `Int` interpolado, `LocalizedStringKey` busca `%lld` y en pantalla
            // se lee la clave cruda (trampa 5 del HANDOFF).
            StateBadge(
                text: count > 0
                    ? String(localized: "settings.restore.done \(String(count))")
                    : String(localized: "settings.restore.empty"),
                systemImage: count > 0 ? "checkmark.circle.fill" : "info.circle.fill",
                textAlignment: .center,
                muted: count == 0
            )
        case .failed(let message):
            StateBadge(text: message, systemImage: "exclamationmark.triangle.fill",
                       textAlignment: .center, muted: false)
        }
    }

    private func runRestore() async {
        restore = .running
        await store.restore()
        if let message = store.lastErrorMessage {
            restore = .failed(message)
        } else {
            // Lo restaurado son los **no consumibles** que StoreKit reconoce
            // como vigentes: es exactamente lo que el jugador recupera.
            restore = .done(store.purchasedProductIDs.count)
        }
    }

    // MARK: Legales

    private var legalSection: some View {
        VStack(spacing: Tokens.s12) {
            SectionHeader("settings.section.legal")
            GameCard(style: .normal) {
                VStack(spacing: 0) {
                    ForEach(Array(LegalDocument.Kind.allCases.enumerated()), id: \.element) { index, document in
                        if index > 0 { RowDivider() }
                        NavigationLink(value: document) {
                            HStack(spacing: Tokens.s8) {
                                Text(document.titleKey)
                                    .font(Tokens.body)
                                    .foregroundStyle(Color("PaletteInk"))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .black))
                                    .foregroundStyle(Color("PaletteInk").opacity(0.45))
                            }
                            .padding(.vertical, 9)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier(document.identifier)
                        .accessibilityLabel(Text(document.titleKey))
                    }
                }
            }
        }
    }

    // MARK: Acerca de

    private var aboutSection: some View {
        VStack(spacing: Tokens.s12) {
            SectionHeader("settings.section.about")
            GameCard(style: .normal) {
                VStack(spacing: Tokens.s8) {
                    // El número sale del bundle y no de una constante escrita a
                    // mano: una versión que miente en Ajustes es la primera
                    // pista falsa de cualquier reporte de bug.
                    Text("settings.about.version \(Self.versionText)")
                        .font(Tokens.body)
                        .monospacedDigit()
                        .foregroundStyle(Color("PaletteInk"))
                        .accessibilityIdentifier("settings.about.version")
                    Text("settings.about.credits")
                        .font(Tokens.caption)
                        .foregroundStyle(Color("PaletteInk").opacity(0.7))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    /// "0.1.0 (1)". Con guiones si el bundle no tuviera las claves, que no puede
    /// pasar con `GENERATE_INFOPLIST_FILE` pero se dice igual antes que
    /// desenvolver a la fuerza.
    private static var versionText: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "\(short) (\(build))"
    }
}

// MARK: - Filas

/// Fila de toggle: etiqueta, aclaración opcional y el `GameToggle` del juego.
///
/// Toda la fila es el botón —no sólo la perilla— porque en un teléfono nadie le
/// apunta a una cápsula de 64 pt cuando el renglón entero está ahí. El estado lo
/// decide quien la usa (`isOn`), así que un toggle que el sistema rechaza (las
/// notificaciones) vuelve solo a su lugar sin que la fila tenga que saber nada.
private struct ToggleRow: View {
    let titleKey: LocalizedStringKey
    let identifier: String
    var hintKey: LocalizedStringKey?
    let isOn: Bool
    let set: (Bool) -> Void

    var body: some View {
        Button { set(!isOn) } label: {
            HStack(spacing: Tokens.s12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(titleKey)
                        .font(Tokens.body)
                        .foregroundStyle(Color("PaletteInk"))
                        .fixedSize(horizontal: false, vertical: true)
                    if let hintKey {
                        Text(hintKey)
                            .font(Tokens.caption)
                            .foregroundStyle(Color("PaletteInk").opacity(0.6))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                GameToggle(isOn: isOn, width: 58, height: 32)
            }
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
        .accessibilityLabel(Text(titleKey))
        // Sin traducir a propósito: es lo que compara el test de UI.
        .accessibilityValue(Text(verbatim: isOn ? "on" : "off"))
        .accessibilityAddTraits(.isToggle)
    }
}

/// Fila de volumen: glifo, etiqueta y el slider, que escribe directo en el
/// `AudioManager` (que persiste solo).
private struct SliderRow: View {
    let titleKey: LocalizedStringKey
    let identifier: String
    let systemImage: String
    @Binding var value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: Tokens.s8) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(Color("PaletteInk").opacity(0.7))
                    .accessibilityHidden(true)
                Text(titleKey)
                    .font(Tokens.body)
                    .foregroundStyle(Color("PaletteInk"))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(verbatim: "\(Int((value * 100).rounded()))%")
                    .font(Tokens.caption)
                    .monospacedDigit()
                    .foregroundStyle(Color("PaletteInk").opacity(0.6))
                    .accessibilityHidden(true)
            }
            Slider(value: $value, in: 0...1)
                .tint(Color("PaletteGreen"))
                .accessibilityIdentifier(identifier)
                .accessibilityLabel(Text(titleKey))
        }
        .padding(.vertical, 7)
    }
}

/// Fila de idioma: el nombre y un tilde cuando es la elegida.
///
/// El tilde y no un radio button del sistema: es el mismo lenguaje de "esto está
/// puesto" que usa el resto del juego (la pinta equipada, el piso actual).
private struct LanguageRow: View {
    let option: LanguagePreference
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Tokens.s8) {
                Text(option.titleKey)
                    .font(Tokens.body)
                    .foregroundStyle(Color("PaletteInk"))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(selected
                        ? Color("PaletteGreen")
                        : Color("PaletteInk").opacity(0.25))
            }
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(option.identifier)
        .accessibilityLabel(Text(option.titleKey))
        // Sin traducir: lo compara el test de UI (trampa 6).
        .accessibilityValue(Text(verbatim: selected ? "selected" : "unselected"))
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}
