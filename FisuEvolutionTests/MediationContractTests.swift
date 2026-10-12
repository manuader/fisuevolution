import Foundation
import Testing
@testable import FisuEvolution

/// La mediación está en el binario (PLAN-v2 E7b-a): los dos adaptadores
/// enlazados (Unity Ads y Meta) y la unión de SKAdNetwork en el `Info.plist`.
/// Sin los IDs, la atribución no funciona y el inventario que paga por
/// instalación no puja: no falla nada, sólo se factura menos.
@Suite("La mediación está en el binario")
struct MediationContractTests {
    private var skadIDs: [String] {
        let items = Bundle.main.object(forInfoDictionaryKey: "SKAdNetworkItems") as? [[String: String]] ?? []
        return items.compactMap { $0["SKAdNetworkIdentifier"] }
    }

    @Test("SKAdNetwork: Google, Unity y Meta, en minúscula y sin repetidos")
    func skadNetworkUnion() {
        let ids = skadIDs
        #expect(ids.count >= 85, "\(ids.count) IDs: la unión de Google y Unity son 89")
        #expect(Set(ids).count == ids.count, "hay repetidos")
        #expect(ids.allSatisfy { $0 == $0.lowercased() && $0.hasSuffix(".skadnetwork") })
        for required in ["cstr6suwn9.skadnetwork", "v9wttpbfk9.skadnetwork", "n38lu8286q.skadnetwork", "4dzt52r2t5.skadnetwork"] {
            #expect(ids.contains(required), "falta \(required)")
        }
    }

    /// Los nombres son los de los headers de cada adaptador.
    @Test("los dos adaptadores están enlazados", arguments: [
        "GADMediationAdapterUnity",
        "GADMediationAdapterFacebook",
    ])
    func adapterIsLinked(className: String) {
        #expect(NSClassFromString(className) != nil, "\(className) no está en el binario: falta el paquete o -ObjC")
    }
}
