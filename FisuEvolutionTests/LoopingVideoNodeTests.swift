import SpriteKit
import Testing
import UIKit
@testable import FisuEvolution

@Suite("LoopingVideoNode: el póster en la escena y el video encima")
@MainActor
struct LoopingVideoNodeTests {
    private let size = CGSize(width: 100, height: 100)

    @Test("sin entrada: sólo el póster, nunca un SKVideoNode")
    func noEntryOnlyPoster() {
        let pool = VideoPlayerPool(policy: .allowAll)
        let node = LoopingVideoNode(clip: .floor("no_existe"), poster: SKTexture(), size: size,
                                    role: .background, manifest: .main, pool: pool)
        node.setVisible(true)
        #expect(node.videoNode == nil && pool.liveCount == 0)
    }

    @Test("visible y vivo: hay video; invisible: lo suelta y el cupo vuelve")
    func visibilityDrivesTheLease() throws {
        let pool = VideoPlayerPool(policy: .allowAll)
        let manifest = try LoopsManifestTests.fixture(floors: ["urban": "cine_arresto.mov"])
        let node = LoopingVideoNode(clip: .floor("urban"), poster: SKTexture(), size: size,
                                    role: .background, manifest: manifest, pool: pool)
        #expect(node.videoNode == nil, "el init no decodifica")
        node.setVisible(true)
        #expect(node.videoNode != nil && pool.liveCount == 1)
        node.setVisible(false)
        #expect(node.videoNode == nil && pool.liveCount == 0)
    }

    @Test("con la política apagada, póster aunque esté visible")
    func stillPolicy() throws {
        let pool = VideoPlayerPool(policy: .allowAll.with(.lowPower))
        let manifest = try LoopsManifestTests.fixture(floors: ["urban": "cine_arresto.mov"])
        let node = LoopingVideoNode(clip: .floor("urban"), poster: SKTexture(), size: size,
                                    role: .background, manifest: manifest, pool: pool)
        node.setVisible(true)
        #expect(node.videoNode == nil)
    }

    @Test("una suspensión del pool baja el video y al reanudar vuelve")
    func suspensionDropsTheVideo() throws {
        let pool = VideoPlayerPool(policy: .allowAll)
        let manifest = try LoopsManifestTests.fixture(floors: ["urban": "cine_arresto.mov"])
        let node = LoopingVideoNode(clip: .floor("urban"), poster: SKTexture(), size: size,
                                    role: .background, manifest: manifest, pool: pool)
        node.setVisible(true)
        let suspension = pool.suspend(.overlay)
        #expect(node.videoNode == nil)
        pool.resume(suspension)
        #expect(node.videoNode != nil)
        node.setVisible(false)
    }

    private func render(clip: ArtClip, manifest: LoopsManifest) async throws -> (corner: Pixel, center: Pixel) {
        let pool = VideoPlayerPool(policy: .allowAll)
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 256, height: 256))
        let scene = SKScene(size: view.frame.size)
        scene.backgroundColor = .red
        scene.scaleMode = .resizeFill
        view.presentScene(scene)
        let clear = SKTexture(image: UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).image { _ in })
        let node = LoopingVideoNode(clip: clip, poster: clear, size: view.frame.size,
                                    role: .popup, manifest: manifest, pool: pool)
        node.position = CGPoint(x: 128, y: 128)
        scene.addChild(node)
        node.setVisible(true)
        try await node.waitUntilVisible(timeout: .seconds(8))
        try await Task.sleep(for: .milliseconds(500))
        let image = view.texture(from: scene)!.cgImage()
        node.setVisible(false)
        return (Self.pixel(of: image, x: 2, y: 2), Self.pixel(of: image, x: 128, y: 128))
    }

    /// La medición que decide la ruta de T9: ¿el `SKVideoNode` respeta el alfa del HEVC? Sobre
    /// fondo rojo: la esquina transparente del retrato deja ver el rojo y el centro lo tapa.
    @Test("el alfa del HEVC sobrevive en SKVideoNode")
    func alphaSurvivesInSKVideoNode() async throws {
        let result = try await render(clip: .portrait("npc_vecina"), manifest: .main)
        print("MEDICION_ALFA corner=\(result.corner) center=\(result.center)")
        #expect(result.corner.isRed, "esquina \(result.corner): si es negra, el alfa no pasa")
        #expect(!result.center.isRed, "centro \(result.center): el retrato tiene que tapar el fondo")
    }

    @Test("control: un video opaco tapa el fondo rojo también en la esquina")
    func opaqueVideoCoversTheBackground() async throws {
        let manifest = try LoopsManifestTests.fixture(floors: ["urban": "cine_arresto.mov"])
        let result = try await render(clip: .floor("urban"), manifest: manifest)
        print("MEDICION_CONTROL corner=\(result.corner) center=\(result.center)")
        #expect(!result.corner.isRed && !result.center.isRed)
    }

    @Test("un archivo que no es video: tras el tope queda el póster y el cupo vuelve")
    func giveUpReleasesEverything() async throws {
        let pool = VideoPlayerPool(policy: .allowAll)
        let manifest = try LoopsManifestTests.fixture(floors: ["urban": "loops_manifest.json"])
        let node = LoopingVideoNode(clip: .floor("urban"), poster: SKTexture(), size: size,
                                    role: .background, manifest: manifest, pool: pool)
        node.setVisible(true)
        for _ in 0..<80 where node.videoNode != nil { try await Task.sleep(for: .milliseconds(50)) }
        #expect(node.videoNode == nil && pool.liveCount == 0)
        node.setVisible(true)
        #expect(node.videoNode == nil, "tras abandonar no reabre hasta un stop explícito")
        node.stop()
    }

    struct Pixel: CustomStringConvertible {
        let red: Int, green: Int, blue: Int, alpha: Int
        var isRed: Bool { red > 200 && green < 60 && blue < 60 }
        var description: String { "(\(red),\(green),\(blue),\(alpha))" }
    }

    private static func pixel(of image: CGImage, x: Int, y: Int) -> Pixel {
        var data = [UInt8](repeating: 0, count: 4)
        let context = CGContext(data: &data, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        context?.draw(image, in: CGRect(x: -x, y: -(image.height - 1 - y), width: image.width, height: image.height))
        return Pixel(red: Int(data[0]), green: Int(data[1]), blue: Int(data[2]), alpha: Int(data[3]))
    }
}
