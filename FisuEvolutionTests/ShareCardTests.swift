import EconomyKit
import Foundation
import SwiftUI
import Testing
import UIKit
@testable import FisuEvolution

/// La imagen que se comparte y la card del personaje nuevo (E14 C23, C24).
@Suite("Compartir: la card y la imagen del personaje", .serialized)
@MainActor
struct ShareCardTests {
    private func makeGameState() async -> GameState {
        let repository = PlayerStateRepository(
            persistence: PersistenceController(inMemory: true),
            snapshotURL: FileManager.default.temporaryDirectory.appending(path: "sharecard-\(UUID().uuidString).json")
        )
        let gameState = GameState(repository: repository)
        await gameState.bootstrap()
        gameState.shareOffersEnabled = true
        return gameState
    }

    private func type(tier: Int, in gameState: GameState) throws -> CharacterType {
        try #require(gameState.content?.tiers.concreteTypes.first { $0.tier == tier })
    }

    /// Un retrato de prueba de un color que ningún otro elemento de la card usa.
    private func sentinelPortrait() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 200, height: 200)).image { context in
            UIColor(red: 1, green: 0, blue: 1, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 200, height: 200))
        }
    }

    /// Cuántos píxeles de la imagen son (casi) el magenta del retrato de prueba.
    private func sentinelPixels(in image: UIImage) -> Int {
        guard let cgImage = image.cgImage else { return 0 }
        let width = cgImage.width, height = cgImage.height
        var data = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &data, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return 0 }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        var count = 0
        for index in stride(from: 0, to: data.count, by: 4)
        where data[index] > 230 && data[index + 1] < 40 && data[index + 2] > 230 {
            count += 1
        }
        return count
    }

    private func moments(in gameState: GameState) throws -> [ShareMoment] {
        let character = try type(tier: 4, in: gameState)
        let god = try type(tier: gameState.content?.tiers.maxTier ?? 1, in: gameState)
        return [
            .newCharacter(character),
            .newFloor(floorID: try #require(gameState.content?.floorTable[1].id)),
            .reincarnation(level: 2),
            .god(god),
        ]
    }

    // MARK: La imagen

    @Test("la imagen de cada momento sale entera y lleva el retrato del personaje")
    func theRenderCarriesThePortrait() async throws {
        let gameState = await makeGameState()
        for moment in try moments(in: gameState) {
            let image = ShareCardRenderer.render(moment, artwork: ShareArtwork(portrait: sentinelPortrait()))
            #expect(image.size == CGSize(width: 540, height: 960), "\(moment.key)")
            #expect(image.cgImage?.width == 1080, "\(moment.key): 1080×1920")
            #expect(sentinelPixels(in: image) > 20_000, "\(moment.key): el retrato tiene que verse grande")
        }
    }

    @Test("sin retrato cargado, la imagen no queda vacía ni dibuja nada de más: el respaldo es el de la casa")
    func withoutThePortraitTheHouseFallbackDraws() async throws {
        let gameState = await makeGameState()
        for moment in try moments(in: gameState) {
            let image = ShareCardRenderer.render(moment, artwork: .empty)
            #expect(image.cgImage != nil, "\(moment.key)")
            #expect(sentinelPixels(in: image) == 0, "\(moment.key)")
        }
    }

    @Test("el arte real: cada momento trae el personaje y el piso donde vive")
    func theRealArtIsLoaded() async throws {
        let gameState = await makeGameState()
        for moment in try moments(in: gameState) {
            let art = ShareArt.artwork(for: moment, in: gameState)
            #expect(art.portrait != nil, "\(moment.key): sin el personaje")
            #expect(art.background != nil, "\(moment.key): sin el fondo del piso")
        }
    }

    @Test("el retrato lleva la skin que el jugador tiene puesta")
    func thePortraitWearsTheActiveSkin() async throws {
        let gameState = await makeGameState()
        let content = try #require(gameState.content)
        let character = try type(tier: 4, in: gameState)
        let skin = try #require(content.skins.entries(forCharacterType: character.id).first { entry in
            entry.treatment == .texture && entry.textureKey != nil
                && ShareArt.portrait(of: character, in: gameState) != nil
        })
        let base = try #require(ShareArt.portrait(of: character, in: gameState)?.image)
        gameState.player?.meta.activeSkinByType[character.id] = skin.id
        let dressed = try #require(ShareArt.portrait(of: character, in: gameState)?.image)
        #expect(base.pngData() != dressed.pngData(), "con la skin puesta, la imagen es otra")
    }

    // MARK: La card del personaje nuevo

    @Test("un personaje nuevo abre su card cuando le toca el turno, después de la celebración del tablero")
    func theCardWaitsForTheBoardCelebration() async throws {
        let gameState = await makeGameState()
        let character = try type(tier: 4, in: gameState)
        gameState.celebrate(.boardCelebration)
        gameState.queueNewCharacterCard(.newCharacter(character))
        #expect(gameState.showing == .boardCelebration, "el reveal del tablero va primero")
        #expect(gameState.newCharacterCard == .newCharacter(character))
        gameState.celebrationFinished(.boardCelebration)
        #expect(gameState.showing == .newCharacter)
        #expect(!gameState.isCalmMoment, "mientras está abierta, nada se suma encima")
    }

    @Test("«Seguir» cierra la card sin bonus y el juego sigue")
    func continueClosesWithoutBonus() async throws {
        let gameState = await makeGameState()
        let character = try type(tier: 4, in: gameState)
        let coins = try #require(gameState.player?.run.coins)
        gameState.queueNewCharacterCard(.newCharacter(character))
        #expect(gameState.showing == .newCharacter)
        gameState.finishNewCharacterCard(shared: false)
        #expect(gameState.showing == nil)
        #expect(gameState.newCharacterCard == nil)
        #expect(gameState.player?.run.coins == coins, "sin compartir no hay bonus")
        #expect(gameState.player?.meta.sharesCompleted == 0)
    }

    @Test("compartir completado cobra el bonus una sola vez y el juego sigue")
    func sharingPaysOnce() async throws {
        let gameState = await makeGameState()
        let character = try type(tier: 4, in: gameState)
        let coins0 = try #require(gameState.player?.run.coins)
        gameState.queueNewCharacterCard(.newCharacter(character))
        gameState.finishNewCharacterCard(shared: true)
        let coins1 = try #require(gameState.player?.run.coins)
        #expect(coins1 > coins0)
        #expect(gameState.showing != .newCharacter, "el juego sigue (a lo sumo, el logro de compartir)")
        #expect(gameState.newCharacterCard == nil)
        #expect(gameState.player?.meta.engagement.sharedMoments.contains("character.\(character.id)") == true)
        gameState.finishNewCharacterCard(shared: true)
        #expect(gameState.player?.run.coins == coins1, "no hay una segunda card que cobrar")
        gameState.queueNewCharacterCard(.newCharacter(character))
        #expect(gameState.newCharacterCard == nil, "lo ya compartido no vuelve a abrir la card")
    }

    @Test("los primeros personajes del tutorial traen la card sin compartir; del cuarto en adelante, con")
    func theTutorialCharactersCannotShare() async throws {
        let gameState = await makeGameState()
        for tier in 1...GameState.tutorialTierCeiling {
            #expect(!gameState.newCharacterCardCanShare(.newCharacter(try type(tier: tier, in: gameState))), "T\(tier)")
        }
        #expect(gameState.newCharacterCardCanShare(.newCharacter(try type(tier: 4, in: gameState))))
        let god = try type(tier: gameState.content?.tiers.maxTier ?? 1, in: gameState)
        #expect(gameState.newCharacterCardCanShare(.god(god)), "Dios siempre comparte")
    }

    @Test("el núcleo del tutorial no abre la card, ni apagado el compartir")
    func noCardDuringTheCoreOrWhenDisabled() async throws {
        let gameState = await makeGameState()
        let character = try type(tier: 4, in: gameState)
        gameState.tutorialPhaseActive = true
        gameState.queueNewCharacterCard(.newCharacter(character))
        #expect(gameState.newCharacterCard == nil)
        gameState.tutorialPhaseActive = false
        gameState.shareOffersEnabled = false
        gameState.queueNewCharacterCard(.newCharacter(character))
        #expect(gameState.newCharacterCard == nil)
        #expect(gameState.showing == nil)
    }

    @Test("el reveal de un tier abre la card del personaje; el de Dios, la de Dios")
    func revealingATierOpensTheCard() async throws {
        let gameState = await makeGameState()
        gameState.noteRevealedTier(4)
        guard case .newCharacter(let revealed) = gameState.newCharacterCard else {
            Issue.record("el tier 4 no abrió la card de personaje")
            return
        }
        #expect(revealed.tier == 4)
        gameState.finishNewCharacterCard(shared: false)
        gameState.noteRevealedTier(gameState.content?.tiers.maxTier ?? 1)
        guard case .god = gameState.newCharacterCard else {
            Issue.record("el tier de Dios no abrió la card de Dios")
            return
        }
    }

    @Test("el watchdog destraba la card si nadie la cierra, sin cobrar nada")
    func theWatchdogReleasesTheCard() async throws {
        let gameState = await makeGameState()
        let character = try type(tier: 4, in: gameState)
        let coins = try #require(gameState.player?.run.coins)
        gameState.queueNewCharacterCard(.newCharacter(character))
        #expect(gameState.showing == .newCharacter)
        gameState.advanceCelebrations(delta: (CelebrationKind.newCharacter.timeout ?? 0) + 1)
        #expect(gameState.showing == nil)
        #expect(gameState.newCharacterCard == nil)
        #expect(gameState.player?.run.coins == coins)
    }

    @Test("piso nuevo y reencarnación siguen con la oferta chica, no con la card")
    func floorsAndReincarnationKeepTheChip() async throws {
        let gameState = await makeGameState()
        gameState.queueShareMoment(.reincarnation(level: 1))
        gameState.refreshProjections()
        #expect(gameState.shareOffer == .reincarnation(level: 1))
        #expect(gameState.newCharacterCard == nil)
    }
}
