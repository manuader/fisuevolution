import Foundation

/// El camino v2 del valor por jugador (2.1 E15 F6): el mismo `evaluate`, con un modelo de árboles
/// opcional. Cualquier cosa que impida usar el modelo cae a las reglas de F1, idénticas.
extension PlayerValue {
    /// Con modelo: el score es el percentil de su predicción contra `tables.modelThresholds`, y el
    /// segmento sale de ese score con los mismos umbrales, histéresis y tope de un escalón que las
    /// reglas. `expectedMicrosPerVideo` sigue siendo el de las reglas: el modelo predice el ingreso de
    /// los días 8–37 (la etiqueta de `train.py`), no lo que paga un video.
    ///
    /// Sin modelo, sin `modelThresholds` válidos, con una feature que el modelo pide y no existe o con
    /// una predicción no finita: `evaluate(_:tables:previous:)` tal cual.
    public static func evaluate(
        _ inputs: PlayerValueInputs,
        tables: PlayerValueTables,
        model: TreeEnsemble?,
        previous: PlayerSegment?
    ) -> PlayerValueEstimate {
        guard let model, let score = modelScore(inputs, tables: tables, model: model) else {
            return evaluate(inputs, tables: tables, previous: previous)
        }
        return PlayerValueEstimate(
            segment: segment(forScore: score, tables: tables, previous: previous),
            expectedMicrosPerVideo: expectedMicrosPerVideo(inputs, tables: tables),
            score: score,
            tablesVersion: tables.version,
            source: .model
        )
    }

    /// El percentil (0…1) de la predicción del modelo, o `nil` si el modelo no se puede usar.
    public static func modelScore(_ inputs: PlayerValueInputs, tables: PlayerValueTables, model: TreeEnsemble) -> Double? {
        guard let thresholds = tables.modelThresholds, areUsable(thresholds) else { return nil }
        let features = PlayerValueFeatures.features(from: inputs, tables: tables)
        guard let vector = PlayerValueFeatures.vector(for: model, from: features) else { return nil }
        let prediction = model.predict(vector)
        guard prediction.isFinite else { return nil }
        return percentile(prediction, among: thresholds)
    }

    /// La fracción de cuantiles que la predicción alcanza: por debajo del primero, 0; desde el último, 1.
    public static func percentile(_ value: Double, among thresholds: [Double]) -> Double {
        guard !thresholds.isEmpty else { return 0 }
        let reached = thresholds.prefix { $0 <= value }.count
        return Double(reached) / Double(thresholds.count)
    }

    /// No vacíos, finitos y no decrecientes.
    static func areUsable(_ thresholds: [Double]) -> Bool {
        guard !thresholds.isEmpty, thresholds.allSatisfy(\.isFinite) else { return false }
        return zip(thresholds, thresholds.dropFirst()).allSatisfy { $0 <= $1 }
    }
}
