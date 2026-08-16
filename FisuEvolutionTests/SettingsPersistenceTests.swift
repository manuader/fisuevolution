import Foundation
import Testing
import UserNotifications
@testable import FisuEvolution

/// Lo que Ajustes (spec §10.4) guarda, apaga y programa.
///
/// Las tres piezas que se prueban acá tienen la misma forma: **una preferencia
/// que sobrevive al cierre de la app y algo del juego que la obedece**. Y las
/// tres tienen la misma trampa: `UserDefaults.standard` es global y compartido
/// con el simulador entero, así que cada suite se arma su propio dominio y lo
/// borra al terminar. Un test que escriba en `.standard` deja el juego del dueño
/// en español o sin partículas.
@Suite("Ajustes: persistencia")
@MainActor
struct SettingsPersistenceTests {

    // MARK: - Partículas

    /// ⚠️ El default **true** es la razón de ser del helper. `bool(forKey:)`
    /// devuelve `false` cuando la clave no existe, así que un `guard
    /// UserDefaults.standard.bool(forKey:)` en `emit` dejaría el juego SIN
    /// partículas en la primera partida de todos los jugadores — y el toggle
    /// arrancaría en "prendido" mostrando lo contrario de lo que pasa.
    @Test("sin la clave escrita, las partículas están prendidas")
    func particlesDefaultToOn() {
        let scratch = ScratchDefaults()
        defer { scratch.clear() }

        #expect(scratch.defaults.object(forKey: ParticlePool.particlesDefaultsKey) == nil)
        #expect(ParticlePool.particlesEnabled(in: scratch.defaults))
    }

    @Test("el toggle de partículas persiste en los dos sentidos")
    func particlesTogglePersists() {
        let scratch = ScratchDefaults()
        defer { scratch.clear() }

        scratch.defaults.set(false, forKey: ParticlePool.particlesDefaultsKey)
        #expect(ParticlePool.particlesEnabled(in: scratch.defaults) == false)

        scratch.defaults.set(true, forKey: ParticlePool.particlesDefaultsKey)
        #expect(ParticlePool.particlesEnabled(in: scratch.defaults))
    }

    // MARK: - Idioma

    @Test("elegir un idioma escribe AppleLanguages y deja constancia de la elección")
    func choosingALanguageWritesAppleLanguages() {
        let scratch = ScratchDefaults()
        defer { scratch.clear() }

        LanguagePreference.es.apply(to: scratch.defaults)
        #expect(scratch.defaults.stringArray(forKey: LanguagePreference.systemKey) == ["es"])
        #expect(LanguagePreference.current(in: scratch.defaults) == .es)

        LanguagePreference.en.apply(to: scratch.defaults)
        #expect(scratch.defaults.stringArray(forKey: LanguagePreference.systemKey) == ["en"])
        #expect(LanguagePreference.current(in: scratch.defaults) == .en)
    }

    /// "Sistema" no escribe `["es"]` ni `["en"]`: **remueve** la clave. Es la
    /// única forma de devolverle la decisión a iOS; con un valor puesto, el
    /// juego seguiría ignorando el idioma del teléfono.
    @Test("volver a Sistema remueve la clave en vez de escribir un idioma")
    func systemRemovesTheOverride() {
        let scratch = ScratchDefaults()
        defer { scratch.clear() }

        LanguagePreference.en.apply(to: scratch.defaults)
        LanguagePreference.system.apply(to: scratch.defaults)

        // ⚠️ Se pregunta por el **dominio propio** y no con `object(forKey:)`:
        // `AppleLanguages` también vive en el dominio global, así que un
        // `object(forKey:)` devuelve la lista de idiomas del simulador aunque la
        // app haya removido la suya —y el test fallaría con el código correcto—.
        // Es el mismo dato que obliga a `current(in:)` a leer una clave propia.
        #expect(scratch.stored[LanguagePreference.systemKey] == nil)
        #expect(scratch.stored[LanguagePreference.defaultsKey] == nil)
        #expect(LanguagePreference.current(in: scratch.defaults) == .system)
    }

    /// ⚠️ **Por qué hay una clave propia y no se lee `AppleLanguages` de vuelta.**
    /// `AppleLanguages` vive en el dominio global (`NSGlobalDomain`): un
    /// `stringArray(forKey:)` devuelve la lista de idiomas DEL SISTEMA aunque la
    /// app no haya escrito nunca nada. Sin la clave propia, "Sistema" se leería
    /// como "Español" en un teléfono en español y el tilde marcaría una opción
    /// que el jugador no eligió.
    @Test("los ids de las tres opciones son los que pinea el spec")
    func optionIdentifiersMatchTheSpec() {
        #expect(LanguagePreference.allCases.map(\.identifier) == [
            "settings.language.system", "settings.language.es", "settings.language.en"
        ])
    }

    // MARK: - Andamio

    /// Un dominio de `UserDefaults` descartable por test.
    struct ScratchDefaults {
        let name = "t16-settings-\(UUID().uuidString)"
        let defaults: UserDefaults

        init() {
            defaults = UserDefaults(suiteName: name) ?? .standard
        }

        /// Lo que la app escribió **de verdad** en su propio dominio, sin la
        /// herencia del dominio global. Es la única forma de comprobar que una
        /// clave se removió.
        var stored: [String: Any] {
            UserDefaults.standard.persistentDomain(forName: name) ?? [:]
        }

        func clear() {
            defaults.removePersistentDomain(forName: name)
        }
    }
}

// MARK: - Notificaciones

@Suite("NotificationsManager")
@MainActor
struct NotificationsManagerTests {

    @Test("recién instalado, las notificaciones están apagadas")
    func startsOff() {
        let scratch = SettingsPersistenceTests.ScratchDefaults()
        defer { scratch.clear() }

        let manager = NotificationsManager(center: SpyNotificationCenter(), defaults: scratch.defaults)

        #expect(manager.isEnabled == false)
    }

    @Test("conceder el permiso programa UN recordatorio diario a las 19")
    func grantingSchedulesTheDailyReminder() async throws {
        let scratch = SettingsPersistenceTests.ScratchDefaults()
        defer { scratch.clear() }
        let spy = SpyNotificationCenter()
        spy.granted = true
        let manager = NotificationsManager(center: spy, defaults: scratch.defaults)

        await manager.requestAndSchedule()

        #expect(manager.isEnabled)
        #expect(scratch.defaults.bool(forKey: NotificationsManager.defaultsKey))
        #expect(spy.requestedOptions == [.alert, .sound, .badge])
        #expect(spy.pending.count == 1, "un recordatorio, no dos")

        let request = try #require(spy.pending[NotificationsManager.requestIdentifier])
        let trigger = request.trigger as? UNCalendarNotificationTrigger
        #expect(trigger?.dateComponents.hour == NotificationsManager.reminderHour)
        #expect(trigger?.dateComponents.minute == 0)
        #expect(trigger?.repeats == true, "el recordatorio es DIARIO: sin repeats suena una vez y nunca más")
        // El texto sale del catálogo: sin esto, una clave mal escrita se
        // notificaría como "notif.daily.title" en el teléfono del jugador.
        #expect(request.content.title.isEmpty == false)
        #expect(request.content.title.hasPrefix("notif.") == false)
        #expect(request.content.body.isEmpty == false)
        #expect(request.content.body.hasPrefix("notif.") == false)
    }

    /// Encender dos veces no puede dejar dos recordatorios: el id es fijo y
    /// `add` reemplaza al que ya estaba.
    @Test("encender dos veces sigue dejando un solo recordatorio")
    func schedulingIsIdempotent() async {
        let scratch = SettingsPersistenceTests.ScratchDefaults()
        defer { scratch.clear() }
        let spy = SpyNotificationCenter()
        let manager = NotificationsManager(center: spy, defaults: scratch.defaults)

        await manager.requestAndSchedule()
        await manager.requestAndSchedule()

        #expect(spy.pending.count == 1)
    }

    /// ⚠️ **El estado no puede mentir.** Si el jugador dice que no en el diálogo
    /// del sistema, el toggle vuelve a apagado: uno prendido con el permiso
    /// denegado promete un recordatorio que iOS nunca va a mostrar.
    @Test("si el permiso se deniega, el toggle vuelve a apagado y no programa nada")
    func denialLeavesTheToggleOff() async {
        let scratch = SettingsPersistenceTests.ScratchDefaults()
        defer { scratch.clear() }
        let spy = SpyNotificationCenter()
        spy.granted = false
        let manager = NotificationsManager(center: spy, defaults: scratch.defaults)

        await manager.requestAndSchedule()

        #expect(manager.isEnabled == false)
        #expect(manager.permissionDenied)
        #expect(spy.pending.isEmpty)
    }

    @Test("un error del centro tampoco deja el toggle prendido")
    func failureLeavesTheToggleOff() async {
        let scratch = SettingsPersistenceTests.ScratchDefaults()
        defer { scratch.clear() }
        let spy = SpyNotificationCenter()
        spy.authorizationError = SpyError.nope
        let manager = NotificationsManager(center: spy, defaults: scratch.defaults)

        await manager.requestAndSchedule()

        #expect(manager.isEnabled == false)
        #expect(spy.pending.isEmpty)
    }

    @Test("apagar el toggle limpia los recordatorios programados")
    func disablingClearsPending() async {
        let scratch = SettingsPersistenceTests.ScratchDefaults()
        defer { scratch.clear() }
        let spy = SpyNotificationCenter()
        let manager = NotificationsManager(center: spy, defaults: scratch.defaults)
        await manager.requestAndSchedule()
        #expect(spy.pending.count == 1)

        manager.disable()

        #expect(manager.isEnabled == false)
        #expect(scratch.defaults.bool(forKey: NotificationsManager.defaultsKey) == false)
        #expect(spy.pending.isEmpty)
        #expect(spy.removeAllCount == 1)
    }

    /// ⚠️ Pedir el permiso tiene dos `await` en el medio. Si el jugador apaga el
    /// toggle mientras el sistema contesta, gana **el apagado**: la respuesta que
    /// llega después es más vieja que su decisión. Sin la guarda de generación,
    /// el toggle se veía volver solo a prendido.
    @Test("apagar mientras el permiso está en vuelo le gana a la respuesta")
    func disablingDuringTheRequestWins() async {
        let scratch = SettingsPersistenceTests.ScratchDefaults()
        defer { scratch.clear() }
        let spy = SpyNotificationCenter()
        let manager = NotificationsManager(center: spy, defaults: scratch.defaults)
        // El apagado ocurre EXACTAMENTE en el hueco: adentro del pedido, después
        // de que el jugador lo disparó y antes de que el sistema conteste.
        spy.beforeAnswering = { manager.disable() }

        await manager.requestAndSchedule()

        #expect(manager.isEnabled == false)
        #expect(spy.pending.isEmpty, "quedó programado un recordatorio que el jugador apagó")
    }

    /// El permiso se puede revocar desde Ajustes de iOS sin que la app se entere.
    /// Al abrir la pantalla, el estado se re-sincroniza contra el sistema.
    @Test("un permiso revocado por fuera apaga el toggle al re-sincronizar")
    func revokedPermissionSyncsBack() async {
        let scratch = SettingsPersistenceTests.ScratchDefaults()
        defer { scratch.clear() }
        let spy = SpyNotificationCenter()
        let manager = NotificationsManager(center: spy, defaults: scratch.defaults)
        await manager.requestAndSchedule()
        #expect(manager.isEnabled)

        spy.status = .denied
        await manager.syncWithSystem()

        #expect(manager.isEnabled == false)
        #expect(spy.pending.isEmpty, "un recordatorio pendiente sin permiso es basura en la cola")
    }

    @Test("con el permiso vigente, re-sincronizar no toca nada")
    func authorizedSyncKeepsTheReminder() async {
        let scratch = SettingsPersistenceTests.ScratchDefaults()
        defer { scratch.clear() }
        let spy = SpyNotificationCenter()
        let manager = NotificationsManager(center: spy, defaults: scratch.defaults)
        await manager.requestAndSchedule()

        spy.status = .authorized
        await manager.syncWithSystem()

        #expect(manager.isEnabled)
        #expect(spy.pending.count == 1)
    }

    // MARK: Andamio

    enum SpyError: Error { case nope }

    /// El centro de notificaciones, de mentira. Modela lo único que importa del
    /// de verdad: que `add` **reemplaza** por identifier (por eso es un
    /// diccionario y no un array) y que el permiso puede negarse o fallar.
    @MainActor
    final class SpyNotificationCenter: NotificationScheduling {
        var granted = true
        var authorizationError: Error?
        var status: UNAuthorizationStatus = .notDetermined
        /// Se ejecuta **adentro** del pedido de permiso, justo antes de
        /// contestar: es el único lugar desde donde se puede simular lo que el
        /// jugador hace mientras el sistema piensa.
        var beforeAnswering: (() -> Void)?
        private(set) var requestedOptions: UNAuthorizationOptions?
        private(set) var pending: [String: UNNotificationRequest] = [:]
        private(set) var removeAllCount = 0

        func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
            requestedOptions = options
            beforeAnswering?()
            if let authorizationError { throw authorizationError }
            status = granted ? .authorized : .denied
            return granted
        }

        func add(_ request: UNNotificationRequest) async throws {
            pending[request.identifier] = request
        }

        func removeAllPendingNotificationRequests() {
            removeAllCount += 1
            pending.removeAll()
        }

        func authorizationStatus() async -> UNAuthorizationStatus { status }
    }
}

// MARK: - Legales

/// Los `.md` de `Distribution/site/` viajan en el bundle y se dibujan adentro
/// del juego. Lo que se prueba acá es el **parseo por bloques**, que es lo que
/// hace que un documento escrito para leerse en un editor a 80 columnas se lea
/// como texto corrido en un teléfono.
@Suite("Documentos legales")
@MainActor
struct LegalDocumentTests {

    /// ⚠️ El defecto que este parser existe para evitar: los `.md` vienen
    /// **cortados a mano a ~78 columnas**. Renderizados línea por línea, cada
    /// párrafo queda con cortes en lugares arbitrarios que en un iPhone no
    /// coinciden con el ancho de nada.
    @Test("un párrafo cortado a 80 columnas se re-arma en uno solo")
    func hardWrappedParagraphsAreJoined() {
        let blocks = LegalDocument.blocks(from: """
        Al descargar, instalar o usar FisuEvolution (el "Juego") aceptás estos
        términos. Si no estás de acuerdo, no lo uses y borralo del dispositivo.

        El Juego lo desarrolla una persona física.
        """)

        #expect(blocks == [
            .paragraph("Al descargar, instalar o usar FisuEvolution (el \"Juego\") aceptás estos términos. Si no estás de acuerdo, no lo uses y borralo del dispositivo."),
            .paragraph("El Juego lo desarrolla una persona física.")
        ])
    }

    @Test("los dos niveles de título se distinguen del cuerpo")
    func headingsAreRecognized() {
        let blocks = LegalDocument.blocks(from: """
        # Términos de Servicio — FisuEvolution

        ## 1. Aceptación

        Texto.
        """)

        #expect(blocks == [
            .title("Términos de Servicio — FisuEvolution"),
            .heading("1. Aceptación"),
            .paragraph("Texto.")
        ])
    }

    /// Los ítems de lista también vienen cortados: la continuación indentada es
    /// parte del MISMO punto, no un párrafo nuevo colgando debajo.
    @Test("una viñeta de varias líneas es una sola viñeta")
    func bulletsAbsorbTheirContinuation() {
        let blocks = LegalDocument.blocks(from: """
        - **Las cobra Apple.** Todas las compras se procesan a través de la App
          Store, con tu Apple Account.
        - **Reembolsos.** Los gestiona Apple.
        """)

        #expect(blocks == [
            .bullet("**Las cobra Apple.** Todas las compras se procesan a través de la App Store, con tu Apple Account."),
            .bullet("**Reembolsos.** Los gestiona Apple.")
        ])
    }

    @Test("un título corta el párrafo que venía abierto")
    func headingsFlushThePendingParagraph() {
        let blocks = LegalDocument.blocks(from: """
        Un párrafo sin línea en blanco antes del título.
        ## Título
        """)

        #expect(blocks == [
            .paragraph("Un párrafo sin línea en blanco antes del título."),
            .heading("Título")
        ])
    }

    // MARK: Los documentos de verdad

    @Test("los dos documentos viajan en el bundle y traen contenido", arguments: LegalDocument.Kind.allCases)
    func bothDocumentsShipInTheBundle(kind: LegalDocument.Kind) throws {
        let blocks = try #require(LegalDocument.load(kind),
                                  "\(kind.resourceName).md no está en el bundle: revisá Resources/Legal y el xcodegen")
        #expect(blocks.count > 10)

        // Los dos son bilingües: ES arriba, EN abajo, cada uno con su `# H1`.
        let titles = blocks.compactMap { block -> String? in
            if case .title(let text) = block { return text }
            return nil
        }
        #expect(titles.count == 2, "el documento tiene que traer la versión en español y la inglesa: \(titles)")
        #expect(titles.last?.hasSuffix("(English)") == true)
        // Y el contacto, que es lo que App Review busca.
        let hasContact = blocks.contains { block in
            if case .paragraph(let text) = block { return text.contains("adermanu@gmail.com") }
            return false
        }
        #expect(hasContact, "el documento tiene que decir a dónde escribir")
    }

    // MARK: El corte por idioma

    /// ⚠️ El defecto: la pantalla mostraba el documento ENTERO, con el español
    /// arriba, así que un jugador con el teléfono en inglés abría "Terms of
    /// Service" y tenía que hojear 150 líneas en otro idioma para llegar al
    /// suyo.
    @Test("cada idioma se lleva su mitad del documento")
    func eachLanguageGetsItsOwnHalf() {
        let blocks = LegalDocument.blocks(from: """
        # Términos de Servicio — FisuEvolution

        ## 1. Aceptación

        Texto en español.

        # Terms of Service — FisuEvolution (English)

        ## 1. Acceptance

        Text in English.
        """)

        #expect(LegalDocument.half(of: blocks, forLanguage: "es") == [
            .title("Términos de Servicio — FisuEvolution"),
            .heading("1. Aceptación"),
            .paragraph("Texto en español.")
        ])
        #expect(LegalDocument.half(of: blocks, forLanguage: "en") == [
            .title("Terms of Service — FisuEvolution (English)"),
            .heading("1. Acceptance"),
            .paragraph("Text in English.")
        ])
        // Un idioma que el juego no habla cae al base, igual que el resto de la UI.
        #expect(LegalDocument.half(of: blocks, forLanguage: "pt-BR")
                == LegalDocument.half(of: blocks, forLanguage: "es"))
    }

    /// Quedarse sin términos sería peor que mostrarlos de más: un documento de
    /// un solo idioma se muestra entero.
    @Test("un documento de un solo idioma se muestra entero")
    func singleLanguageDocumentSurvives() {
        let blocks = LegalDocument.blocks(from: """
        # Solo un idioma

        Texto.
        """)
        #expect(LegalDocument.half(of: blocks, forLanguage: "en") == blocks)
        #expect(LegalDocument.half(of: blocks, forLanguage: "es") == blocks)
    }

    /// El corte sobre los documentos REALES, que es lo que ve el jugador: cada
    /// mitad trae un solo `# H1` y las dos juntas son el documento entero.
    @Test("los documentos del bundle se cortan en dos mitades sanas",
          arguments: LegalDocument.Kind.allCases)
    func realDocumentsSplitCleanly(kind: LegalDocument.Kind) throws {
        let all = try #require(LegalDocument.load(kind))
        let es = LegalDocument.half(of: all, forLanguage: "es")
        let en = LegalDocument.half(of: all, forLanguage: "en")

        #expect(es.count + en.count == all.count, "el corte no puede perder ni duplicar bloques")
        #expect(es != en)
        for half in [es, en] {
            let titles = half.filter { if case .title = $0 { return true } else { return false } }
            #expect(titles.count == 1, "cada mitad trae un solo título de idioma")
            // Título + cuerpo. El piso es 2 y no más: la mitad inglesa de
            // `privacy.md` es a propósito UN párrafo —el resumen honesto con el
            // contacto—, mientras que la española va desglosada en viñetas.
            #expect(half.count >= 2, "una mitad sin cuerpo sería una pantalla de legales en blanco")
        }
        if case .title(let text)? = en.first {
            #expect(text.hasSuffix("(English)"))
        } else {
            Issue.record("la mitad inglesa tiene que arrancar en su título")
        }
    }

    /// ⚠️ **Guarda anti-deriva.** Los `.md` del bundle son COPIAS de
    /// `Distribution/site/`, que es lo que se publica en la web. Dos copias que
    /// se editan por separado terminan diciendo cosas distintas — y la que ve el
    /// jugador sería la que nadie revisó. Este test compara byte a byte usando
    /// `#filePath` para ubicar el repo; si algún día los tests corren fuera del
    /// árbol de fuentes, se saltea en vez de fallar.
    @Test("la copia del bundle es idéntica a la de Distribution/site",
          arguments: LegalDocument.Kind.allCases)
    func bundledCopyMatchesTheSourceOfTruth(kind: LegalDocument.Kind) throws {
        let repoRoot = URL(filePath: #filePath)
            .deletingLastPathComponent()  // FisuEvolutionTests/
            .deletingLastPathComponent()  // raíz del repo
        let site = repoRoot.appending(path: "Distribution/site/\(kind.resourceName).md")
        let copy = repoRoot.appending(path: "FisuEvolution/Resources/Legal/\(kind.resourceName).md")
        guard FileManager.default.fileExists(atPath: site.path()) else { return }

        #expect(try String(contentsOf: copy, encoding: .utf8) == String(contentsOf: site, encoding: .utf8),
                "\(kind.resourceName).md se editó de un solo lado: sincronizá Distribution/site con Resources/Legal")
    }
}
