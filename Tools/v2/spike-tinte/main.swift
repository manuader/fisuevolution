// Genera Docs/capturas/spike-tinte/comparativa.png: cuadro base | variantes de ArtTint | PNG de la pinta.
// swiftc -O Tools/v2/spike-tinte/main.swift FisuEvolution/Managers/ArtTint.swift -o /tmp/cap
// /tmp/cap <char_cartonero.mov> <cartonero_idle__oro@2x.png> Docs/capturas/spike-tinte
import AVFoundation
import CoreImage
import AppKit

let args = CommandLine.arguments
let video = URL(fileURLWithPath: args[1]), skinPNG = args[2], outDir = args[3]
let asset = AVURLAsset(url: video)
let g = AVAssetImageGenerator(asset: asset)
g.requestedTimeToleranceBefore = .zero; g.requestedTimeToleranceAfter = .zero
let frame = CIImage(cgImage: try g.copyCGImage(at: CMTime(seconds: 1, preferredTimescale: 600), actualTime: nil))
let target = CIImage(contentsOf: URL(fileURLWithPath: skinPNG))!
let ctx = CIContext()
let size = 512.0
func fit(_ i: CIImage) -> CIImage {
    let s = size / max(i.extent.width, i.extent.height)
    return i.transformed(by: CGAffineTransform(scaleX: s, y: s)).transformed(by: CGAffineTransform(translationX: -i.extent.origin.x * s, y: -i.extent.origin.y * s))
}
let plate = CIImage(color: CIColor(red: 0.93, green: 0.90, blue: 0.84)).cropped(to: CGRect(x: 0, y: 0, width: size, height: size))
func over(_ i: CIImage, dx: Double) -> CIImage { fit(i).composited(over: plate).transformed(by: CGAffineTransform(translationX: dx, y: 0)) }
var tiles: [(String, CIImage)] = [("base", frame)]
for t in ArtTint.allCases { tiles.append((t.rawValue, t.apply(to: frame))) }
tiles.append(("pinta", target))
var strip = CIImage(color: .white).cropped(to: CGRect(x: 0, y: 0, width: size * Double(tiles.count), height: size))
for (n, (name, img)) in tiles.enumerated() {
    strip = over(img, dx: size * Double(n)).composited(over: strip)
    print(n, name)
}
let cg = ctx.createCGImage(strip, from: strip.extent)!
try NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: outDir + "/comparativa.png"))
// alfa preservado
for t in ArtTint.allCases {
    let o = t.apply(to: frame)
    let px = { (img: CIImage) -> [UInt8] in var b = [UInt8](repeating: 0, count: 4); ctx.render(img, toBitmap: &b, rowBytes: 4, bounds: CGRect(x: 2, y: 2, width: 1, height: 1), format: .RGBA8, colorSpace: nil); return b }
    print(t.rawValue, "esquina alfa:", px(o)[3], "centro fuente:", frame.extent)
}
