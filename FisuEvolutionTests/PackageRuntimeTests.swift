import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("Paquete de la Aduana en la partida")
@MainActor
struct PackageRuntimeTests {
    private func playing() async -> GameState {
        let gameState = await makeGameState()
        gameState.engagementAutorun = true
        return gameState
    }

    @Test("bajo XCTest no cae nada solo")
    func autorunIsOffUnderTests() async {
        let gameState = await makeGameState()
        #expect(!gameState.engagementAutorun)
        gameState.player?.meta.engagement.packages.secondsUntilNext = 0.5
        gameState.advanceEngagement(delta: 1)
        #expect(gameState.packagesWaiting == 0)
    }

    @Test("con el juego andando, cae uno cuando vence el reloj")
    func aPackageDrops() async {
        let gameState = await playing()
        gameState.player?.meta.engagement.packages.secondsUntilNext = 0.5
        gameState.advanceEngagement(delta: 1)
        #expect(gameState.packagesWaiting == 1)
    }

    @Test("durante la fase obligatoria del tutorial no nace ninguno")
    func noPackagesDuringTheTutorialCore() async {
        let gameState = await playing()
        gameState.beginTutorialPhase()
        gameState.player?.meta.engagement.packages.secondsUntilNext = 0.5
        gameState.advanceEngagement(delta: 1)
        #expect(gameState.packagesWaiting == 0)
    }

    @Test("el Piquete frena el reloj y la Lluvia lo corre ×10")
    func eventsMoveTheClock() async {
        let gameState = await playing()
        let now = Date().timeIntervalSince1970
        gameState.player?.meta.engagement.packages.secondsUntilNext = 10
        gameState.player?.run.activeModifiers = [
            ActiveModifier(effect: .packageRateMultiplier, magnitude: 0, expiresAt: now + 90, sourceKey: "event.piquete"),
        ]
        gameState.advanceEngagement(delta: 2)
        #expect(gameState.player?.meta.engagement.packages.secondsUntilNext == 10)
        gameState.player?.run.activeModifiers = [
            ActiveModifier(effect: .packageRateMultiplier, magnitude: 10, expiresAt: now + 60, sourceKey: "event.lluvia_paquetes"),
        ]
        gameState.advanceEngagement(delta: 1)
        #expect(gameState.packagesWaiting == 1)
    }

    @Test("lo que el paquete puede traer es exactamente lo que FisuJobs vende con lugar")
    func candidatesMatchFisuJobs() async {
        let gameState = await makeGameState()
        gameState.debugUnlockFloors(throughTier: 12)
        gameState.debugMarkTypesSeen(throughTier: 12)
        let hirable = Set(gameState.jobRows.filter { $0.state == .hirable }.map(\.id))
        #expect(hirable.count > 1)
        #expect(Set(gameState.packageCandidates.map(\.id)) == hirable)
    }

    @Test("abrir uno sortea entre los candidatos y deja la llegada en el embudo")
    func openingPlansAnArrival() async throws {
        let gameState = await makeGameState()
        gameState.debugAddPackages(1)
        let candidates = Set(gameState.packageCandidates.map(\.id))
        guard case .opened(let typeId) = gameState.openPackage() else {
            Issue.record("el paquete no se abrió")
            return
        }
        #expect(candidates.contains(typeId))
        #expect(gameState.packagesWaiting == 0)
        let change = try #require(gameState.pendingBoardChanges.last)
        #expect(change.origin == .package)
        #expect(change.kind == .arrival(typeId: typeId))
    }

    @Test("llegar es colocar: no cuenta como contratación")
    func arrivingIsNotHiring() async throws {
        let gameState = await makeGameState()
        gameState.debugAddPackages(1)
        let before = try #require(gameState.player)
        _ = gameState.openPackage()
        let change = try #require(gameState.beginNextBoardChange())
        gameState.confirmBoardChange(id: change.id)
        let after = try #require(gameState.player)
        #expect(after.run.totalUnits == before.run.totalUnits + 1)
        #expect(after.run.hireCounts == before.run.hireCounts)
        #expect(after.run.hireCountsByType == before.run.hireCountsByType)
        #expect(after.meta.stats.totalHiresEver == before.meta.stats.totalHiresEver)
    }

    @Test("sin lugar dice LLENO y el paquete no se gasta")
    func aFullTowerKeepsThePackage() async throws {
        let gameState = await makeGameState()
        let base = try #require(gameState.content?.tiers.baseType.id)
        let capacity = try #require(gameState.tower?.floors.first?.def.capacity)
        gameState.player?.run.units = [base: capacity]
        gameState.reconcileTower()
        gameState.debugAddPackages(1)
        #expect(gameState.packagesBlocked)
        #expect(gameState.openPackage() == .full)
        #expect(gameState.packagesWaiting == 1)
        #expect(gameState.pendingBoardChanges.isEmpty)
    }

    @Test("sin paquetes esperando, abrir no hace nada")
    func nothingToOpen() async {
        let gameState = await makeGameState()
        #expect(gameState.openPackage() == .noneWaiting)
        #expect(gameState.pendingBoardChanges.isEmpty)
    }

    @Test("si al llegar su turno ya no entra, el paquete vuelve al buzón")
    func aStaleArrivalGivesThePackageBack() async throws {
        let gameState = await makeGameState()
        gameState.debugAddPackages(1)
        _ = gameState.openPackage()
        let change = try #require(gameState.pendingBoardChanges.last)
        gameState.discardBoardChange(change)
        #expect(gameState.packagesWaiting == 1)
    }

    @Test("descartar un paquete devuelve el paquete y no compensa ningún video")
    func discardingDoesNotCompensateVideos() async throws {
        let gameState = await makeGameState()
        gameState.debugAddPackages(1)
        _ = gameState.openPackage()
        let change = try #require(gameState.pendingBoardChanges.last)
        let coinsBefore = gameState.player?.run.coins
        gameState.discardBoardChange(change)
        #expect(gameState.player?.run.coins == coinsBefore)
        #expect(gameState.towerNotice == nil)
    }

    @Test("el paquete abierto es prepago: al pasar a inactivo se asienta y no se pierde con un kill")
    func anOpenedPackageIsPrepaid() async throws {
        let gameState = await makeGameState()
        gameState.debugAddPackages(1)
        let before = try #require(gameState.player).run.totalUnits
        _ = gameState.openPackage()
        gameState.settlePrepaidBoardChanges()
        #expect(gameState.pendingBoardChanges.isEmpty)
        #expect(gameState.player?.run.totalUnits == before + 1)
    }

    @Test("uno regalado entra aunque haya dos esperando")
    func grantedPackagesSkipTheCap() async {
        let gameState = await makeGameState()
        gameState.debugAddPackages(2)
        gameState.grant(.package(1), source: "visit.puntero_bolson")
        #expect(gameState.packagesWaiting == 3)
    }
}
