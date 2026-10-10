import Foundation

extension WheelConfig {
    /// La misma ruleta con `bonus` giros por video de más por día (el "abono a
    /// la ruleta" de la tienda de ORO). Todo lo demás, igual.
    public func withBonusVideoSpins(_ bonus: Int) -> WheelConfig {
        guard bonus > 0 else { return self }
        return WheelConfig(
            schemaVersion: schemaVersion,
            videoSpinsPerDay: videoSpinsPerDay + bonus,
            oroSpinCost: oroSpinCost,
            oroSpinsPerDay: oroSpinsPerDay,
            spinSeconds: spinSeconds,
            chestFallbackSegmentId: chestFallbackSegmentId,
            segments: segments
        )
    }
}
