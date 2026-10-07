import CoreGraphics
import SpriteKit
import Testing
@testable import FisuEvolution

@Suite("Los efectos de skin por código")
@MainActor
struct SkinShadersTests {
    /// 64×64: un margen transparente de 8 y adentro un damero rojo y azul de 4 px.
    /// Tiene borde (Neón, Sombra), color (Arcoíris, Oro) y detalle fino (Pixel).
    private func checker() throws -> SKTexture {
        let side = 64
        let context = try #require(CGContext(
            data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        for y in stride(from: 8, to: side - 8, by: 4) {
            for x in stride(from: 8, to: side - 8, by: 4) {
                let red = (x / 4 + y / 4).isMultiple(of: 2)
                context.setFillColor(red ? CGColor(red: 1, green: 0, blue: 0, alpha: 1) : CGColor(red: 0, green: 0, blue: 1, alpha: 1))
                context.fill(CGRect(x: x, y: y, width: 4, height: 4))
            }
        }
        return SKTexture(cgImage: try #require(context.makeImage()))
    }

    private func pixels(_ image: CGImage) throws -> [UInt8] {
        var buffer = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let context = try #require(CGContext(
            data: &buffer, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return buffer
    }

    @Test("son los 8 candidatos del dueño, en su orden")
    func theEightCandidates() {
        #expect(SkinShaders.ids == ["neon", "holograma", "fantasma", "arcoiris", "glitch", "pixel", "oro_liquido", "sombra"])
    }

    @Test("un shader por efecto, compartido, con su velocidad y sus dos atributos", arguments: SkinShaders.ids)
    func oneSharedShaderPerEffect(id: String) throws {
        let shader = try #require(SkinShaders.shader(for: id))
        #expect(SkinShaders.shader(for: id) === shader, "compartido: los mismos efectos van en la misma tanda")
        #expect(shader.uniformNamed("u_speed") != nil)
        #expect(Set(shader.attributes.map(\.name)) == ["a_phase", "a_rect"])
    }

    @Test("un id desconocido no tiene shader")
    func unknownID() {
        #expect(SkinShaders.shader(for: "jackpot") == nil)
    }

    @Test("aplicar pone el shader y la fase; sin efecto, lo saca")
    func applyAndClear() throws {
        let sprite = SKSpriteNode(texture: try checker())
        SkinShaders.apply("neon", to: sprite, phase: 0.9)
        #expect(sprite.shader === SkinShaders.shader(for: "neon"))
        #expect(sprite.value(forAttributeNamed: "a_phase")?.floatValue == 0.9)
        SkinShaders.apply(nil, to: sprite, phase: 0)
        #expect(sprite.shader == nil)
    }

    @Test("quieto con Reduce Motion o Bajo consumo: la velocidad baja a 0")
    func motionStops() {
        defer { SkinShaders.setAnimated(SkinShaders.systemWantsMotion) }
        SkinShaders.setAnimated(false)
        #expect(SkinShaders.speed == 0)
        SkinShaders.setAnimated(true)
        #expect(SkinShaders.speed == 1)
    }

    @Test("cada efecto compila y cambia el dibujo", arguments: SkinShaders.ids)
    func everyEffectChangesTheDrawing(id: String) throws {
        let texture = try checker()
        let plain = try #require(SkinEffectRenderer.snapshot(of: texture, shaderID: nil, side: 64))
        let shaded = try #require(SkinEffectRenderer.snapshot(of: texture, shaderID: id, side: 64), "\(id) no dibujó")
        let shadedPixels = try pixels(shaded)
        #expect(shadedPixels != (try pixels(plain)), "\(id) dibuja igual que sin efecto: el shader no compiló")
        #expect(stride(from: 3, to: shadedPixels.count, by: 4).contains { shadedPixels[$0] > 0 }, "\(id) quedó transparente")
    }
}
