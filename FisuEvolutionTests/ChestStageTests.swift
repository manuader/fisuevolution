import Foundation
import Testing
@testable import FisuEvolution

/// Los clips nuevos del cofre (E14 C26) y la geometría que los encastra con el
/// premio que dibuja el código.
@Suite("El cofre: los clips de C26 y su escenario")
struct ChestStageTests {
    @Test func cadaMomentoTieneSuClip() {
        #expect(ChestClip.id(opening: false, shaking: false) == "cofre_espera")
        #expect(ChestClip.id(opening: false, shaking: true) == "cofre_sacude")
        #expect(ChestClip.id(opening: true, shaking: true) == "cofre_abre")
        #expect(ChestClip.id(opening: true, shaking: false) == "cofre_abre")
    }

    @Test func losTresClipsEstanEnElManifestYEnElBundle() throws {
        let manifest = try #require(
            (Bundle.main.url(forResource: "loops_manifest", withExtension: "json"))
                .flatMap { try? Data(contentsOf: $0) }
                .flatMap { try? JSONDecoder().decode(LoopsManifest.self, from: $0) }
        )
        for id in ["cofre_espera", "cofre_sacude", "cofre_abre"] {
            let entry = try #require(manifest.objects[id], "falta \(id) en el manifest")
            let name = entry.file as NSString
            #expect(Bundle.main.url(forResource: name.deletingPathExtension,
                                    withExtension: name.pathExtension) != nil,
                    "\(entry.file) no está en el bundle")
        }
    }

    /// D14: el bloque del premio termina antes de que empiece la tapa abierta.
    @Test func elPremioNoPisaElCofreAbierto() {
        #expect(ChestStage.prizeBottomY < ChestStage.lidTopY)
    }

    /// El cofre del clip es el mismo cuadro cuadrado en los tres, y cabe en pantalla SE.
    @Test func elEscenarioCabeEnElSE() {
        let half: CGFloat = 667 / 2
        #expect(ChestStage.clipY + ChestStage.clipSide / 2 < half)
        #expect(ChestStage.prizeY - ChestStage.prizeHeight / 2 > -half)
    }

    /// La barra de abajo queda a la vista durante el cofre (r56): en el SE el
    /// escenario entero —premio, cofre y botones— entra arriba de ella (D14).
    @MainActor @Test func elEscenarioEntraArribaDeLaBarraEnElSE() {
        let seClearance = GameTabBar.barHeight + GameTabBar.minimumBottomGap + ChestStage.barGap
        let available = 667 - seClearance
        let fit = ChestStage.fit(height: available)
        #expect(fit < 1, "en el SE no entra a tamaño natural: tiene que achicarse")
        #expect(ChestStage.halfHeight * 2 * fit <= available)
        // En un 15 Pro (852 pt, 59 arriba, 34 abajo) entra entero sin achicarse.
        let proAvailable = 852 - 59 - (GameTabBar.barHeight + 34 + ChestStage.barGap)
        #expect(ChestStage.fit(height: proAvailable) == 1)
    }

    /// Los recursos viejos del cofre se retiraron: nada del bundle los nombra.
    @Test func losRecursosViejosYaNoEstan() {
        #expect(Bundle.main.url(forResource: "chest_open", withExtension: "mov") == nil)
        #expect(Bundle.main.url(forResource: "chest_anim", withExtension: "json") == nil)
        #expect(Bundle.main.url(forResource: "chest_f000", withExtension: "png") == nil)
    }
}
