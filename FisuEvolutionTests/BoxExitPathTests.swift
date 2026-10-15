import CoreGraphics
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

    @Test("termina en su lugar de la hilera, después de aterrizar")
    func endsOnItsSlot() {
        let slot = CGPoint(x: 260, y: 180)
        let exit = path(to: slot)
        #expect(exit.target == slot)
        #expect(exit.walkSeconds >= BoxExitPath.minWalkSeconds)
        #expect(exit.jumpStart < exit.landingTime)
        #expect(abs(exit.totalSeconds - (exit.landingTime + BoxExitPath.squashSeconds + exit.walkSeconds)) < 0.0001)
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
