import EconomyKit
import Foundation

/// La barra de abajo progresiva (PLAN-v2 E3): qué pestañas tiene el jugador, el
/// "¡Nuevo!" y la persistencia en `meta.unlockedTabs` (save v6).
extension GameState {
    /// Las abiertas en esta instalación que todavía no se miraron. Vive en
    /// `UserDefaults` y no en el save: es una pista de UI, como las lecciones.
    static let newTabsKey = "tabs.new"

    /// Las pestañas abiertas, en el orden de la barra (y del paginador del menú).
    var unlockedTabsInBarOrder: [GameScreen] {
        GameScreen.barOrder.filter(unlockedTabs.contains)
    }

    /// Lo llama `refreshProjections` a 8 Hz: son cuatro lecturas y unas
    /// operaciones de conjuntos, y escribe sólo si algo cambió.
    func refreshUnlockedTabs() {
        guard let content, var player else { return }
        let earned = progressiveTabsEnabled
            ? TabUnlockRules.unlocked(config: content.tabs, signals: tabSignals(player: player))
            : Set(GameScreen.barOrder)
        // Un save viejo puede traer "store": no se reescribe (por si la Tienda
        // vuelve), pero tampoco se cuela en la barra.
        let saved = Set(player.meta.unlockedTabs.compactMap(GameScreen.init(rawValue:)))
            .intersection(GameScreen.barOrder)
        let fresh = earned.subtracting(saved)
        if !fresh.isEmpty {
            player.meta.unlockedTabs.formUnion(fresh.map(\.rawValue))
            self.player = player
            scheduleSave()
            if progressiveTabsEnabled {
                rememberNew(fresh.subtracting(content.tabs.alwaysOpen))
            }
        }
        let all = saved.union(earned)
        if unlockedTabs != all { unlockedTabs = all }
        let new = storedNewTabs.intersection(all)
        if newTabs != new { newTabs = new }
    }

    /// El jugador abrió la pestaña: se le va el "¡Nuevo!".
    func markTabOpened(_ screen: GameScreen) {
        var stored = storedNewTabs
        guard stored.remove(screen) != nil else { return }
        UserDefaults.standard.set(stored.map(\.rawValue).sorted(), forKey: Self.newTabsKey)
        newTabs.remove(screen)
    }

    func tabSignals(player: PlayerState) -> TabUnlockSignals {
        let defaults = UserDefaults.standard
        return TabUnlockSignals(
            tutorialCoreDone: defaults.bool(forKey: "fisuTutorialDone"),
            ownsAnySkin: !player.meta.allOwnedSkins.isEmpty,
            hasReceivedChest: player.meta.welcomeChestGiven
                || player.meta.chestsPending > 0
                || player.meta.prestigeChestsPending > 0,
            sessionsAfterCore: defaults.integer(forKey: Self.sessionsAfterPhaseKey)
        )
    }

    private var storedNewTabs: Set<GameScreen> {
        Set((UserDefaults.standard.stringArray(forKey: Self.newTabsKey) ?? []).compactMap(GameScreen.init(rawValue:)))
    }

    private func rememberNew(_ screens: Set<GameScreen>) {
        guard !screens.isEmpty else { return }
        let all = storedNewTabs.union(screens)
        UserDefaults.standard.set(all.map(\.rawValue).sorted(), forKey: Self.newTabsKey)
    }
}
