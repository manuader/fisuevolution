import EconomyKit
import Foundation

/// Un paso del tutorial v2 (PLAN-v2 E9): o explica (y "Entendido" espera 5 s) o pide una
/// acción (y sólo avanza haciéndola). Es un valor: el núcleo, las lecciones, el Tour y el
/// repaso son listas de esto.
struct TutorialStep: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case explain
        case action(TutorialSignal)
    }

    /// Dónde se dibuja. El overlay de la raíz sólo dibuja `board`; las hojas tienen su coach
    /// (`TutorialSheetCoach`) y los popups su tarjeta (`TutorialInlineCard`).
    enum Surface: Equatable, Sendable {
        case board
        case page(GameScreen)
        case characterSheet
        case embedded
    }

    enum SwipeDirection: Equatable, Sendable {
        case left, right, up, down
    }

    enum Hand: Equatable, Sendable {
        case none
        case tap
        case hold
        case swipe(SwipeDirection)
    }

    /// Lo que publica el marcador `tutorial.step` (sin traducir).
    let id: String
    let kind: Kind
    let target: TutorialTarget?
    var windows: [TutorialTarget] = []
    var boardTarget: GameState.TutorialBoardTarget?
    var surface: Surface = .board
    var hand: Hand = .tap
    /// La clave del cartel, escrita entera (la busca `TutorialCurriculumTests`).
    let textKey: String
    var pose = "fisura_wave"

    var clockKind: TutorialStepClock.Kind {
        if case .action = kind { return .action }
        return .explain
    }

    var signal: TutorialSignal? {
        if case .action(let signal) = kind { return signal }
        return nil
    }

    static func explain(
        _ id: String, text: String, on target: TutorialTarget? = nil,
        surface: Surface = .board, hand: Hand = .none, pose: String = "fisura_wave"
    ) -> TutorialStep {
        TutorialStep(id: id, kind: .explain, target: target, surface: surface, hand: hand, textKey: text, pose: pose)
    }

    static func act(
        _ id: String, _ signal: TutorialSignal, text: String, on target: TutorialTarget?,
        surface: Surface = .board, hand: Hand = .tap, windows: [TutorialTarget] = [],
        boardTarget: GameState.TutorialBoardTarget? = nil
    ) -> TutorialStep {
        TutorialStep(id: id, kind: .action(signal), target: target, windows: windows,
                     boardTarget: boardTarget, surface: surface, hand: hand, textKey: text)
    }
}

/// La foto de lo que el tutorial mira, tomada al empezar cada paso y en cada refresh. Son
/// contadores del save y proyecciones ya publicadas: armarla cuesta una docena de lecturas.
struct TutorialProbe: Equatable, Sendable {
    var taps = 0
    var hires = 0
    var merges = 0
    var upgradeLevels = 0
    var passivesUnlocked = 0
    var visibleFloor = 0
    var pinnedTypeId: String?
    var canAffordSpawn = false
    var ftueTapped = false
    var ftueSpawned = false
    var ftueMerged = false
}

/// Lo que las vistas avisan y no queda en el save.
enum TutorialEvent: Hashable, Sendable {
    /// La acción firma de una lección (`tutorialTipCompleted`): abrir el mapa, reencarnar,
    /// contratar con el atajo, tocar un acceso de la columna…
    case lessonAction(String)
    case screenOpened(GameScreen)
    case pagerMoved
    case pickerOpened
    case elevatorExpanded
    case characterSheetOpened
}

/// Qué hace avanzar un paso de acción.
enum TutorialSignal: Hashable, Sendable {
    /// Núcleo: tocó y ya le alcanza para contratar (las dos cosas, o el paso siguiente
    /// iluminaría un botón impagable con el resto bloqueado).
    case coreTappedAndAffordable
    case coreHired
    case coreMerged
    case tapped
    case hired
    case merged
    case upgradeBought
    case passiveUnlocked
    case floorChanged
    case pinned
    case unpinned
    case lessonAction
    case screenOpened(GameScreen)
    case pagerMoved
    case pickerOpened
    case elevatorExpanded
    case characterSheetOpened

    /// Las del núcleo son absolutas (los milestones `ftue.*` persisten: retomar a mitad no
    /// rehace nada); las demás miran el cambio desde el inicio del paso.
    func isSatisfied(baseline: TutorialProbe, now: TutorialProbe, events: Set<TutorialEvent>, lesson: String?) -> Bool {
        switch self {
        case .coreTappedAndAffordable: now.ftueTapped && now.canAffordSpawn
        case .coreHired: now.ftueSpawned
        case .coreMerged: now.ftueMerged
        case .tapped: now.taps > baseline.taps
        case .hired: now.hires > baseline.hires
        case .merged: now.merges > baseline.merges
        case .upgradeBought: now.upgradeLevels > baseline.upgradeLevels
        case .passiveUnlocked: now.passivesUnlocked > baseline.passivesUnlocked
        case .floorChanged: now.visibleFloor != baseline.visibleFloor
        case .pinned: now.pinnedTypeId != nil && now.pinnedTypeId != baseline.pinnedTypeId
        case .unpinned: baseline.pinnedTypeId != nil && now.pinnedTypeId == nil
        case .lessonAction: lesson.map { events.contains(.lessonAction($0)) } ?? false
        case .screenOpened(let screen): events.contains(.screenOpened(screen))
        case .pagerMoved: events.contains(.pagerMoved)
        case .pickerOpened: events.contains(.pickerOpened)
        case .elevatorExpanded: events.contains(.elevatorExpanded)
        case .characterSheetOpened: events.contains(.characterSheetOpened)
        }
    }
}
