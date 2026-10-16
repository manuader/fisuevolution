import Foundation
import SpriteKit
import Testing
@testable import FisuEvolution

/// E14b B30 (D13, experimento): el tamaño según la distancia. Se prueba la cuenta pura: los bordes,
/// la monotonía, que no haya saltos y que el área de toque no baje del mínimo.
@Suite("Tamaño según la distancia: más atrás, más chico")
struct DepthScaleTests {
    private let span = DepthScale.Span(backY: 560, frontY: 190)
    private let tolerance: CGFloat = 0.0001

    @Test("en el horizonte vale backScale y al frente frontScale")
    func edges() {
        #expect(abs(DepthScale.scale(forFeetY: span.backY, in: span) - DepthScale.backScale) < tolerance)
        #expect(abs(DepthScale.scale(forFeetY: span.frontY, in: span) - DepthScale.frontScale) < tolerance)
    }

    @Test("fuera del tramo se queda quieta en el borde")
    func clampsOutsideTheSpan() {
        #expect(DepthScale.scale(forFeetY: span.backY + 400, in: span) == DepthScale.backScale)
        #expect(DepthScale.scale(forFeetY: span.frontY - 400, in: span) == DepthScale.frontScale)
    }

    @Test("más arriba en la pantalla nunca es más grande")
    func monotonic() {
        var previous = DepthScale.scale(forFeetY: span.frontY - 20, in: span)
        for y in stride(from: span.frontY - 19, through: span.backY + 20, by: 1) {
            let scale = DepthScale.scale(forFeetY: y, in: span)
            #expect(scale <= previous + tolerance, "pies en \(y): \(scale) crece sobre \(previous)")
            previous = scale
        }
    }

    @Test("sin saltos: un punto de y mueve la escala menos de un 1 %")
    func noJumps() {
        for y in stride(from: span.frontY - 10, through: span.backY + 10, by: 1) {
            let step = abs(DepthScale.scale(forFeetY: y + 1, in: span) - DepthScale.scale(forFeetY: y, in: span))
            #expect(step < 0.01, "pies en \(y): salto de \(step)")
        }
    }

    @Test("siempre entre backScale y frontScale")
    func staysInRange() {
        for y in stride(from: CGFloat(-100), through: 1600, by: 7) {
            let scale = DepthScale.scale(forFeetY: y, in: span)
            #expect(scale >= DepthScale.backScale - tolerance && scale <= DepthScale.frontScale + tolerance)
        }
    }

    @Test("un tramo vacío o una y inválida no rompen: escala del frente")
    func degenerateInputs() {
        let flat = DepthScale.Span(backY: 200, frontY: 200)
        #expect(DepthScale.scale(forFeetY: 200, in: flat) == DepthScale.frontScale)
        #expect(DepthScale.scale(forFeetY: .nan, in: span) == DepthScale.frontScale)
    }

    @Test("el área de toque nunca baja de 44 pt, aunque el cuerpo sea más chico")
    func minimumTouch() {
        let tiny = CGRect(x: 100, y: 100, width: 20, height: 30)
        let grown = DepthScale.enforcingMinimumTouch(tiny)
        #expect(grown.width >= DepthScale.minTouchSide && grown.height >= DepthScale.minTouchSide)
        #expect(abs(grown.midX - tiny.midX) < tolerance && abs(grown.midY - tiny.midY) < tolerance)
        let big = CGRect(x: 0, y: 0, width: 80, height: 120)
        #expect(DepthScale.enforcingMinimumTouch(big) == big)
    }

    @Test("el tramo de un piso va del horizonte al frente de la pantalla")
    @MainActor
    func spanFromTheStageLayout() {
        let layout = StageLayout(sceneSize: CGSize(width: 393, height: 852), bottomInset: BoardScene.bottomInset,
                                 cellSize: 72, floorBottom: BoardScene.floorBottom)
        for background in StageLayout.horizons.keys {
            let span = layout.depthSpan(background: background)
            #expect(span.frontY == layout.groundFloorY)
            #expect(span.backY >= span.frontY, "\(background): el horizonte quedó debajo del frente")
        }
    }
}
