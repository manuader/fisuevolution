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

    /// La medición que decide la ruta de T9: ¿el `SKVideoNode` respeta el alfa del HEVC?
    /// Se renderiza la escena sobre rojo y se lee un píxel de la esquina del retrato.
    @Test("el alfa del HEVC sobrevive en SKVideoNode")
    func alphaSurvivesInSKVideoNode() async throws {
        let pool = VideoPlayerPool(policy: .allowAll)
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 256, height: 256))
        let scene = SKScene(size: view.frame.size)
        scene.backgroundColor = .red
        scene.scaleMode = .resizeFill
        view.presentScene(scene)
        let clear = SKTexture(image: UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).image { _ in })
        let node = LoopingVideoNode(clip: .portrait("npc_vecina"), poster: clear,
                                    size: view.frame.size, role: .popup, manifest: .main, pool: pool)
        node.position = CGPoint(x: 128, y: 128)
        scene.addChild(node)
        node.setVisible(true)
        try await node.waitUntilVisible(timeout: .seconds(8))
        try await Task.sleep(for: .milliseconds(500))
        let texture = try #require(view.texture(from: scene))
        let image = texture.cgImage()
        let pixel = Self.pixel(of: image, x: 2, y: 2)
        print("MEDICION_ALFA corner=\(pixel)")
        #expect(pixel.red > 200 && pixel.green < 60 && pixel.blue < 60, "esquina \(pixel): si es negra, el alfa no pasa")
        node.setVisible(false)
    }

    private static func pixel(of image: CGImage, x: Int, y: Int) -> (red: Int, green: Int, blue: Int, alpha: Int) {
        var data = [UInt8](repeating: 0, count: 4)
        let context = CGContext(data: &data, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        context?.draw(image, in: CGRect(x: -x, y: -(image.height - 1 - y), width: image.width, height: image.height))
        return (Int(data[0]), Int(data[1]), Int(data[2]), Int(data[3]))
    }
}
