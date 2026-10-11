import EconomyKit
import Foundation
@testable import FisuEvolution

extension GameState {
    /// Recorre la lección de Mejoras entera como la juega el jugador: abre la hoja (que tapa el
    /// tablero, como en la raíz), compra un nivel, la cierra y confirma cuando el candado se abre.
    func finishUpgradesLessonForTest() {
        tutorialTipHandled(opening: .upgrades)
        uiCoversBoard = true
        if let type = characterUpgradeTypes.first { buyCharacterUpgrade(typeID: type.id) }
        refreshProjections()
        uiCoversBoard = false
        advanceTutorial(delta: TutorialStepClock.explainLock)
        confirmTutorialStep()
    }
}
