import Foundation
import SwiftUI

/// El manifest de `Resources/ChestAnim/`: la animación del cofre sacada del
/// video del animador, en tres familias — frames interactivos (idle y las dos
/// sacudidas, que responden al dedo sin preroll), el tramo cinemático en HEVC
/// con alfa (`chest_open.mov`, del estallido al marco vacío) y el still del
/// estado final para Reduce Motion.
///
/// Los assets los produce `Tools/asset-pipeline/scripts/chest_video_frames.py`
/// y `chest_anim.json` (schemaVersion 2) es **el contrato entre el pipeline y
/// este archivo**: cambiar un lado sin el otro lo pinean `ChestAnimationTests`
/// (acá) y `test_chest_video_frames` (allá). Todos los encuadres comparten un
/// lienzo de 1280×720 en el que el cofre no se mueve del piso — por eso
/// alcanza UNA ancla (`chestRect`) para que PNGs y video se dibujen con el
/// cofre del mismo tamaño y en el mismo lugar; `parchmentRect` es la segunda
/// ancla: el interior vacío de la carta del último frame, donde el juego
/// renderiza el contenido del premio.
struct ChestAnimation: Sendable {
    /// Un latido interactivo reproduce un segmento de frames; los nombres son
    /// los del manifest. El tramo cinemático no es un segmento: es el video.
    enum Segment: String, CaseIterable, Sendable {
        case idle, shakeA, shakeB
    }

    struct Rect: Decodable, Equatable, Sendable {
        let x: CGFloat
        let y: CGFloat
        let w: CGFloat
        let h: CGFloat
    }

    struct SegmentInfo: Decodable, Sendable {
        let first: Int
        let last: Int
        let crop: Rect
        /// Escala de ENTREGA del PNG respecto del lienzo. No participa del
        /// layout: un frame a 0,8 representa la misma área de lienzo y se
        /// estira a los mismos puntos.
        let scale: CGFloat

        var frameCount: Int { last - first + 1 }
    }

    /// Cómo dibujar un encuadre con el cofre anclado: el tamaño en puntos del
    /// recorte y el corrimiento de su centro respecto del centro del cofre.
    struct Stage: Sendable {
        let size: CGSize
        let offset: CGSize
    }

    private struct Manifest: Decodable {
        struct Size: Decodable {
            let w: CGFloat
            let h: CGFloat
        }

        struct Cinematic: Decodable {
            let file: String
            let first: Int
            let last: Int
            let crop: Rect
        }

        struct Still: Decodable {
            let file: String
            let crop: Rect
            let scale: CGFloat
        }

        let schemaVersion: Int
        let fps: Double
        let canvas: Size
        let chestRect: Rect
        let parchmentRect: Rect
        let segments: [String: SegmentInfo]
        let cinematic: Cinematic
        let cardStill: Still
    }

    let fps: Double
    let chestRect: Rect
    let parchmentRect: Rect
    let cinematicURL: URL
    let cinematicCrop: Rect
    let cinematicFrameCount: Int
    let cardStillURL: URL
    let cardStillCrop: Rect
    private let segments: [Segment: SegmentInfo]
    private let frameURLs: [Segment: [URL]]

    /// El manifest parseado una sola vez. `nil` si falta o está roto — el
    /// overlay cae entonces al cofre estático, feo pero funcional, y
    /// `ChestAnimationTests` pina que en el bundle real esto nunca es `nil`.
    static let shared: ChestAnimation? = load()

    static func load(bundle: Bundle = .main) -> ChestAnimation? {
        guard let url = bundle.url(forResource: "chest_anim", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let manifest = try? JSONDecoder().decode(Manifest.self, from: data),
              manifest.schemaVersion == 2
        else {
            Log.assets.error("chest_anim.json missing or unreadable; chest opening falls back to static art")
            return nil
        }

        func resource(_ fileName: String) -> URL? {
            let name = (fileName as NSString).deletingPathExtension
            let ext = (fileName as NSString).pathExtension
            return bundle.url(forResource: name, withExtension: ext)
        }

        var segments: [Segment: SegmentInfo] = [:]
        var frameURLs: [Segment: [URL]] = [:]
        for segment in Segment.allCases {
            guard let info = manifest.segments[segment.rawValue] else {
                Log.assets.error("chest_anim.json lacks segment '\(segment.rawValue)'")
                return nil
            }
            var urls: [URL] = []
            for n in info.first...info.last {
                guard let frame = bundle.url(
                    forResource: String(format: "chest_f%03d", n),
                    withExtension: "png"
                ) else {
                    Log.assets.error("chest frame \(n) missing for segment '\(segment.rawValue)'")
                    return nil
                }
                urls.append(frame)
            }
            segments[segment] = info
            frameURLs[segment] = urls
        }

        guard let cinematicURL = resource(manifest.cinematic.file),
              let cardStillURL = resource(manifest.cardStill.file)
        else {
            Log.assets.error("chest cinematic or card still missing from bundle")
            return nil
        }

        return ChestAnimation(
            fps: manifest.fps,
            chestRect: manifest.chestRect,
            parchmentRect: manifest.parchmentRect,
            cinematicURL: cinematicURL,
            cinematicCrop: manifest.cinematic.crop,
            cinematicFrameCount: manifest.cinematic.last - manifest.cinematic.first + 1,
            cardStillURL: cardStillURL,
            cardStillCrop: manifest.cardStill.crop,
            segments: segments,
            frameURLs: frameURLs
        )
    }

    func info(_ segment: Segment) -> SegmentInfo {
        // Los tres segmentos existen si `load` devolvió algo: la carga es
        // todo-o-nada a propósito, para que acá no haya optional que arrastrar.
        segments[segment]!
    }

    func frames(_ segment: Segment) -> [URL] {
        frameURLs[segment]!
    }

    func stage(_ segment: Segment, chestWidth: CGFloat) -> Stage {
        stage(for: info(segment).crop, chestWidth: chestWidth)
    }

    /// El encuadre del video (y del still, que comparte crop): el lienzo
    /// entero, anclado por el cofre.
    func cinematicStage(chestWidth: CGFloat) -> Stage {
        stage(for: cinematicCrop, chestWidth: chestWidth)
    }

    /// Dónde renderizar el contenido del premio: el interior pergamino de la
    /// carta del último frame, en puntos y relativo al centro del cofre — el
    /// mismo sistema de coordenadas que `cinematicStage`, así que un overlay
    /// centrado en el escenario con este offset cae exacto dentro del marco.
    func parchmentStage(chestWidth: CGFloat) -> Stage {
        stage(for: parchmentRect, chestWidth: chestWidth)
    }

    private func stage(for crop: Rect, chestWidth: CGFloat) -> Stage {
        let k = chestWidth / chestRect.w
        let chestCenter = CGPoint(x: chestRect.x + chestRect.w / 2, y: chestRect.y + chestRect.h / 2)
        let cropCenter = CGPoint(x: crop.x + crop.w / 2, y: crop.y + crop.h / 2)
        return Stage(
            size: CGSize(width: crop.w * k, height: crop.h * k),
            offset: CGSize(
                width: (cropCenter.x - chestCenter.x) * k,
                height: (cropCenter.y - chestCenter.y) * k
            )
        )
    }
}
