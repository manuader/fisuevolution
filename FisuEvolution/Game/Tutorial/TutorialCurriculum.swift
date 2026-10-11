import Foundation

/// El currículo del tutorial v2 (PLAN-v2 E9). El núcleo va acá; las lecciones, en su
/// `TutorialLesson.steps`; el Tour, en E9b.
enum TutorialCurriculum {
    /// Tocar → contratar → fusionar → cierre, 2-3 minutos, y termina justo después del reveal
    /// del primer merge (que se reproduce limpio: con una celebración en pantalla el overlay
    /// entero se esconde). Secuencial, con scrim; el cierre entrega el cofre de bienvenida.
    /// Los textos son los del núcleo de la v1.
    ///
    /// ⚠️ El paso de contratar ilumina el tab que abre FisuJobs, no un botón que compra: la
    /// hoja se presenta por encima del overlay, la guía sigue adentro (su banda del tutorial)
    /// y `hireCharacter` marca `ftue.spawned`, así que al cerrarse la hoja ya está en "fusioná".
    ///
    /// ⚠️ Poses: sólo `wave` y `celebrate` (las otras salieron del atlas).
    static let core: [TutorialStep] = [
        .act("core.tap", .coreTappedAndAffordable, text: "tutorial.step.tap", on: .boardUnit,
             windows: [.coins], boardTarget: .anyUnit),
        .act("core.hire", .coreHired, text: "tutorial.step.hire", on: .hire, windows: [.coins]),
        // Enseña los DOS gestos de fusión y se completa con cualquiera: después de contratar
        // hay un solo par mergeable, así que no pueden ser dos pasos.
        .act("core.merge", .coreMerged, text: "tutorial.step.merge", on: .boardUnit, boardTarget: .mergePair),
        .explain("core.finish", text: "tutorial.step.finish", pose: "fisura_celebrate"),
    ]
}
