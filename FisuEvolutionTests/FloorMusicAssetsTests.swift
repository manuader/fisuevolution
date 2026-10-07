import AudioToolbox
import AVFoundation
import Foundation
import Testing
@testable import FisuEvolution

/// Los diez temas por piso viajan en AAC (PLAN-v2 §5), que es justo el formato
/// que la v1 había descartado para la música: el padding del encoder rompía el
/// loop. Lo que lo vuelve seguro es que el CAF trae la tabla de paquetes y que
/// `AudioManager` decodifica el tema entero antes de loopearlo. Estos tests
/// pinean las dos mitades contra los archivos reales del bundle: si alguien
/// regenera un tema en m4a, o el decodificador deja el priming adentro, el
/// loop tropieza en la costura y acá se ve.
@Suite("Temas por piso en el bundle")
@MainActor
struct FloorMusicAssetsTests {
    @Test("cada piso de economy.json tiene su tema en el bundle")
    func everyFloorHasItsTrack() throws {
        let content = try GameContentLoader.load(from: .main)
        for floor in content.floorTable.floors {
            let track = FloorMusicDirector.track(forFloor: floor.id)
            #expect(Bundle.main.url(forResource: track, withExtension: "caf") != nil, "falta \(track).caf")
        }
    }

    @Test("decodificado, cada tema dura exacto lo que dice su tabla de paquetes y la costura no salta")
    func decodedLoopsAreExactAndSeamless() throws {
        let content = try GameContentLoader.load(from: .main)
        for floor in content.floorTable.floors {
            let track = FloorMusicDirector.track(forFloor: floor.id)
            let url = try #require(Bundle.main.url(forResource: track, withExtension: "caf"))
            let table = try #require(Self.packetTable(url), "\(track) no trae tabla de paquetes")
            #expect(table.mPrimingFrames > 0, "\(track): sin priming no hay nada que recortar (¿no es AAC?)")

            let wav = try #require(AudioManager.decodedWAV(url))
            let samples = Self.samples(ofWAV: wav)
            #expect(
                Int64(samples.count) == table.mNumberValidFrames,
                "\(track): el priming o el remainder del encoder quedaron adentro del loop"
            )

            // El WAV en memoria es lo que recibe el player: la cabecera tiene
            // que decir el mismo largo.
            let player = try AVAudioPlayer(data: wav, fileTypeHint: AVFileType.wav.rawValue)
            #expect(abs(player.duration - Double(samples.count) / 44_100) < 0.001)

            // La costura: el salto de la última muestra a la primera no puede
            // ser más grande que el 99 % de los saltos entre muestras vecinas
            // del propio tema. Un clic es justamente un salto que no aparece
            // en ningún otro lado.
            let seam = abs(Int(samples[0]) - Int(samples[samples.count - 1]))
            let typical = Self.percentile99(ofStepsIn: samples)
            #expect(seam <= typical, "\(track): la costura salta \(seam) y el p99 del tema es \(typical)")
        }
    }

    private static func packetTable(_ url: URL) -> AudioFilePacketTableInfo? {
        var fileID: AudioFileID?
        guard AudioFileOpenURL(url as CFURL, .readPermission, kAudioFileCAFType, &fileID) == noErr,
              let fileID
        else { return nil }
        defer { AudioFileClose(fileID) }
        var info = AudioFilePacketTableInfo()
        var size = UInt32(MemoryLayout<AudioFilePacketTableInfo>.size)
        guard AudioFileGetProperty(fileID, kAudioFilePropertyPacketTableInfo, &size, &info) == noErr else {
            return nil
        }
        return info
    }

    /// Las muestras después de la cabecera de 44 bytes que arma `AudioManager`.
    private static func samples(ofWAV wav: Data) -> [Int16] {
        let body = wav.dropFirst(44)
        var samples = [Int16](repeating: 0, count: body.count / 2)
        _ = samples.withUnsafeMutableBytes { body.copyBytes(to: $0) }
        return samples
    }

    /// Por histograma y no ordenando: son ~1,2 millones de saltos por tema y
    /// los unit tests corren en Debug.
    private static func percentile99(ofStepsIn samples: [Int16]) -> Int {
        var histogram = [Int](repeating: 0, count: 65_536)
        for index in 1..<samples.count {
            histogram[abs(Int(samples[index]) - Int(samples[index - 1]))] += 1
        }
        let target = Int(Double(samples.count - 1) * 0.99)
        var seen = 0
        for (step, count) in histogram.enumerated() {
            seen += count
            if seen > target { return step }
        }
        return histogram.count - 1
    }
}
