import Foundation

/// Lo que dicen los accesos a los premios —los chips de hoy, la columna lateral
/// de E7b—: cuántos paquetes esperan, si ninguno entra, si hay colchón y
/// cuántos giros hay sin pagar. Publicado a 8 Hz porque `player` no se observa.
struct PrizeAccess: Equatable {
    var packagesWaiting = 0
    var packagesBlocked = false
    /// En la columna, esperando su video.
    var mattressReady = false
    var wheelSpinsReady = 0
    /// Ya se abrió un colchón y su «otro colchón» sigue sin pedir.
    var mattressExtraReady = false
    /// Pagado, en el tablero (E14b B6).
    var mattressOnBoard = false
    /// El gratis de cada 30 minutos, en el tablero (E14b B31).
    var freeMattressOnBoard = false

    static let none = PrizeAccess()
}

/// El popup del colchón; `outcome` es lo que salió, cuando ya se abrió.
struct MattressPopup: Identifiable, Equatable {
    let id = UUID()
    /// Se abrió desde el «otro colchón» guardado (no hay uno nuevo esperando).
    var extraOnly = false
    /// Se abrió en el tablero con su animación: el premio se ve directo, sin tocar el colchón otra vez.
    var openedOnBoard = false
    var outcome: MattressOutcome?
}

/// La ruleta presentada sobre el tablero (un chip, la columna, el Conductor).
/// Desde Regalos se empuja y no pasa por acá.
struct WheelSheet: Identifiable, Equatable {
    let id = UUID()
}
