import Foundation
import Testing
import UIKit
@testable import FisuEvolution

/// La política de presentación de las hojas (PLAN-v2 E3, spike S1): en iPad una
/// `.sheet` sale opaca o como tarjeta según el runtime, así que ahí la hoja es
/// un `fullScreenCover` transparente con velo propio; en iPhone no cambia nada.
@Suite("La política de presentación de las hojas")
struct SheetPresentationPolicyTests {
    @Test("sólo el iPad presenta con un cover; el iPhone sigue con la hoja de siempre")
    func onlyThePadUsesACover() {
        #expect(SheetPresentation.usesCover(on: .pad))
        #expect(!SheetPresentation.usesCover(on: .phone))
        #expect(!SheetPresentation.usesCover(on: .unspecified))
    }

    @Test("el panel de una hoja no pasa de 640 pt y el velo atenúa el juego como el del sistema")
    func columnAndVeil() {
        #expect(SheetColumn.maxWidth == 640)
        #expect(SheetPresentation.veilOpacity == 0.35)
    }
}

/// Toda hoja del juego pasa por `fisuSheet` (PLAN-v2 E3, iPad): una que se
/// presente a mano con `.presentationBackground(.clear)` o con un `.sheet(` pelado
/// sale en iPad como un formulario angosto. Lee las FUENTES con `#filePath`,
/// como `LocalizationCompletenessTests`.
@Suite("Toda hoja se presenta con fisuSheet")
struct SheetPresentationGuardTests {
    private static let appSources = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appending(path: "FisuEvolution")

    /// El único archivo autorizado: el que define `fisuSheet`.
    private static let definition = "PanelFrames.swift"

    /// Los que todavía presentan a mano, con su motivo. Los presentadores de las
    /// hojas viven en `RootView`, que es caliente: los migra la Task 11 de E3a,
    /// que deja esta lista vacía.
    private static let pending: Set<String> = ["RootView.swift"]

    /// Presentan con un `.sheet(` que no es una hoja del juego: la hoja de
    /// compartir del sistema (`UIActivityViewController`), que el sistema
    /// presenta como quiere.
    private static let systemSheets: Set<String> = ["ShareCardView.swift"]

    /// Las líneas de código (sin comentarios) de cada fuente que le toca al guardia.
    private static func guardedSources() throws -> [(name: String, code: [String])] {
        var sources: [(String, [String])] = []
        let files = FileManager.default.enumerator(at: appSources, includingPropertiesForKeys: nil)
        while let url = files?.nextObject() as? URL {
            let name = url.lastPathComponent
            guard url.pathExtension == "swift", name != definition, !pending.contains(name) else { continue }
            let code = try String(contentsOf: url, encoding: .utf8)
                .split(separator: "\n")
                .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
                .map(String.init)
            sources.append((name, code))
        }
        return sources
    }

    @Test("ninguna hoja usa .presentationBackground(.clear) a mano")
    func noSheetBypassesFisuSheet() throws {
        let offenders = try Self.guardedSources()
            .filter { $0.code.contains { $0.contains(".presentationBackground(.clear)") } }
            .map(\.name)
        #expect(offenders.isEmpty, "presentan a mano: \(offenders.sorted())")
    }

    @Test("ninguna hoja se presenta con .sheet( ni .fullScreenCover( pelados")
    func noBareSheetPresenters() throws {
        let offenders = try Self.guardedSources()
            .filter { !Self.systemSheets.contains($0.name) }
            .filter { $0.code.contains { $0.contains(".sheet(") || $0.contains(".fullScreenCover(") } }
            .map(\.name)
        #expect(offenders.isEmpty, "presentan con .sheet a mano: \(offenders.sorted())")
    }
}
