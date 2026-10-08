import SwiftUI

/// La franja de arriba de FisuJobs y Mejoras mientras dura el Corralito: las
/// hojas tapan el aviso del HUD, así que el motivo tiene que estar acá.
struct SpendingFrozenStrip: View {
    let until: TimeInterval
    let identifier: String

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let left = max(0, Int((until - context.date.timeIntervalSince1970).rounded(.up)))
            StateBadge(
                text: String(localized: "spending.frozen.strip \(String(left))"),
                systemImage: "lock.fill",
                textAlignment: .center,
                muted: false
            )
        }
        .accessibilityElement(children: .combine)
        .background(Color.clear.accessibilityElement().accessibilityIdentifier(identifier))
    }
}
