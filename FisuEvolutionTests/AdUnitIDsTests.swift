import Foundation
import Testing
@testable import FisuEvolution

/// Las unidades de AdMob de la 2.0 (PLAN-v2, E7): una por MOMENTO, con el
/// fallback a Regalos mientras el dueño no cree la unidad real.
///
/// Lo que estos tests cuidan es que ningún lugar del juego se quede sin unidad:
/// un placement sin ID no falla al compilar ni al arrancar, falla en silencio
/// con un botón de video que nunca carga.
@Suite("Unidades de anuncios por momento")
struct AdUnitIDsTests {

    private static let gifts = "ca-app-pub-8575641544774372/8304196070"

    @Test("cada placement tiene una unidad, y los de la 2.0 sin crear caen a Regalos")
    func everyPlacementResolvesToAUnit() {
        let units = FeatureFlags.AdUnitIDs(rewardedGifts: Self.gifts)
        for placement in RewardedPlacement.allCases {
            #expect(units.rewarded(for: placement) == Self.gifts, "\(placement)")
        }
    }

    @Test("una unidad propia le gana al fallback", arguments: [
        (RewardedPlacement.wheel, "ca-app-pub-8575641544774372/1111111111"),
        (RewardedPlacement.treasure, "ca-app-pub-8575641544774372/2222222222"),
        (RewardedPlacement.visitor, "ca-app-pub-8575641544774372/3333333333"),
        (RewardedPlacement.daily, "ca-app-pub-8575641544774372/4444444444"),
    ])
    func aSpecificUnitWinsOverTheFallback(placement: RewardedPlacement, unit: String) {
        let units = FeatureFlags.AdUnitIDs(
            rewardedGifts: Self.gifts,
            rewardedWheel: placement == .wheel ? unit : nil,
            rewardedTreasure: placement == .treasure ? unit : nil,
            rewardedVisitor: placement == .visitor ? unit : nil,
            rewardedDaily: placement == .daily ? unit : nil
        )
        #expect(units.rewarded(for: placement) == unit)
        // Y no se le escapa a los otros momentos.
        for other in RewardedPlacement.allCases where other != placement {
            #expect(units.rewarded(for: other) == Self.gifts, "\(other)")
        }
    }

    /// El JSON del build 4 no trae ninguna de las claves nuevas: tiene que
    /// seguir decodificando, con todo lo nuevo en `nil`.
    @Test("un adUnitIDs viejo, sin las claves de la 2.0, sigue decodificando")
    func anOldJSONStillDecodes() throws {
        let json = Data("""
        {"rewardedGifts": "\(Self.gifts)", "interstitial": "ca-app-pub-8575641544774372/5270838626"}
        """.utf8)
        let units = try JSONDecoder().decode(FeatureFlags.AdUnitIDs.self, from: json)
        #expect(units.rewardedWheel == nil)
        #expect(units.rewardedInterstitial == nil)
        #expect(units.appOpen == nil)
        #expect(units.rewarded(for: .daily) == Self.gifts)
    }

    @Test("el JSON embarcado trae la pausa publicitaria real y el app open apagado")
    func theBundledFlagsDeclareTheNewFormats() throws {
        let flags = try GameContentLoader.load(from: .main).flags
        let declared = flags.declaredAdUnitIDs
        // La unidad que ya existe en AdMob ("unidad", `…/1615619906`).
        #expect(declared.rewardedInterstitial == "ca-app-pub-8575641544774372/1615619906")
        // [GATE DEL DUEÑO] Sin unidad de app open creada: queda en null.
        #expect(declared.appOpen == nil)
    }

    @Test("los IDs de prueba de Google cubren los cuatro formatos")
    func googleTestIDsCoverEveryFormat() {
        let test = FeatureFlags.AdUnitIDs.googleTest
        #expect(test.rewardedGifts == "ca-app-pub-3940256099942544/1712485313")
        #expect(test.interstitial == "ca-app-pub-3940256099942544/4411468910")
        #expect(test.rewardedInterstitial == "ca-app-pub-3940256099942544/6978759866")
        #expect(test.appOpen == "ca-app-pub-3940256099942544/5575463023")
        #expect(test.usesAnyGoogleTestID)
    }

    /// El caso que importa es el build medio migrado: todo real menos UNA
    /// unidad nueva olvidada en la de prueba.
    @Test("un solo ID de prueba en cualquier formato alcanza para delatar al build")
    func aSingleTestIDAnywhereIsCaught() {
        let real = FeatureFlags.AdUnitIDs(
            rewardedGifts: Self.gifts,
            interstitial: "ca-app-pub-8575641544774372/5270838626",
            rewardedInterstitial: "ca-app-pub-8575641544774372/1615619906"
        )
        #expect(!real.usesAnyGoogleTestID)

        let forgotten = FeatureFlags.AdUnitIDs(
            rewardedGifts: Self.gifts,
            interstitial: "ca-app-pub-8575641544774372/5270838626",
            appOpen: "ca-app-pub-3940256099942544/5575463023"
        )
        #expect(forgotten.usesAnyGoogleTestID)
    }
}
