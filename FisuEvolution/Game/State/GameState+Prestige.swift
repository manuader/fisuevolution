import EconomyKit
import Foundation

/// RF-16: el antes y el después de reencarnar. El popup decía cuánto ORO ganabas
/// pero no que cada ORO vale +12% de multiplicador global, así que el jugador
/// veía "ganás 14" sin forma de saber qué compra.
///
/// ⚠️ `multiplierAfter` sale de `economy.globalMultiplier(oroEarnedLifetime:prestigeBonus:)`,
/// la MISMA función que aplica `PrestigeCalculator.applyReincarnation`. Calcularlo
/// aparte es exactamente cómo el popup termina mintiendo, y un popup que miente le
/// enseña al jugador a no creerle. `PrestigePreviewTests` lo pinea.
struct PrestigePreview: Equatable {
    let oroGained: Int
    let multiplierBefore: Double
    let multiplierAfter: Double
    /// Lo que muere: unidades en la torre, plata y mejoras de personaje.
    let unitsLost: Int
    let coinsLost: Double
    /// El camino hasta el PRÓXIMO ORO, para el botón adelantado ("al llegar a
    /// lujo"): cuánta plata de lifetime falta y qué fracción ya está hecha.
    /// Sale de la inversa de `oroTotal` — la misma cuenta que
    /// `giveEarningsForPrestigeTesting` usa del otro lado.
    let coinsToNextOro: Double
    let nextOroProgress: Double

    /// Antes del bootstrap no hay economía ni jugador: multiplicador neutro.
    static let empty = PrestigePreview(
        oroGained: 0,
        multiplierBefore: 1,
        multiplierAfter: 1,
        unitsLost: 0,
        coinsLost: 0,
        coinsToNextOro: 0,
        nextOroProgress: 0
    )

    /// Reencarnar ahora cambia algo. Con 0 ORO por cobrar, el "después" es el
    /// "antes" y la flecha no tiene nada que mostrar.
    var isWorthIt: Bool { oroGained > 0 }

    /// "2,3". Un decimal mientras se lee de un vistazo y el abreviador de plata
    /// de ahí para arriba: el multiplicador escala como todo lo demás del juego.
    static func multiplierText(_ value: Double) -> String {
        value < 1000
            ? value.formatted(.number.precision(.fractionLength(1)))
            : CoinFormatter.string(from: value)
    }

    var multiplierBeforeText: String { Self.multiplierText(multiplierBefore) }
    var multiplierAfterText: String { Self.multiplierText(multiplierAfter) }
    var coinsLostText: String { CoinFormatter.string(from: coinsLost) }
}

/// Reencarnación (F7: gate por ORO). Separado de `GameState.swift` para que el
/// frente de prestigio no comparta archivo con los otros cinco dominios.
extension GameState {
    /// ORO que ganarías reencarnando ahora.
    var prestigeOroGained: Int {
        guard let economy, let player else { return 0 }
        return PrestigeCalculator.oroGained(state: player, economy: economy)
    }

    /// El cálculo en vivo, contra el `PlayerState` autoritativo. **No lo leas
    /// desde SwiftUI**: la vista lee `prestigePreview`, la proyección que publica
    /// `refreshProjections` a 8 Hz. Este getter existe para alimentarla (y para
    /// que el test pueda comparar la proyección contra la verdad).
    var prestigePreviewNow: PrestigePreview {
        guard let economy, let player else { return .empty }
        let gained = PrestigeCalculator.oroGained(state: player, economy: economy)
        let prestigeBonus = player.meta.derivedEffects.prestigeBonus
        // La inversa de `oroTotal`: con cuánto lifetime cae el ORO que sigue.
        let curve = economy.config.oro
        let earnedTotal = player.meta.oroEarnedLifetime + gained
        let nextOroAt = curve.divisor * pow(Double(earnedTotal + 1), 1 / curve.exponent)
        let lifetime = player.meta.lifetimeEarnings
        return PrestigePreview(
            oroGained: gained,
            multiplierBefore: economy.globalMultiplier(
                oroEarnedLifetime: player.meta.oroEarnedLifetime,
                prestigeBonus: prestigeBonus
            ),
            multiplierAfter: economy.globalMultiplier(
                oroEarnedLifetime: player.meta.oroEarnedLifetime + gained,
                prestigeBonus: prestigeBonus
            ),
            unitsLost: player.run.totalUnits,
            coinsLost: player.run.coins,
            coinsToNextOro: max(0, nextOroAt - lifetime),
            nextOroProgress: nextOroAt > 0 ? min(1, max(0, lifetime / nextOroAt)) : 0
        )
    }

    /// La llama `refreshProjections`. Escribe sólo si cambió, como el resto de
    /// las proyecciones: SwiftUI no se invalida al pedo.
    func refreshPrestigePreview() {
        let preview = prestigePreviewNow
        if prestigePreview != preview { prestigePreview = preview }
    }

    /// "+12%": cuánto multiplicador compra cada ORO. Sale de `economy.json`, no
    /// de un literal en la copia — el rebalance lo mueve por dato.
    var prestigeMultiplierPerOroText: String {
        let perOro = economy?.config.oro.globalMultiplierPerOro ?? 0
        return perOro.formatted(.percent.precision(.fractionLength(0...1)))
    }

    func confirmPrestige() {
        guard let economy, let content, var player = player,
              PrestigeCalculator.canReincarnate(state: player, economy: economy)
        else { return }
        PrestigeCalculator.applyReincarnation(
            state: &player,
            economy: economy,
            tiers: content.tiers,
            floorTable: content.floorTable,
            now: Date().timeIntervalSince1970
        )
        self.player = player
        // El cofre de la reencarnación —el único con piso de rareza— se otorga
        // DESPUÉS de `applyReincarnation`, que hace `run = .fresh(...)`: darlo
        // antes lo perdería el día que el contador se mude a `run`.
        awardChest(minRarity: .epica)
        reconcileTower()
        audio?.play(.prestige)
        haptics?.play(.rarity)
        gameCenter?.report(.firstPrestige)
        // Los tres logros de reencarnación miran `meta.prestigeLevel`, que ya
        // subió, así que en la práctica los cruza el `reconcileTower()` de arriba.
        // Queda igual porque el orden de esas dos líneas no es un contrato: si
        // mañana el reconciliador deja de pasar por `updateMaxFloorStat`, esto
        // sigue siendo el choke point del prestigio. Es idempotente: no cuesta.
        evaluateAchievements()
        bumpBoard()
        Task { await persistNow() }
        Log.economy.info("reincarnated: level \(player.meta.prestigeLevel), oro \(player.meta.oro)")

        // **Transición suave #2** (`Docs/ads-integration.md`): el reset ya
        // ocurrió y la partida nueva todavía no arrancó. Es el corte más
        // natural del juego.
        //
        // ⚠️ Va con `Task` y al FINAL: `confirmPrestige` es síncrona y el
        // llamador cuenta con que al volver el estado ya está reencarnado.
        // Y ⚠️ **el cofre de reencarnación se otorgó arriba**, así que la
        // cola de celebraciones puede tener su turno pedido — por eso el
        // disparo pasa por `showInterstitialIfAppropriate`, que se niega
        // mientras haya una celebración con el turno. Sin ese filtro, el
        // interstitial taparía el cofre épico que el jugador se acaba de
        // ganar, que es el peor momento posible.
        Task { await showInterstitialIfAppropriate() }
    }
}
