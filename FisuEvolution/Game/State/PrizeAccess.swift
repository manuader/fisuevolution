import Foundation

/// Lo que dicen los accesos a los premios —los chips de hoy, la columna lateral
/// de E7b—: cuántos paquetes esperan, si ninguno entra, si hay colchón y
/// cuántos giros hay sin pagar. Publicado a 8 Hz porque `player` no se observa.
struct PrizeAccess: Equatable {
    var packagesWaiting = 0
    var packagesBlocked = false
    var mattressReady = false
    var wheelSpinsReady = 0

    static let none = PrizeAccess()
}

/// El popup del colchón; `outcome` es lo que salió, cuando ya se abrió.
struct MattressPopup: Identifiable, Equatable {
    let id = UUID()
    var outcome: MattressOutcome?
}

/// La ruleta presentada sobre el tablero (un chip, la columna, el Conductor).
/// Desde Regalos se empuja y no pasa por acá.
struct WheelSheet: Identifiable, Equatable {
    let id = UUID()
}
