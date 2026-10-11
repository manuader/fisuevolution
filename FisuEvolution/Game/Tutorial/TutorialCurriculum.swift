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
