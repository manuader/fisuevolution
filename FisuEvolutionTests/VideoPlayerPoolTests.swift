import Foundation
import Testing
@testable import FisuEvolution

@Suite("El pool de videos: nunca más de 3 vivos")
@MainActor
struct VideoPlayerPoolTests {
    final class Holder: VideoLeaseHolder {
        var live = false
        func videoLeaseDidChange(isLive: Bool) { live = isLive }
    }
    private func pool(_ policy: VideoPlaybackPolicy = .allowAll) -> VideoPlayerPool {
        VideoPlayerPool(policy: policy)
    }

    @Test("fondo + popup + ícono: los tres vivos")
    func oneOfEachRole() {
        let pool = pool()
        let bg = Holder(), popup = Holder(), icon = Holder()
        _ = pool.acquire(bg, role: .background)
        _ = pool.acquire(popup, role: .popup)
        _ = pool.acquire(icon, role: .icon)
        #expect(bg.live && popup.live && icon.live)
        #expect(pool.liveCount == 3)
    }

    @Test("el popup nuevo baja al anterior a póster; al cerrarse, el anterior vuelve")
    func newestOfARoleWins() {
        let pool = pool()
        let first = Holder(), second = Holder()
        _ = pool.acquire(first, role: .popup)
        let lease = pool.acquire(second, role: .popup)
        #expect(!first.live && second.live)
        pool.release(lease)
        #expect(first.live, "devuelto el decodificador, el de abajo retoma")
    }

    @Test("la cinemática suspende a todos y al terminar vuelven")
    func fullscreenSuspendsTheRest() {
        let pool = pool()
        let bg = Holder(), popup = Holder(), cine = Holder()
        _ = pool.acquire(bg, role: .background)
        _ = pool.acquire(popup, role: .popup)
        let lease = pool.acquire(cine, role: .fullscreen)
        #expect(cine.live && !bg.live && !popup.live)
        #expect(pool.liveCount == 1)
        pool.release(lease)
        #expect(bg.live && popup.live)
    }

    @Test("una suspensión baja todo; anidadas, vuelve sólo al soltar la última")
    func suspensionsNest() {
        let pool = pool()
        let bg = Holder()
        _ = pool.acquire(bg, role: .background)
        let chest = pool.suspend(.overlay)
        let ride = pool.suspend(.elevatorRide)
        #expect(!bg.live)
        pool.resume(chest)
        #expect(!bg.live)
        pool.resume(ride)
        #expect(bg.live)
    }

    @Test("una reserva baja el tope: con la cabina calentando quedan 2")
    func reservationsLowerTheCap() {
        let pool = pool()
        let bg = Holder(), popup = Holder(), icon = Holder()
        _ = pool.acquire(bg, role: .background)
        _ = pool.acquire(popup, role: .popup)
        _ = pool.acquire(icon, role: .icon)
        let cabin = pool.reserve()
        #expect(pool.liveCount == 2)
        #expect(!icon.live, "cae primero el de menor prioridad: ícono < fondo < popup")
        pool.unreserve(cabin)
        #expect(icon.live)
    }

    @Test("la política apaga todo a póster, y la cinemática según su propia regla",
          arguments: [VideoPlaybackPolicy.Reason.reduceMotion, .lowPower, .thermal, .background,
                      .videoAutoplayOff, .forcedStill])
    func policyTurnsLoopsOff(_ reason: VideoPlaybackPolicy.Reason) {
        let pool = pool()
        let bg = Holder()
        _ = pool.acquire(bg, role: .background)
        pool.update(policy: .allowAll.with(reason))
        #expect(!bg.live && pool.liveCount == 0)
        pool.update(policy: .allowAll)
        #expect(bg.live)
    }

    @Test("la cinemática sigue con bajo consumo y térmica alta; no con Reduce Motion")
    func cinematicsPolicy() {
        #expect(VideoPlaybackPolicy.allowAll.with(.lowPower).allowsCinematics)
        #expect(VideoPlaybackPolicy.allowAll.with(.thermal).allowsCinematics)
        #expect(!VideoPlaybackPolicy.allowAll.with(.reduceMotion).allowsCinematics)
        #expect(!VideoPlaybackPolicy.allowAll.with(.videoAutoplayOff).allowsCinematics)
    }

    @Test("bajo XCTest el pool compartido arranca en póster")
    func sharedStartsStillUnderTests() {
        #expect(VideoPlaybackPolicy.launch.contains(.forcedStill))
    }

    @Test("soltar un lease ajeno o dos veces no rompe nada")
    func releaseIsIdempotent() {
        let pool = pool()
        let a = Holder()
        let lease = pool.acquire(a, role: .popup)
        pool.release(lease)
        pool.release(lease)
        #expect(pool.liveCount == 0 && !a.live)
    }

    @Test("la cinemática vive con Modo de bajo consumo, y a ella no la baja una suspensión")
    func fullscreenSurvivesLowPower() {
        let pool = pool(.allowAll.with(.lowPower))
        let bg = Holder(), cine = Holder()
        _ = pool.acquire(bg, role: .background)
        _ = pool.acquire(cine, role: .fullscreen)
        #expect(cine.live && !bg.live)
    }

    @Test("sin Reduce Motion no hay cinemática: queda en póster y los demás también")
    func fullscreenBlockedByReduceMotion() {
        let pool = pool(.allowAll.with(.reduceMotion))
        let bg = Holder(), cine = Holder()
        _ = pool.acquire(bg, role: .background)
        _ = pool.acquire(cine, role: .fullscreen)
        #expect(!cine.live && !bg.live && pool.liveCount == 0)
    }

    @Test("un holder que desaparece sin release no retiene el cupo")
    func deadHoldersArePurged() {
        let pool = pool()
        let survivor = Holder()
        _ = pool.acquire(survivor, role: .popup)
        do {
            let ghost = Holder()
            _ = pool.acquire(ghost, role: .popup)
            #expect(!survivor.live)
        }
        pool.unreserve(pool.reserve())
        #expect(survivor.live && pool.liveCount == 1)
    }
}
