import Foundation

/// Pure board mutations. The scene renders these results; it never owns state.
public enum BoardActions {
    /// Moves a unit to an empty cell. Returns false (no mutation) if the source
    /// is empty or the target is occupied.
    @discardableResult
    public static func moveUnit(fromCell source: Int, toCell target: Int, state: inout PlayerState) -> Bool {
        guard source != target,
              let sourceIndex = state.board.firstIndex(where: { $0.cellIndex == source }),
              !state.board.contains(where: { $0.cellIndex == target })
        else { return false }

        let typeId = state.board[sourceIndex].typeId
        state.board[sourceIndex] = BoardPlacement(cellIndex: target, typeId: typeId)
        return true
    }

    /// Removes the unit at `cell` (frees the slot). Returns false if the cell was
    /// already empty. Usado por "dejar de contratar" para destrabar tiers bajos.
    @discardableResult
    public static func removeUnit(atCell cell: Int, state: inout PlayerState) -> Bool {
        guard let index = state.board.firstIndex(where: { $0.cellIndex == cell }) else { return false }
        state.board.remove(at: index)
        return true
    }

    /// Consumes source + target and leaves one `newTypeId` unit on the target cell.
    /// Also advances `maxTierReached` (input to progressive spawn and backgrounds).
    public static func applyMerge(
        sourceCell: Int,
        targetCell: Int,
        newTypeId: String,
        state: inout PlayerState,
        tiers: TierRepository
    ) {
        state.board.removeAll { $0.cellIndex == sourceCell }
        guard let targetIndex = state.board.firstIndex(where: { $0.cellIndex == targetCell }) else { return }
        state.board[targetIndex] = BoardPlacement(cellIndex: targetCell, typeId: newTypeId)
        if let newType = tiers.type(id: newTypeId) {
            state.maxTierReached = max(state.maxTierReached, newType.tier)
        }
    }
}
