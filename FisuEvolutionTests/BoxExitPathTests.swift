import CoreGraphics
import Foundation
import Testing
@testable import FisuEvolution

/// E14b B23: el empleado sale de adentro de la caja. Sin `SKView` las acciones no corren, así que se
/// mide la cuenta de la que salen: asoma detrás del frente, salta al costado, aterriza delante de la
/// línea de la caja y termina en su lugar de la hilera.
@Suite("La salida de la caja (E14b B23)")
struct BoxExitPathTests {
    private let boxFeet = CGPoint(x: 120, y: 260)
    private let boxWidth: CGFloat = 72 * PickupLayout.sideRatio
    private var rimY: CGFloat { boxFeet.y + boxWidth }

    private func path(to target: CGPoint) -> BoxExitPath {
        BoxExitPath(boxFeet: boxFeet, rimY: rimY, boxWidth: boxWidth, target: target)
    }

    @Test("termina en su lugar de la hilera: camina del aterrizaje a su lugar a paso de caminata, después de aterrizar")
    func endsOnItsSlot() {
        let slot = CGPoint(x: 260, y: 180)
        let exit = path(to: slot)
        let distance = hypot(slot.x - exit.landing.x, slot.y - exit.landing.y)
        #expect(distance > 0, "aterriza al lado de la caja, no en su lugar: le queda caminar")
        #expect(abs(exit.walkSeconds - max(BoxExitPath.minWalkSeconds, Double(distance / BoxExitPath.walkSpeed))) < 0.0001)
        #expect(exit.jumpStart < exit.landingTime)
        #expect(abs(exit.totalSeconds - (exit.landingTime + BoxExitPath.squashSeconds + exit.walkSeconds)) < 0.0001)
        // Al lado, la caminata no baja del mínimo: no llega de golpe.
        #expect(path(to: exit.landing).walkSeconds == BoxExitPath.minWalkSeconds)
    }

    // MARK: Cortar la salida a mitad de camino

    /// El empleado a mitad de la salida: detrás del frente, aplastado debajo del borde, o en el aire
    /// estirado; con Reduce Motion, a medio fundido.
    private var midExitPoses: [CharacterPose] {
        let exit = path(to: CGPoint(x: 260, y: 180))
        return [
            CharacterPose(position: exit.start, xScale: 1, yScale: BoxExitPath.hiddenYScale),
            CharacterPose(position: exit.peek, xScale: BoxExitPath.stretchXScale, yScale: BoxExitPath.stretchYScale),
            CharacterPose(position: exit.jumpPoint(at: 0.5), xScale: BoxExitPath.squashXScale, yScale: BoxExitPath.squashYScale),
            CharacterPose(position: exit.landing, alpha: 0.4),
        ]
    }

    @Test("agarrarlo a mitad de la salida lo deja sano donde está: escala 1 y opaco, sin saltar")
    func grabbingMidExitHeals() {
        let slot = CGPoint(x: 260, y: 180)
        for pose in midExitPoses {
            let grabbed = BoxExitInterruption.grab.pose(from: pose, slot: slot)
            #expect(grabbed.position == pose.position, "el dedo lo agarró ahí")
            #expect(grabbed.xScale == 1 && grabbed.yScale == 1, "no queda aplastado ni estirado: \(pose)")
            #expect(grabbed.alpha == 1)
        }
    }

    @Test("un toque a mitad de la salida (agarrar y soltar sin arrastrar) lo deja en su celda con escala 1")
    func tappingMidExitEndsOnItsSlot() {
        let slot = CGPoint(x: 260, y: 180)
        for pose in midExitPoses {
            let tapped = BoxExitInterruption.pose(after: [.grab, .tap], from: pose, slot: slot)
            #expect(tapped == CharacterPose(position: slot), "varado en \(pose.position) en vez de su lugar")
        }
    }

    @Test("el foco del tutorial a mitad de la salida lo planta en su celda, sano")
    func theSpotlightPutsItOnItsSlot() {
        let slot = CGPoint(x: 40, y: 150)
        for pose in midExitPoses {
            #expect(BoxExitInterruption.spotlight.pose(from: pose, slot: slot) == CharacterPose(position: slot))
        }
    }

    @Test("el arrastre se mide desde donde apoyó el dedo, no desde la celda")
    func theDragThresholdStartsAtTheGrab() {
        let grab = CGPoint(x: 120, y: 330)
        let threshold: CGFloat = 10
        #expect(!BoxExitInterruption.isDragging(from: grab, to: CGPoint(x: 126, y: 336), threshold: threshold),
                "un temblor del dedo es un toque, aunque el empleado esté lejos de su celda")
        #expect(BoxExitInterruption.isDragging(from: grab, to: CGPoint(x: 120, y: 345), threshold: threshold))
    }

    @Test("asoma detrás del frente de la caja: sus pies van más atrás que la línea de la caja, y suben")
    func risesBehindTheFront() {
        let exit = path(to: CGPoint(x: 260, y: 180))
        #expect(exit.start.x == boxFeet.x && exit.peek.x == boxFeet.x, "sale de adentro, no del costado")
        #expect(exit.start.y > boxFeet.y && exit.peek.y > exit.start.y)
        #expect(DepthOrder.z(forFeetY: exit.start.y) < DepthOrder.z(forFeetY: boxFeet.y), "el frente lo tapa")
        #expect(DepthOrder.z(forFeetY: exit.peek.y) < DepthOrder.z(forFeetY: boxFeet.y))
        #expect(exit.peek.y < rimY, "los pies no pasan el borde mientras asoma")
    }

    @Test("arranca escondido debajo del borde y al salir se estira")
    func startsHiddenAndStretches() {
        let body = 72 * StageLayout.employeeSideRatio * StageLayout.employeeCanvasBodyRatio
        #expect(body * BoxExitPath.hiddenYScale < rimY - boxFeet.y, "la cabeza no asoma antes de subir")
        #expect(BoxExitPath.stretchYScale > 1 && BoxExitPath.stretchXScale < 1)
        #expect(BoxExitPath.squashXScale > 1 && BoxExitPath.squashYScale < 1, "al aterrizar se aplasta")
    }

    @Test("salta en arco al costado de la caja, del lado de su lugar, y aterriza delante de su línea")
    func jumpsBesideTheBox() {
        for target in [CGPoint(x: 300, y: 150), CGPoint(x: 20, y: 150)] {
            let exit = path(to: target)
            #expect(abs(exit.landing.x - boxFeet.x) >= boxWidth * 0.9, "aterriza al lado, no adentro")
            #expect((exit.landing.x > boxFeet.x) == (target.x > boxFeet.x), "salta hacia su lugar")
            #expect(exit.landing.y < boxFeet.y, "delante de la caja")
            #expect(DepthOrder.z(forFeetY: exit.landing.y) > DepthOrder.z(forFeetY: boxFeet.y))
            #expect(exit.jumpPoint(at: 0) == exit.peek)
            let landed = exit.jumpPoint(at: 1)
            #expect(abs(landed.x - exit.landing.x) < 0.001 && abs(landed.y - exit.landing.y) < 0.001)
            let top = exit.jumpPoint(at: 0.5)
            #expect(abs(top.y - exit.apexY) < 0.001)
            #expect(exit.apexY > exit.peek.y && exit.apexY > exit.landing.y, "el arco sube antes de caer")
        }
    }

    @Test("con Reduce Motion el fundido dura poco: aparece al lado y enseguida está en su lugar")
    func reduceMotionIsQuick() {
        #expect(BoxExitPath.fadeSeconds * 2 + BoxExitPath.holdSeconds < 1.5)
    }
}
