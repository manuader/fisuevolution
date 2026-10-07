import SwiftUI
import UIKit

/// Las safe areas de la PANTALLA, observables (PLAN-v2 E3).
///
/// Reemplaza las dos lecturas que `HUDView` y `GameTabBar` hacían en su
/// `onAppear`: eran una foto del arranque, y en iPad —o con el SDK de iOS 27,
/// cuando la app deje de ser de pantalla completa— el inset puede cambiar en
/// pleno juego.
///
/// ⚠️ Se sigue leyendo de la ventana y no con un `GeometryReader`: adentro del
/// juego la safe area ya la consumió `RootView`, y un proxy reporta 0 en todos
/// los teléfonos.
@MainActor
@Observable
final class ScreenInsets {
    static let shared = ScreenInsets()

    /// Arrancan en los de un teléfono con notch: el valor real llega con el
    /// primer aviso de la sonda, y arrancar en 0 haría saltar el HUD 12 pt en
    /// el caso común.
    private(set) var top: CGFloat
    private(set) var bottom: CGFloat

    init(top: CGFloat = 44, bottom: CGFloat = 34) {
        self.top = top
        self.bottom = bottom
    }

    func update(top: CGFloat, bottom: CGFloat) {
        if self.top != top { self.top = top }
        if self.bottom != bottom { self.bottom = bottom }
    }

    /// Cuánto aire agregar para que algo pegado a un borde físico no quede a
    /// menos de `minimum` del bezel cuando el inset de ese borde es chico (en el
    /// SE, con la barra de estado oculta, los dos son 0).
    nonisolated static func floorGap(minimum: CGFloat, inset: CGFloat) -> CGFloat {
        max(0, minimum - inset)
    }
}

/// La sonda que mantiene al día `ScreenInsets.shared`. Va UNA vez, de fondo del
/// HUD, que está montado siempre que hay tablero; lo único que hace es instalar
/// el `WindowSentinel` en su ventana.
///
/// ⚠️ La sonda NO publica por su cuenta: con `statusBarHidden(true)` el inset de
/// la ventana cambia DESPUÉS de `didMoveToWindow` (20 → 0 en el SE, 32 → 0 en el
/// iPad) y a una vista metida en la jerarquía de SwiftUI no le llega aviso.
/// Medido en el spike S4 sobre cuatro dispositivos: publicando desde la sonda el
/// HUD quedaba pegado en el valor viejo en 5 de 9 arranques.
struct ScreenInsetsReader: UIViewRepresentable {
    func makeUIView(context: Context) -> Probe {
        let probe = Probe()
        probe.isUserInteractionEnabled = false
        probe.isAccessibilityElement = false
        return probe
    }

    func updateUIView(_ uiView: Probe, context: Context) {}

    final class Probe: UIView {
        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard let window else { return }
            WindowSentinel.install(in: window)
        }
    }
}

/// Una `UIView` común agregada directo a la ventana y del tamaño de la ventana:
/// su safe area ES la de la ventana, y UIKit le avisa cada cambio. Publica de
/// forma sincrónica, sin `Task` (9 de 9 arranques en el spike S4).
final class WindowSentinel: UIView {
    static let tag = 0x5E17

    /// Una sola por ventana: la sonda corre `didMoveToWindow` cada vez que el HUD
    /// se vuelve a montar.
    static func install(in window: UIWindow) {
        guard window.viewWithTag(tag) == nil else { return }
        let sentinel = WindowSentinel(frame: window.bounds)
        sentinel.tag = tag
        sentinel.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        sentinel.isUserInteractionEnabled = false
        sentinel.isAccessibilityElement = false
        window.insertSubview(sentinel, at: 0)
        sentinel.publish()
    }

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        publish()
    }

    private func publish() {
        guard let window else { return }
        let insets = window.safeAreaInsets
        ScreenInsets.shared.update(top: insets.top, bottom: insets.bottom)
    }
}
