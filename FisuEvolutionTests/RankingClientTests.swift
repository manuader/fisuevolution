import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("Cliente HTTP del ranking")
struct RankingClientTests {
    private static let installId = "11111111-2222-4333-8444-555555555555"
    private static let anonKey = "sb_publishable_test"

    private final class Recorder: @unchecked Sendable {
        private let lock = NSLock()
        private var seen: [URLRequest] = []
        var requests: [URLRequest] { lock.withLock { seen } }
        func record(_ request: URLRequest) { lock.withLock { seen.append(request) } }
    }

    private static func config(base: String? = "https://proyecto.supabase.co", key: String? = anonKey) -> RankingConfig {
        RankingConfig(schemaVersion: 1, enabled: true, baseURL: base.flatMap(URL.init(string:)), anonKey: key)
    }

    private static func client(
        config: RankingConfig = config(),
        recorder: Recorder = Recorder(),
        status: Int = 200,
        body: String = "{}",
        error: (any Error)? = nil
    ) -> HTTPRankingClient {
        HTTPRankingClient(
            config: config,
            identity: InstallIdentity(store: MemoryIdentityStore(installId)),
            fetch: { request in
                recorder.record(request)
                if let error { throw error }
                let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
                return (Data(body.utf8), response)
            }
        )
    }

    private let start = StartRunRequest(appVersion: "2.0", clientRunId: "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee")

    @Test("start-run arma el POST con los dos headers, el cuerpo y el installId fuera de la URL")
    func startRunRequestShape() async throws {
        let recorder = Recorder()
        let client = Self.client(recorder: recorder, body: #"{"runId":"r1","startedAt":1790000000}"#)

        let response = try await client.startRun(start)

        #expect(response == StartRunResponse(runId: "r1", startedAt: 1_790_000_000))
        let request = try #require(recorder.requests.first)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.absoluteString == "https://proyecto.supabase.co/functions/v1/start-run")
        #expect(request.url?.absoluteString.contains(Self.installId) == false)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer \(Self.anonKey)")
        #expect(request.value(forHTTPHeaderField: "apikey") == Self.anonKey)
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(request.timeoutInterval == 10)
        #expect(request.httpShouldHandleCookies == false)
        let data = try #require(request.httpBody)
        let body = try #require(JSONSerialization.jsonObject(with: data) as? [String: String])
        #expect(body == ["installId": Self.installId, "appVersion": "2.0", "clientRunId": start.clientRunId])
    }

    @Test("finish-run sin nombre no manda la clave name, y con nombre sí")
    func finishRunBody() async throws {
        let recorder = Recorder()
        let client = Self.client(recorder: recorder, body: #"{"status":"finished","nameStatus":"missing","realSeconds":120}"#)

        let sealed = try await client.finishRun(FinishRunRequest(runId: "r1", playedSeconds: 90, name: nil))
        #expect(sealed == FinishRunResponse(status: .finished, nameStatus: .missing, realSeconds: 120, rank: nil))
        _ = try await client.finishRun(FinishRunRequest(runId: "r1", playedSeconds: 90, name: "Fisu"))

        let bodies = try recorder.requests.map { request -> [String: Any] in
            let data = try #require(request.httpBody)
            return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        }
        #expect(bodies[0]["name"] == nil)
        #expect(bodies[0]["playedSeconds"] as? Int == 90)
        #expect(bodies[1]["name"] as? String == "Fisu")
        #expect(recorder.requests[0].url?.lastPathComponent == "finish-run")
    }

    @Test("leaderboard decodifica el top, la fila propia y Mis partidas")
    func leaderboardDecoding() async throws {
        let body = """
        {"top":[{"runId":"a","rank":1,"name":null,"realSeconds":100,"playedSeconds":50,"isMe":false}],
         "me":{"runId":"b","rank":3,"name":"Yo","realSeconds":300,"playedSeconds":150,"isMe":true},
         "myRank":3,
         "mine":[{"runId":"b","startedAt":1,"finishedAt":null,"realSeconds":null,"playedSeconds":null,
                  "name":"Yo","nameStatus":"pending","status":"review"}],
         "fetchedAt":1790000000}
        """
        let response = try await Self.client(body: body).leaderboard(LeaderboardRequest(mine: true))

        #expect(response.top.first?.name == nil)
        #expect(response.me?.isMe == true)
        #expect(response.myRank == 3)
        #expect(response.mine?.first?.nameStatus == .pending)
        #expect(response.mine?.first?.status == .review)
        #expect(response.mine?.first?.finishedAt == nil)
    }

    @Test("report acepta {ok:true}")
    func reportAcknowledged() async throws {
        let recorder = Recorder()
        try await Self.client(recorder: recorder, body: #"{"ok":true}"#).report(ReportRequest(runId: "r1"))
        #expect(recorder.requests.first?.url?.lastPathComponent == "report")
    }

    @Test("cada estado HTTP se traduce a su RankingError", arguments: [
        (400, RankingError.invalidName), (403, .notOwner), (409, .notActive), (429, .rateLimited),
        (503, .disabled), (500, .retryLater), (502, .retryLater), (404, .badResponse),
    ])
    func statusMapping(status: Int, expected: RankingError) async {
        let client = Self.client(status: status, body: #"{"error":"x"}"#)
        await #expect(throws: expected) { try await client.startRun(start) }
    }

    @Test("un 200 que no se puede decodificar es badResponse")
    func undecodableBody() async {
        let client = Self.client(body: #"{"nope":1}"#)
        await #expect(throws: RankingError.badResponse) { try await client.startRun(start) }
    }

    @Test("timeout o sin red es offline")
    func transportFailureIsOffline() async {
        for failure in [URLError(.timedOut), URLError(.notConnectedToInternet)] {
            let client = Self.client(error: failure)
            await #expect(throws: RankingError.offline) { try await client.startRun(start) }
        }
    }

    @Test("una config http://, sin clave o sin URL nunca pide nada")
    func unusableConfigNeverRequests() async {
        let configs = [Self.config(base: "http://proyecto.supabase.co"), Self.config(key: nil), Self.config(base: nil)]
        for config in configs {
            let recorder = Recorder()
            let client = Self.client(config: config, recorder: recorder)
            await #expect(throws: RankingError.disabled) { try await client.startRun(start) }
            #expect(recorder.requests.isEmpty)
        }
    }

    @Test("una respuesta que termina en http:// se descarta")
    func downgradedResponseIsRejected() async {
        let client = HTTPRankingClient(
            config: Self.config(), identity: InstallIdentity(store: MemoryIdentityStore(Self.installId))
        ) { _ in
            (Data(#"{"runId":"r","startedAt":1}"#.utf8),
             HTTPURLResponse(url: URL(string: "http://x.test")!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
        await #expect(throws: RankingError.badResponse) { try await client.startRun(start) }
    }
}
