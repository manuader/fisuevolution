import EconomyKit
import Foundation
import SwiftUI

extension GameState {
    /// La llaman los seis dominios: toda mutación persistible pasa por acá.
    func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            await self?.persistNow()
        }
    }

    func persistNow(includingCloud: Bool = true) async {
        guard !isRecoveryPending, let repository, let player else { return }
        await repository.save(player)
        if includingCloud, let cloudSync {
            await cloudSync.push(player)
        }
    }
}
