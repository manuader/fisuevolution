import Foundation

/// Baja, valida y guarda la config remota de anuncios (`AdsRemoteConfig`).
///
/// ## Las dos promesas, que son las que lo hacen seguro de cablear al arranque
///
/// 1. **No bloquea el arranque.** `current()` lee sólo el disco —la caché, o el
///    respaldo del bundle— y vuelve al instante; la red vive aparte, en
///    `refresh()`, que se dispara en segundo plano y cuyo resultado rige desde
///    que llega (o desde el próximo arranque, según quién lo use). Un arranque
///    sin red o con el sitio caído es exactamente igual a uno con red.
/// 2. **No manda datos del jugador.** Es un `GET` pelado a una URL fija: sin
///    query, sin cuerpo, sin cookies y sin headers propios. Lo único que viaja
///    es lo que manda cualquier pedido del sistema (la IP y el User-Agent de
///    `URLSession`), y la sesión es efímera, así que tampoco deja rastro local.
///
/// ## Qué se descarta
///
/// Todo lo que no sea un 200 por HTTPS con un archivo válido entero: una URL
/// `http://` (ni siquiera se pide), una redirección a `http://`, un estado
/// distinto de 200, un cuerpo de más de 64 KB, un JSON roto o un archivo que
/// no pasa `AdsRemoteConfig.validate`. En todos esos casos **la caché anterior
/// queda intacta**: un archivo malo publicado no le borra a nadie la última
/// config buena.
struct AdsRemoteConfigLoader: Sendable {
    typealias Fetch = @Sendable (URLRequest) async throws -> (Data, URLResponse)

    /// Dónde se publica. Es el mismo sitio que sirve `app-ads.txt`.
    static let productionURL = URL(string: "https://adergames-site.vercel.app/config/ads.json")!

    /// Un archivo de config de anuncios mide unos cientos de bytes; algo de
    /// este tamaño no es una config, es otra cosa.
    static let maxBytes = 64 * 1024

    /// De dónde salió lo que devuelve `current()`.
    enum Source: Equatable, Sendable {
        case cache
        case bundle
    }

    struct Loaded: Equatable, Sendable {
        let config: AdsRemoteConfig
        let source: Source
    }

    /// Lo que pasó al pedir la versión publicada.
    enum RefreshOutcome: Equatable, Sendable {
        /// Llegó, es válida y quedó en la caché.
        case updated(AdsRemoteConfig)
        /// Llegó algo, pero no se acepta. La caché no se toca.
        case rejected(AdsRemoteConfig.Rejection)
        /// No se pudo pedir (sin red, timeout). La caché no se toca.
        case unreachable
    }

    let remoteURL: URL
    let publisherID: String?
    let cacheURL: URL
    let bundledURL: URL?
    let fetch: Fetch

    init(
        remoteURL: URL = AdsRemoteConfigLoader.productionURL,
        publisherID: String? = AdsRemoteConfig.ownPublisherID,
        cacheURL: URL = AdsRemoteConfigLoader.defaultCacheURL,
        bundledURL: URL? = Bundle.main.url(forResource: "ads", withExtension: "json"),
        fetch: @escaping Fetch = AdsRemoteConfigLoader.urlSessionFetch
    ) {
        self.remoteURL = remoteURL
        self.publisherID = publisherID
        self.cacheURL = cacheURL
        self.bundledURL = bundledURL
        self.fetch = fetch
    }

    /// En `Caches` y no en `Application Support`: si el sistema la purga, no
    /// se pierde nada, porque el próximo `refresh()` la repone y mientras
    /// tanto rige el respaldo del bundle.
    static var defaultCacheURL: URL {
        URL.cachesDirectory.appending(path: "ads-remote-config.json")
    }

    /// La sesión efímera: sin caché HTTP en disco, sin cookies y sin
    /// credenciales guardadas.
    private static let session = URLSession(configuration: .ephemeral)

    static let urlSessionFetch: Fetch = { request in
        try await AdsRemoteConfigLoader.session.data(for: request)
    }

    // MARK: - Sin red

    /// Lo mejor que hay en disco, al instante: la caché si sigue siendo válida,
    /// y si no el respaldo del bundle. `nil` sólo si las dos faltan o están
    /// rotas (el test del bundle impide que se embarque así).
    ///
    /// La caché se **revalida** al leerla, no sólo al escribirla: un archivo
    /// guardado por un build anterior puede no cumplir las reglas de este.
    func current() -> Loaded? {
        if let data = try? Data(contentsOf: cacheURL),
           let config = try? AdsRemoteConfig.decodeValidated(data, publisherID: publisherID) {
            return Loaded(config: config, source: .cache)
        }
        if let bundledURL,
           let data = try? Data(contentsOf: bundledURL),
           let config = try? AdsRemoteConfig.decodeValidated(data, publisherID: publisherID) {
            return Loaded(config: config, source: .bundle)
        }
        return nil
    }

    // MARK: - Con red

    /// Pide la versión publicada y, si es válida, la deja en la caché.
    func refresh() async -> RefreshOutcome {
        // Sólo HTTPS, y se chequea ANTES de pedir: una URL `http://` no se pide
        // nunca, ni para descartar la respuesta después.
        guard Self.isHTTPS(remoteURL) else { return .rejected(.notHTTPS) }

        var request = URLRequest(url: remoteURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        request.httpMethod = "GET"
        request.httpShouldHandleCookies = false

        let fetched: (Data, URLResponse)
        do {
            fetched = try await fetch(request)
        } catch {
            return .unreachable
        }
        let (data, response) = fetched

        // Una redirección puede terminar en `http://`: lo que se mira es la URL
        // de la respuesta, no sólo la que se pidió.
        guard let finalURL = response.url, Self.isHTTPS(finalURL) else { return .rejected(.notHTTPS) }
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            return .rejected(.badResponse)
        }
        guard data.count <= Self.maxBytes else { return .rejected(.tooLarge) }

        let config: AdsRemoteConfig
        do {
            config = try AdsRemoteConfig.decodeValidated(data, publisherID: publisherID)
        } catch let rejection as AdsRemoteConfig.Rejection {
            return .rejected(rejection)
        } catch {
            return .rejected(.undecodable)
        }

        // Se guardan los bytes que se validaron, tal cual. Si la escritura
        // falla, la config igual sirve para esta sesión.
        try? data.write(to: cacheURL, options: .atomic)
        return .updated(config)
    }

    private static func isHTTPS(_ url: URL) -> Bool {
        url.scheme?.lowercased() == "https"
    }
}
