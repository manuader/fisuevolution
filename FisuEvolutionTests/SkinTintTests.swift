import CoreImage
import Testing
@testable import FisuEvolution

@Suite("Tinte de pintas recoloreo: cartonero__oro reusa el clip base")
@MainActor
struct SkinTintTests {
    private func manifest(_ keys: [String]) throws -> LoopsManifest {
        let entries = keys.map { #""\#($0)":{"file":"\#($0).mov","width":512,"height":512,"alpha":true,"audio":false}"# }
            .joined(separator: ",")
        return try JSONDecoder().decode(
            LoopsManifest.self, from: Data(#"{"schemaVersion":1,"characters":{\#(entries)}}"#.utf8))
    }

    @Test("la tabla del spike tiene una sola entrada: cartonero__oro")
    func tableHasOnlyTheSpikeEntry() {
        #expect(SkinTints.table.keys.sorted() == ["cartonero__oro"])
        #expect(SkinTints.tint(type: "cartonero", skin: "oro") != nil)
        #expect(SkinTints.tint(type: "cartonero", skin: "diamante") == nil)
        #expect(SkinTints.tint(type: "mantero", skin: "oro") == nil)
    }

    @Test("la pinta habilitada usa el clip del tipo base con el tinte")
    func enabledSkinUsesTintedBaseClip() throws {
        let loops = try manifest(["cartonero", "mantero"])
        let playable = try #require(ArtClips.characterPlayable(type: "cartonero", skin: "oro", in: loops))
        #expect(playable.clip == .character("cartonero"))
        #expect(playable.tint == SkinTints.tint(type: "cartonero", skin: "oro"))
        #expect(ArtClips.characterPlayable(type: "cartonero", skin: nil, in: loops)?.tint == nil)
    }

    @Test("pinta de dibujo propio, o recoloreo no habilitada, sigue sin clip: queda el PNG")
    func otherSkinsStayStill() throws {
        let loops = try manifest(["cartonero", "mantero"])
        #expect(ArtClips.characterPlayable(type: "cartonero", skin: "urban_trailblazer", in: loops) == nil)
        #expect(ArtClips.characterPlayable(type: "cartonero", skin: "diamante", in: loops) == nil)
        #expect(ArtClips.characterPlayable(type: "mantero", skin: "oro", in: loops) == nil)
    }

    @Test("sin clip base la pinta habilitada queda estática; con clip propio gana el propio sin tinte")
    func noBaseClipStaysStillAndOwnClipWins() throws {
        #expect(ArtClips.characterPlayable(type: "cartonero", skin: "oro", in: try manifest(["mantero"])) == nil)
        let own = try #require(ArtClips.characterPlayable(
            type: "cartonero", skin: "oro", in: try manifest(["cartonero", "cartonero__oro"])))
        #expect(own.clip == .character("cartonero__oro") && own.tint == nil)
    }

    @Test("en la ficha sólo la seleccionada y tuya anima; la silueta y la vecina no")
    func sheetGatesTheTint() throws {
        let loops = try manifest(["cartonero"])
        func playable(selected: Bool, owned: Bool) -> ArtClips.Playable? {
            CharacterSheetView.playable(skinID: "oro", type: "cartonero", isSelected: selected, owned: owned, in: loops)
        }
        #expect(playable(selected: true, owned: true)?.tint != nil)
        #expect(playable(selected: true, owned: false) == nil)
        #expect(playable(selected: false, owned: true) == nil)
    }

    // MARK: El filtro

    private func render(_ tint: ArtTint, red: Double, green: Double, blue: Double, alpha: Double) -> [UInt8] {
        let color = CIColor(red: red * alpha, green: green * alpha, blue: blue * alpha, alpha: alpha)
        let input = CIImage(color: color).cropped(to: CGRect(x: 0, y: 0, width: 4, height: 4))
        var pixel = [UInt8](repeating: 0, count: 4)
        CIContext().render(tint.apply(to: input), toBitmap: &pixel, rowBytes: 4,
                           bounds: CGRect(x: 1, y: 1, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
        return pixel
    }

    @Test("el tinte vuelve dorado el verde de la ropa y respeta el alfa", arguments: ArtTint.allCases)
    func tintTurnsGreenIntoGoldKeepingAlpha(_ tint: ArtTint) {
        let opaque = render(tint, red: 0.35, green: 0.55, blue: 0.25, alpha: 1)
        #expect(opaque[3] == 255)
        #expect(opaque[0] > opaque[1] && opaque[1] > opaque[2], "dorado: rojo > verde > azul, fue \(opaque)")
        let clear = render(tint, red: 0.35, green: 0.55, blue: 0.25, alpha: 0)
        #expect(clear[3] == 0, "el fondo transparente sigue transparente")
        let half = render(tint, red: 0.35, green: 0.55, blue: 0.25, alpha: 0.5)
        #expect(abs(Int(half[3]) - 128) <= 2, "el borde suavizado conserva su alfa")
    }

    @Test("la luminancia manda: la línea oscura queda más oscura que la luz")
    func luminanceOrderIsKept() {
        let ink = render(.goldMonochrome, red: 0.05, green: 0.05, blue: 0.05, alpha: 1)
        let light = render(.goldMonochrome, red: 0.9, green: 0.9, blue: 0.9, alpha: 1)
        #expect(Int(ink[0]) + Int(ink[1]) < Int(light[0]) + Int(light[1]))
    }
}
