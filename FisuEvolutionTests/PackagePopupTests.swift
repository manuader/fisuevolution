import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("Paquete de la Aduana: la pantalla (E14 C28)")
@MainActor
struct PackagePopupTests {
    private func midGame() async -> GameState {
        let gameState = await makeGameState()
        gameState.debugUnlockFloors(throughTier: 12)
        gameState.debugMarkTypesSeen(throughTier: 12)
        return gameState
    }

    @Test("«puede venir» es la tabla de PackageRoller: mismos tipos, mismas chances, suman 1")
    func chancesAreTheRollersTable() async throws {
        let gameState = await midGame()
        let content = try #require(gameState.content)
        let ratio = content.packages.tierRatio(bestSupplierLevel: gameState.bestSupplierLevel)
        let table = PackageRoller.typeOdds(
            eligible: gameState.packageCandidates, windowTiers: content.packages.windowTiers, ratio: ratio
        )
        let shown = gameState.packageChances
        #expect(shown.count > 1)
        #expect(shown.map(\.typeId) == table.map(\.typeId))
        #expect(shown.map(\.probability) == table.map(\.probability))
        #expect(abs(shown.map(\.probability).reduce(0, +) - 1) < 1e-9)
        #expect(shown.allSatisfy { $0.faceKey == "\($0.typeId)_face" && !$0.name.isEmpty })
    }

    @Test("el que sale es uno de los que se muestran")
    func theOpenedOneWasShown() async throws {
        let gameState = await midGame()
        gameState.debugAddPackages(1)
        gameState.packageTapped()
        let shown = Set(gameState.packageChances.map(\.typeId))
        gameState.openPackageFromPopup()
        let arrival = try #require(gameState.packagePopup?.arrivals.first)
        #expect(shown.contains(arrival.typeId))
    }

    @Test("sin lugar, la pantalla muestra las caras de todos modos y «Abrir» no gasta nada")
    func fullStillShowsFaces() async throws {
        let gameState = await makeGameState()
        let base = try #require(gameState.content?.tiers.baseType.id)
        let capacity = try #require(gameState.tower?.floors.first?.def.capacity)
        gameState.player?.run.units = [base: capacity]
        gameState.reconcileTower()
        gameState.debugAddPackages(1)
        #expect(gameState.packagesBlocked)
        #expect(gameState.packageCandidates.isEmpty)
        #expect(!gameState.packageChances.isEmpty, "la cara del empleado que vendría")
        gameState.packageTapped()
        gameState.openPackageFromPopup()
        #expect(gameState.packagesWaiting == 1)
        #expect(gameState.pendingBoardChanges.isEmpty)
    }

    @Test("la llegada que se anuncia es la que cae: el piso del aviso es el de la llegada")
    func announcedFloorIsTheArrivalFloor() async throws {
        let gameState = await midGame()
        gameState.debugAddPackages(3)
        gameState.packageTapped()
        gameState.openAllPackagesFromPopup()
        let arrivals = try #require(gameState.packagePopup?.arrivals)
        let changes = gameState.pendingBoardChanges.filter { $0.origin == .package }
        #expect(arrivals.count == changes.count)
        for (arrival, change) in zip(arrivals, changes) {
            #expect(change.kind == .arrival(typeId: arrival.typeId))
            let ordinal = try #require(gameState.floorOrdinal(of: change))
            #expect(gameState.content?.floorTable[ordinal].id == arrival.floorId)
        }
    }

    @Test("el que se cierra a medio abrir no pierde al empleado: la llegada ya está encolada")
    func closingMidOpeningKeepsTheArrival() async {
        let gameState = await makeGameState()
        gameState.debugAddPackages(1)
        gameState.packageTapped()
        gameState.openPackageFromPopup()
        gameState.closePackagePopup()
        #expect(gameState.packagePopup == nil)
        #expect(gameState.pendingBoardChanges.filter { $0.origin == .package }.count == 1)
        #expect(gameState.packagesWaiting == 0)
    }

    @Test("ganar un paquete (visitante, Ruleta, evento) lo vuela al sello y avisa; el del reloj, no")
    func winningFliesAndNotifies() async {
        let gameState = await makeGameState()
        gameState.engagementAutorun = true
        gameState.player?.meta.engagement.packages.secondsUntilNext = 0.5
        gameState.advanceEngagement(delta: 1)
        #expect(gameState.packagesWaiting == 1)
        #expect(gameState.packageWin == nil, "el que cae solo no vuela")
        #expect(gameState.towerNotice == nil)
        gameState.grant(.package(1), source: "visit.puntero_bolson")
        #expect(gameState.packagesWaiting == 2)
        #expect(gameState.packageWin?.count == 1)
        #expect(gameState.towerNotice?.kind == .packagesWon(count: 1))
    }

    @Test("tres toques abren la caja, con los clips de C27; con Reduce Motion alcanza uno")
    func threeTapsOpenTheBox() {
        var opening = PackageOpening()
        #expect(opening.clipID == "paquete_espera")
        opening.tap(reduceMotion: false)
        #expect(opening.clipID == "paquete_sacude")
        opening.shakeEnded()
        #expect(opening.clipID == "paquete_espera")
        opening.tap(reduceMotion: false)
        opening.tap(reduceMotion: false)
        #expect(opening.isOpen)
        #expect(opening.clipID == "paquete_abre")
        var calm = PackageOpening()
        calm.tap(reduceMotion: true)
        #expect(calm.isOpen)
    }

    @Test("el arte del paquete es la caja con el empleado sorpresa")
    func packageArtIsTheSurpriseBox() {
        #expect(RewardKind.package.artKeys.first == "rw_package_employee")
        #expect(RewardKind.package.resolvedArtKey == "rw_package_employee")
    }
}
