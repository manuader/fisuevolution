import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins

/// Un tinte en vivo: el clip del tipo base recoloreado para parecerse al PNG de una pinta que es el
/// mismo dibujo con otra paleta. Cada caso es un filtro de Core Image que corre sobre cada cuadro
/// del video, con el alfa intacto.
enum ArtTint: String, CaseIterable, Sendable {
    /// Mapa de degradé: la luminancia recorre de marrón oscuro a crema dorado. Línea y sombras
    /// quedan oscuras, las luces se vuelven brillo de metal. Un solo kernel de color.
    case goldGradient
    /// Monocromo dorado de Core Image: la luminancia multiplica el dorado.
    case goldMonochrome
    /// Gris por el dorado a través de una matriz: sin luces crema, el dorado más plano.
    case goldMultiply

    private static let goldShadow = CIColor(red: 0.30, green: 0.16, blue: 0.02)
    private static let goldLight = CIColor(red: 1.0, green: 0.91, blue: 0.55)
    private static let gold = CIColor(red: 0.96, green: 0.76, blue: 0.20)
    private static let luma = (r: 0.299, g: 0.587, b: 0.114)

    /// El clip base es de colores oscuros (verde, marrón) y el oro es metal brillante: se levanta la
    /// luminancia antes de mapearla.
    private func lifted(_ image: CIImage) -> CIImage {
        image.applyingFilter("CIGammaAdjust", parameters: ["inputPower": 0.55])
    }

    /// Pura y sin estado: sirve igual para un cuadro de video que para un `CIImage` de un test.
    func apply(to image: CIImage) -> CIImage {
        let output: CIImage? = switch self {
        case .goldGradient:
            lifted(image).applyingFilter("CIFalseColor", parameters: [
                "inputColor0": Self.goldShadow, "inputColor1": Self.goldLight,
            ])
        case .goldMonochrome:
            lifted(image).applyingFilter("CIColorMonochrome", parameters: [
                kCIInputColorKey: Self.gold, kCIInputIntensityKey: 1.0,
            ])
        case .goldMultiply:
            lifted(image).applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: Self.luma.r * Self.gold.red, y: Self.luma.g * Self.gold.red, z: Self.luma.b * Self.gold.red, w: 0),
                "inputGVector": CIVector(x: Self.luma.r * Self.gold.green, y: Self.luma.g * Self.gold.green, z: Self.luma.b * Self.gold.green, w: 0),
                "inputBVector": CIVector(x: Self.luma.r * Self.gold.blue, y: Self.luma.g * Self.gold.blue, z: Self.luma.b * Self.gold.blue, w: 0),
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1),
            ])
        }
        return (output ?? image).cropped(to: image.extent)
    }

    /// La composición que aplica el tinte cuadro a cuadro; se le pone al `AVPlayerItem` antes de
    /// reproducir (también al template de un `AVPlayerLooper`, que la copia a sus items).
    func videoComposition(for asset: AVAsset) async throws -> AVVideoComposition {
        try await AVVideoComposition.videoComposition(with: asset) { [self] request in
            request.finish(with: apply(to: request.sourceImage), context: nil)
        }
    }
}
