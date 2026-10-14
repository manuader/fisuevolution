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
            wheelSpinsReady: wheel.bonus + wheel.videoLeft,
            mattressExtraReady: mattressExtraPending,
            mattressOnBoard: mattressOnBoard
        )
        if prizeAccess != access { prizeAccess = access }
    }

    /// La columna: abre su popup (D5). El de la columna pide su video; uno ya abierto ofrece el
    /// «otro colchón». El que está en el tablero se abre ahí (`boardMattressTapped`).
    func mattressTapped() {
        guard mattressWaiting || mattressExtraPending, mattressPopup == nil, wheelSheet == nil, packagePopup == nil else { return }
        if mattressWaiting { tutorialTipCompleted(.mattress) }
        mattressPopup = MattressPopup(extraOnly: !mattressWaiting)
    }

    /// Terminó el video del colchón de la columna (E14b B6, D3): se cierra el popup y el colchón cae
    /// al tablero, todavía cerrado. Sólo el primer aviso cuenta: uno repetido no paga otro colchón.
    func mattressVideoWatched() {
        guard let popup = mattressPopup, popup.outcome == nil, !popup.extraOnly, payMattress() else { return }
        mattressPopup = nil
        refreshPrizeAccess()
    }

    /// El colchón del tablero se tocó: `true` si la escena puede abrirlo ahí (con la pantalla libre).
    /// Todavía no gasta nada: se abre cuando termina la animación (`openMattressOnBoard`).
    func boardMattressTapped() -> Bool {
        mattressOnBoard && mattressPopup == nil && wheelSheet == nil && packagePopup == nil
    }

    /// Terminó de abrirse en el tablero: sortea, acredita y sale el pop-up del premio, siempre (D3).
    @discardableResult
    func openMattressOnBoard() -> MattressOutcome? {
        guard boardMattressTapped(), let outcome = openMattress() else { return nil }
        mattressPopup = MattressPopup(openedOnBoard: true, outcome: outcome)
        refreshPrizeAccess()
        scheduleSave()
        return outcome
    }

    /// Terminó el segundo video: "otro colchón".
    func extraMattressVideoWatched() {
        guard let popup = mattressPopup, popup.outcome != nil || popup.extraOnly,
              let outcome = openExtraMattress() else { return }
        mattressPopup?.openedOnBoard = false
        mattressPopup?.outcome = outcome
        refreshPrizeAccess()
        scheduleSave()
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
