import Foundation

/// Dos personajes que cambian de lugar en la escalera (E14 C17: el Empleado de
/// Fast Food pasa al tier 7 y el Chofer de App al 8).
///
/// La economía es de la escalera y no del personaje: el jugador que tenía tres
/// del tier 7 sigue teniendo tres del tier 7, ahora con la cara del otro. Por eso
/// se remapea **por posición** todo lo que vale por el lugar —unidades, pasivos,
/// contrataciones por tipo, mejoras por personaje, vistos y el atajo fijado—, y
/// queda como está lo que es del personaje: sus pintas (propias y la activa).
/// Lo que se guarda por piso (`hireCounts`, `unlockedFloors`) o por número de
/// tier (`maxTierReached`, `revealedTier`) no se entera.
///
/// Es una involución: aplicada dos veces deshace el cambio. Que corra una sola
/// vez lo garantiza el migrador, que la aplica al subir de versión y estampa la
/// nueva.
extension PlayerState {
    public func swappingTierPositions(of first: String, and second: String) -> PlayerState {
        let swap = { (id: String) -> String in
            switch id {
            case first: second
            case second: first
            default: id
            }
        }
        var result = self
        result.run.units = Self.rekey(run.units, swap)
        result.run.passiveUnlocked = Self.rekey(run.passiveUnlocked, swap)
        result.run.hireCountsByType = Self.rekey(run.hireCountsByType, swap)
        result.run.charUpgradeLevels = Self.rekey(run.charUpgradeLevels, swap)
        result.run.seenTypes = Set(run.seenTypes.map(swap))
        result.meta.quickHirePinnedTypeId = meta.quickHirePinnedTypeId.map(swap)
        return result
    }

    private static func rekey<Value>(_ values: [String: Value], _ swap: (String) -> String) -> [String: Value] {
        Dictionary(uniqueKeysWithValues: values.map { (swap($0.key), $0.value) })
    }
}
