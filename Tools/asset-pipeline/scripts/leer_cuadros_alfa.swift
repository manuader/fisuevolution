// Vuelca a stdout los cuadros de un .mov HEVC con alfa como BGRA crudo, premultiplicado tal cual lo
// guarda el clip (y lo composita el juego), uno detrás del otro. `ffmpeg` no lee el alfa de estos .mov y AVFoundation sí (PLAN-v2-E14b B32).
// Por stderr escribe una línea "<ancho> <alto>" antes de los datos.
//
//     swiftc -O leer_cuadros_alfa.swift -o leer_cuadros_alfa && ./leer_cuadros_alfa clip.mov > cuadros.bgra
import AVFoundation
import CoreVideo
import Foundation

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data("uso: leer_cuadros_alfa <clip.mov>\n".utf8))
    exit(2)
}
let asset = AVURLAsset(url: URL(fileURLWithPath: CommandLine.arguments[1]))
guard let track = asset.tracks(withMediaType: .video).first,
      let reader = try? AVAssetReader(asset: asset) else {
    FileHandle.standardError.write(Data("no se pudo abrir el video\n".utf8))
    exit(1)
}
let salida = AVAssetReaderTrackOutput(
    track: track,
    outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
reader.add(salida)
reader.startReading()

var avisado = false
while let muestra = salida.copyNextSampleBuffer() {
    guard let pb = CMSampleBufferGetImageBuffer(muestra) else { continue }
    CVPixelBufferLockBaseAddress(pb, .readOnly)
    let w = CVPixelBufferGetWidth(pb), h = CVPixelBufferGetHeight(pb)
    let bpr = CVPixelBufferGetBytesPerRow(pb)
    let base = CVPixelBufferGetBaseAddress(pb)!
    if !avisado {
        FileHandle.standardError.write(Data("\(w) \(h)\n".utf8))
        avisado = true
    }
    for y in 0..<h {
        FileHandle.standardOutput.write(Data(bytes: base + y * bpr, count: w * 4))
    }
    CVPixelBufferUnlockBaseAddress(pb, .readOnly)
}
if reader.status == .failed { exit(1) }
