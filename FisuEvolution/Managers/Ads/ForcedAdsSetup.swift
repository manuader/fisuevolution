import Foundation

/// Cómo arrancan los anuncios forzados de la 2.0 en este proceso (PLAN-v2 E7):
/// si corren, con qué política y desde qué config. Es lo único que la App
/// llama: `ForcedAdsPacer` y `NaturalBreakPolicy` (E7a) no saben de dónde salen
/// sus números.
@MainActor
enum ForcedAdsSetup {
    enum Mode: Equatable {
        /// Sin forzados: los unit tests, y los UI tests que no los piden.
        case off
        case production
        /// `--uitest-ad-break`: la pausa publicitaria en cada corte, sin esperas.
        case uiTestAdBreak
    }

    nonisolated static func mode(arguments: [String], environment: [String: String]) -> Mode {
        if environment["XCTestConfigurationFilePath"] != nil { return .off }
        if arguments.contains("--uitest-ad-break") { return .uiTestAdBreak }
        if arguments.contains(where: { $0.hasPrefix("--uitest") }) { return .off }
        return .production
    }

    /// La política de los UI tests de la pausa: sale en cada corte y sin
    /// gracias. Construida a mano a propósito: `ads.json` no puede bajar de los
    /// pisos (E7a), y no tiene por qué.
    static let uiTestAdBreakPolicy = NaturalBreakPolicy(
        minSecondsBetweenForced: 0,
        graceSecondsAfterLaunch: 0,
        graceSecondsAfterRewarded: 0,
        alternation: [.rewardedInterstitial],
        appOpenMinSecondsAway: AdsRemoteConfig.Floor.appOpenMinSecondsAway,
        appOpenMinSecondsBetween: AdsRemoteConfig.Floor.appOpenMinSecondsBetween,
        appOpenMinSessionNumber: AdsRemoteConfig.Floor.appOpenMinSessionNumber,
        enabledFormats: [.rewardedInterstitial]
    )

    /// Construirlo cuenta un arranque en frío (`ForcedAdsPacer.init`): se llama
    /// una vez por proceso, desde `startServices`.
    static func makePacer(mode: Mode, config: AdsRemoteConfig?, defaults: UserDefaults = .standard) -> ForcedAdsPacer? {
        switch mode {
        case .off:
            nil
        case .production:
            ForcedAdsPacer(
                policy: config.map(NaturalBreakPolicy.init(config:)) ?? .default,
                store: AdsPacingStore(defaults: defaults)
            )
        case .uiTestAdBreak:
            ForcedAdsPacer(
                policy: uiTestAdBreakPolicy,
                store: AdsPacingStore(defaults: defaults, key: "ads.pacing.uitest")
            )
        }
    }

    /// Lo que llegó del sitio rige desde ya para la cadencia y los interruptores.
    /// Los IDs, desde el próximo arranque: el proveedor ya está creado.
    static func apply(_ outcome: AdsRemoteConfigLoader.RefreshOutcome, to pacer: ForcedAdsPacer) {
        guard case .updated(let config) = outcome else { return }
        pacer.policy = NaturalBreakPolicy(config: config)
    }
}
