import EconomyKit
import Foundation

/// Los accesos al Paquete, al Colchón y a la Ruleta (PLAN-v2 E5): qué dicen y
/// qué hacen al tocarlos. Los tocan los chips, las cajas del tablero y —con
/// E7b— la columna lateral, todos por acá.
extension GameState {
    func refreshPrizeAccess(now: TimeInterval = Date().timeIntervalSince1970) {
        let wheel = wheelAvailability(storefrontAllows: false, now: now)
        let access = PrizeAccess(
            packagesWaiting: packagesWaiting,
            packagesBlocked: packagesBlocked,
            mattressReady: mattressWaiting,
            wheelSpinsReady: wheel.bonus + wheel.videoLeft
        )
        if prizeAccess != access { prizeAccess = access }
    }

    /// El chip o una caja del tablero.
    @discardableResult
    func packageTapped() -> PackageOpenResult {
        let result = openPackage()
        refreshPrizeAccess()
        return result
    }

    /// El chip o el colchón del tablero: abre su popup.
    func mattressTapped() {
        guard mattressWaiting, mattressPopup == nil, wheelSheet == nil else { return }
        mattressPopup = MattressPopup()
    }

    /// Terminó el video del colchón: lo que salió queda en el popup. Sólo el
    /// primero cuenta: un video que termina con el resultado ya a la vista no
    /// abre otro colchón (que pudo haber aparecido mientras tanto).
    func mattressVideoWatched() {
        guard mattressPopup?.outcome == nil, mattressPopup != nil, let outcome = openMattress() else { return }
        mattressPopup?.outcome = outcome
        refreshPrizeAccess()
    }

    /// Terminó el segundo video: "otro colchón".
    func extraMattressVideoWatched() {
        guard mattressPopup?.outcome != nil, let outcome = openExtraMattress() else { return }
        mattressPopup?.outcome = outcome
    }

    func closeMattressPopup() {
        mattressPopup = nil
    }

    /// Sólo con el tablero en calma: si algo más tapa la pantalla (un momento
    /// para compartir, una pausa, el menú) la hoja no se vería y trabaría
    /// `isBoardBusy`. Los giros ya están en `bonusSpins`: quedan para Regalos.
    func openWheel() {
        guard wheelSheet == nil, mattressPopup == nil, !isBoardBusy else { return }
        wheelSheet = WheelSheet()
    }

    func closeWheel() {
        wheelSheet = nil
    }

    /// El popup de un visitante terminó de irse. Si su premio fue un giro (el
    /// Conductor de TV: "abre la ruleta y da +1 giro", Anexo A), la ruleta se
    /// abre ahora, con la hoja anterior ya cerrada.
    func visitorPopupDismissed() {
        guard wheelOpensAfterVisit else { return }
        wheelOpensAfterVisit = false
        openWheel()
    }
}
