import Foundation
import Testing
@testable import FisuEvolution

final class MemoryIdentityStore: InstallIdentityStore, @unchecked Sendable {
    private let lock = NSLock()
    private var value: String?

    init(_ value: String? = nil) { self.value = value }

    func read() -> String? { lock.withLock { value } }
    func write(_ newValue: String) { lock.withLock { value = newValue } }
}

@Suite("Identidad de instalación")
struct InstallIdentityTests {
    @Test("genera un UUID en minúsculas y lo repite")
    func isStableAndLowercase() throws {
        let store = MemoryIdentityStore()
        let identity = InstallIdentity(store: store)

        let first = identity.installId()
        #expect(identity.installId() == first)
        #expect(store.read() == first)
        #expect(first == first.lowercased())
        #expect(UUID(uuidString: first) != nil)
    }

    @Test("lo guardado en mayúsculas se devuelve en minúsculas")
    func normalizesWhatWasSaved() {
        let upper = UUID().uuidString.uppercased()
        #expect(InstallIdentity(store: MemoryIdentityStore(upper)).installId() == upper.lowercased())
    }

    @Test("un valor guardado que no es un UUID se reemplaza")
    func replacesGarbage() {
        let store = MemoryIdentityStore("no-soy-un-uuid")
        let id = InstallIdentity(store: store).installId()
        #expect(UUID(uuidString: id) != nil)
        #expect(store.read() == id)
    }
}
