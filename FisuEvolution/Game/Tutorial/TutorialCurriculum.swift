import Foundation

/// El currículo del tutorial v2 (PLAN-v2 E9). El núcleo va acá; las lecciones, en su
/// `TutorialLesson.steps`; el Tour, en E9b.
enum TutorialCurriculum {
    /// Tocar → contratar → fusionar → cierre, 2-3 minutos, y termina justo después del reveal
    /// del primer merge (que se reproduce limpio: con una celebración en pantalla el overlay
    /// entero se esconde). Secuencial, con scrim; el cierre entrega el cofre de bienvenida.
    /// Los textos son los del núcleo de la v1.
    ///
    /// ⚠️ Contratar son dos pasos: `core.hire` ilumina el tab que abre FisuJobs (no un botón que
    /// compra) y `core.hire.inside` vive ADENTRO de la hoja, que se presenta por encima del
    /// overlay: ahí lo guía el coach de la hoja. `hireCharacter` marca `ftue.spawned`, así que al
    /// cerrarse la hoja ya está en "fusioná"; cerrada sin contratar, vuelve a `core.hire`.
    ///
    /// ⚠️ Poses: sólo `wave` y `celebrate` (las otras salieron del atlas).
    static let core: [TutorialStep] = [
        .act("core.tap", .coreTappedAndAffordable, text: "tutorial.step.tap", on: .boardUnit,
             windows: [.coins], boardTarget: .anyUnit),
        .act("core.hire", .screenOpened(.jobs), text: "tutorial.step.hire", on: .hire, windows: [.coins]),
        .act("core.hire.inside", .coreHired, text: "tutorial.jobs.hint", on: .jobsRecommended,
             surface: .page(.jobs)),
        // Enseña los DOS gestos de fusión y se completa con cualquiera: después de contratar
        // hay un solo par mergeable, así que no pueden ser dos pasos.
        .act("core.merge", .coreMerged, text: "tutorial.step.merge", on: .boardUnit, boardTarget: .mergePair),
        .explain("core.finish", text: "tutorial.step.finish", pose: "fisura_celebrate"),
    ]
}

/// Qué enseña una mecánica (PLAN-v2 E9, regla de cobertura).
enum TutorialCoverage: Equatable {
    case core(String)
    case lesson(GameState.TutorialLesson)
    case inline(TutorialInlineLesson)
    /// Una pantalla que se explica sola (la pausa publicitaria tiene su pantalla previa; el
    /// permiso de avisos, su tarjeta). Va con su id para que el registro los nombre.
    case selfExplained(String)
    /// Todavía sin lección: tiene que estar en `TutorialMechanic.knownGaps`.
    case gap
}

/// Todas las mecánicas del juego. **Cada épica que suma una, suma su caso acá**: el `switch` de
/// `coverage` no compila sin decir qué la enseña.
@MainActor
enum TutorialMechanic: String, CaseIterable {
    case tap, hire, merge, welcomeChest
    case quickHire, passiveIncome, characterMultipliers, orgChart, elevatorPanel, elevatorKeypad
    case floorSwipe, floorFull
    case offlineDoubling, boosts, dailyGifts, skins, achievements, chests, prestigeAndOro, oroUpgrades
    case career, store, menuSwipe, characterSheet, newTabs, hirePriceStep, staffedFloors, prestigeGate
    case customsPackage, mattress, wheel, visitor, visitorPopup, eventChip, album, sideRail
    case mergeAll, share, oroShopShelf, pendingTriple, autoTap, luckOdds, offers
    case cosmetics, skinEffects, extraSlots, notificationsPermission, adBreak

    var coverage: TutorialCoverage {
        switch self {
        case .tap: .core("core.tap")
        case .hire: .core("core.hire")
        case .merge: .core("core.merge")
        case .welcomeChest: .core("core.finish")
        case .quickHire: .lesson(.quickHire)
        case .characterMultipliers: .lesson(.upgrades)
        case .elevatorPanel: .lesson(.elevator)
        case .elevatorKeypad: .lesson(.elevatorKeypad)
        case .skins: .lesson(.skins)
        case .achievements: .lesson(.achievements)
        case .oroUpgrades: .lesson(.oroUpgrades)
        case .dailyGifts: .lesson(.gifts)
        case .store: .lesson(.store)
        case .prestigeAndOro: .lesson(.prestige)
        case .share: .lesson(.share)
        case .visitor: .lesson(.visitor)
        case .eventChip: .lesson(.eventChip)
        case .album: .lesson(.album)
        case .customsPackage: .lesson(.packages)
        case .mattress: .lesson(.mattress)
        case .wheel: .lesson(.wheel)
        case .sideRail: .lesson(.sideRail)
        case .mergeAll: .lesson(.mergeAllVideo)
        case .offlineDoubling: .inline(.offline)
        case .career: .inline(.career)
        case .visitorPopup: .inline(.visitorPopup)
        case .notificationsPermission: .selfExplained(NotificationPermissionCard.lessonID)
        case .adBreak: .selfExplained(Self.adBreakIntroID)
        case .passiveIncome: .lesson(.passive)
        case .orgChart: .lesson(.orgChart)
        case .floorSwipe: .lesson(.floorSwipe)
        case .floorFull: .lesson(.floorFull)
        case .characterSheet: .lesson(.characterSheet)
        case .staffedFloors: .lesson(.staffedFloors)
        case .prestigeGate: .lesson(.prestigeGate)
        case .boosts: .lesson(.boosts)
        case .chests: .lesson(.chests)
        case .menuSwipe: .lesson(.menuSwipe)
        case .newTabs: .lesson(.newTabs)
        case .hirePriceStep: .lesson(.hirePriceStep)
        case .oroShopShelf: .lesson(.oroShop)
        case .pendingTriple: .lesson(.pendingTriple)
        case .autoTap: .lesson(.autoTap)
        case .luckOdds: .lesson(.luck)
        case .offers: .lesson(.offers)
        case .cosmetics: .lesson(.cosmetics)
        case .extraSlots: .lesson(.extraSlots)
        case .skinEffects: .gap
        }
    }

    /// Lo que todavía no tiene lección, con la razón de cada uno. Un caso que gana lección sin
    /// salir de acá (o al revés) pone el test en rojo.
    static let gapReasons: [TutorialMechanic: String] = [
        .skinEffects: "la mecánica no existe: el dueño dijo que no a las skins por código y E6b T1r borró los efectos",
    ]
    static var knownGaps: Set<TutorialMechanic> { Set(gapReasons.keys) }
    /// El techo de hoy: un hueco nuevo sin lección pone el test en rojo.
    static let knownGapsCeiling = 1

    /// El id con el que la pantalla previa de la pausa publicitaria se publica.
    static let adBreakIntroID = "adbreak.intro"
    static let selfExplaining: Set<String> = [NotificationPermissionCard.lessonID, adBreakIntroID]

    /// Anclas que se publican con una variable (`.tutorialAnchor(kind.tutorialTarget)`) y no
    /// con el literal: las de la columna de E7b-b.
    static let dynamicAnchors: Set<TutorialTarget> = [.sideRail, .sideWheel, .sideMattress, .sidePackages, .sideBoost]

    static var allCurriculumSteps: [TutorialStep] {
        TutorialCurriculum.core
            + GameState.TutorialLesson.allCases.flatMap(\.steps)
            + TutorialInlineLesson.allCases.flatMap(\.steps)
    }
}
