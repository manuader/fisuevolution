#if DEBUG
import EconomyKit
import SwiftUI

/// Herramientas de balance y QA. Solo existe en builds Debug — jamás shippea,
/// por eso sus strings no pasan por el String Catalog.
struct DebugPanelView: View {
    @Environment(GameState.self) private var gameState
    @Environment(\.dismiss) private var dismiss
    @State private var timeWarpOn = false
    @State private var knobs = EconomyKnobs()
    private let probe = FrameRateProbe.shared

    /// Los pares (g, r) del plan: v1, y tres que dejan ~6 % por compra al que
    /// fusiona y cobran más al que acumula. El callejón conserva su 1,03.
    private static let curves: [(name: String, growth: Double?, refund: Double?)] = [
        ("v1", nil, nil),
        ("1,08 · 0,5", 1.08, 0.5),
        ("1,12 · 1", 1.12, 1),
        ("1,12 · 2", 1.12, 2),
    ]

    private var curveBinding: Binding<Int> {
        Binding(
            get: {
                Self.curves.firstIndex { $0.growth == knobs.defaultCostGrowth && $0.refund == knobs.mergeRefundCounts } ?? 0
            },
            set: { index in
                knobs.defaultCostGrowth = Self.curves[index].growth
                knobs.mergeRefundCounts = Self.curves[index].refund
                gameState.debugApplyEconomyKnobs(knobs, defaults: .standard)
            }
        )
    }

    private func knobToggle<Value: Equatable>(_ path: WritableKeyPath<EconomyKnobs, Value?>, on value: Value) -> Binding<Bool> {
        Binding(
            get: { knobs[keyPath: path] == value },
            set: { isOn in
                knobs[keyPath: path] = isOn ? value : nil
                gameState.debugApplyEconomyKnobs(knobs, defaults: .standard)
            }
        )
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Economía") {
                    Button("+ Monedas (1M o costo de spawn ×100)") {
                        gameState.debugGrantCoins()
                    }
                    Button("Invocar par del tier máximo") {
                        gameState.debugGrantPair()
                    }
                    Toggle("Time-warp ×60", isOn: $timeWarpOn)
                        .onChange(of: timeWarpOn) { _, on in
                            gameState.debugTimeScale = on ? 60 : 1
                        }
                }
                Section("Offline") {
                    Button("Simular 4 h offline") {
                        gameState.debugSimulateOffline(hours: 4)
                    }
                }
                // La misma carta que reabre el long-press sobre el personaje
                // del tablero, sin pelear el gesto: es la puerta de los tests
                // (precedente `--uitest-open-sheet`: los gestos del tablero no
                // se automatizan por coordenada) y sirve para mirar el
                // beneficio sin puntería.
                if let special = gameState.visibleFloorSpecials.first {
                    Section("Specials") {
                        Button("Carta del special activo") {
                            gameState.presentSpecialInfo(id: special.id)
                            dismiss()
                        }
                        .accessibilityIdentifier("debug.special.info")
                    }
                }
                // Un cofre abierto de una, con su animación. La vía real —cada
                // dos pisos, un video, el día 7— es media hora de partida por
                // cofre, así que sin esto la animación no se puede mirar dos
                // veces seguidas para juzgarla.
                Section("Cofres") {
                    Button("Abrir un cofre") {
                        gameState.debugOpenChest()
                        dismiss()
                    }
                    .accessibilityIdentifier("debug.chest.open")
                    // El de arriba aterriza directo en la animación; éste deja
                    // el cofre GUARDADO, que es lo que hace falta para recorrer
                    // el camino del jugador entero: el puntito de la pestaña, la
                    // tarjeta de Regalos y el botón que la abre.
                    Button("Regalar un cofre (sin abrir)") {
                        gameState.debugAwardChest()
                        dismiss()
                    }
                    .accessibilityIdentifier("debug.chest.award")
                }
                // La ficha con un segundo Fisura en la torre: el fixture
                // `--uitest-open-sheet` la abre sobre el único de una partida
                // nueva, que no se puede despedir.
                Section("Ficha") {
                    Button("Abrir la ficha (con otro para despedir)") {
                        gameState.debugGrantCoins()
                        if let base = gameState.content?.tiers.baseType.id {
                            gameState.hireCharacter(typeId: base)
                        }
                        if let slot = gameState.visiblePlacements.first?.slot {
                            gameState.presentCharacterSheet(cellIndex: slot)
                        }
                        dismiss()
                    }
                    .accessibilityIdentifier("debug.sheet.open")
                }
                Section("Atajo") {
                    // El piso visible lleno con Fisuras: el atajo tiene que
                    // quedarse y decir "Piso lleno".
                    Button("Llenar el piso visible") {
                        gameState.debugGrantCoins()
                        if let base = gameState.content?.tiers.baseType.id {
                            var guardrail = 0
                            while gameState.visibleFloorOccupancy.occupied < gameState.visibleFloorOccupancy.capacity,
                                  guardrail < 30 {
                                gameState.hireCharacter(typeId: base)
                                guardrail += 1
                            }
                        }
                        dismiss()
                    }
                    .accessibilityIdentifier("debug.floor.fill")
                    // Varios contratables a la vez, para que el selector tenga
                    // a quién fijar (el escenario de `QuickHireOfferTests`).
                    Button("Varios contratables (frontera 18)") {
                        gameState.debugUnlockFloors(throughTier: 13)
                        gameState.debugMarkTypesSeen(throughTier: 12)
                        gameState.debugSetMaxTier(18)
                        gameState.debugGrantCoins()
                        dismiss()
                    }
                    .accessibilityIdentifier("debug.quickhire.many")
                }
                Section("Compartir") {
                    Button("Ofrecer compartir (piso nuevo)") {
                        gameState.debugOfferShareMoment()
                        dismiss()
                    }
                    .accessibilityIdentifier("debug.share.offer")
                }
                // ⚠️ Va DESPUÉS de las puertas de los tests (Specials, Cofres,
                // Ficha): la List es perezosa y una fila bajo el pliegue no existe
                // para XCUITest, así que crecer por arriba las deja sin tap.
                // El selector del dueño (PLAN-v2 §2, "Precios"): la curva y el
                // reintegro se prueban en pares; "v1" es lo que shippea hoy.
                Section("Economía 2.0 (E2a)") {
                    Picker("Curva · reintegro", selection: curveBinding) {
                        ForEach(Self.curves.indices, id: \.self) { index in
                            Text(Self.curves[index].name).tag(index)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("debug.e2a.curve")
                    Toggle("Amortiguador (K = 24)", isOn: knobToggle(\.priceReliefPurchases, on: 24))
                        .accessibilityIdentifier("debug.e2a.cushion")
                    Toggle("Pisos en marcha (+5 %)", isOn: knobToggle(\.staffedFloorBonus, on: 0.05))
                        .accessibilityIdentifier("debug.e2a.staffed")
                    Toggle("Piso móvil", isOn: knobToggle(\.requiresLastRunWall, on: true))
                        .accessibilityIdentifier("debug.e2a.wall")
                    Button("Fusionar todo (piso visible)") {
                        gameState.debugMergeAllOnVisibleFloor()
                        dismiss()
                    }
                    .accessibilityIdentifier("debug.e2a.mergeAll")
                }
                // Las cinemáticas, a demanda y sin mirar si le tocan: se anotan vistas igual.
                Section("Cinemáticas") {
                    ForEach(CinematicID.allCases.filter { $0 != .intro }, id: \.self) { id in
                        Button("Ver \(id.rawValue)") {
                            gameState.debugPlayCinematic(id)
                            dismiss()
                        }
                        .accessibilityIdentifier("debug.cinematic.\(id.rawValue)")
                    }
                }
                Section("Rendimiento") {
                    Text(probe.line)
                        .font(.system(.footnote, design: .monospaced))
                        .accessibilityIdentifier("debug.probe.line")
                }
                Section("Ranking") {
                    Button("Llegar a Dios (ranking)") {
                        gameState.debugReachGod()
                        dismiss()
                    }
                    .accessibilityIdentifier("debug.ranking.reachGod")
                }
                Section("Eventos") {
                    Menu("Disparar un evento") {
                        ForEach(gameState.content?.events.events ?? []) { event in
                            Button(event.id) { gameState.debugStartEvent(id: event.id) }
                        }
                    }
                    .accessibilityIdentifier("debug.event.start")
                }
                Section("Escenario") {
                    Button("Escenario: que entre alguien") {
                        gameState.debugPresentStageDemo()
                    }
                    .accessibilityIdentifier("debug.stage.demo")
                }
                Section("Peligro") {
                    Button("Resetear partida", role: .destructive) {
                        gameState.debugResetSave()
                        dismiss()
                    }
                }
                // Al final de la lista: los UI tests de otras pantallas scrollean hasta
                // las filas de arriba y no se mueven si la nueva no está en el medio.
                Section("Visitantes") {
                    Menu("Llamar a un visitante") {
                        ForEach(gameState.content?.visitors.scripts ?? []) { script in
                            Button(script.id) { gameState.debugPresentVisitor(scriptId: script.id) }
                        }
                    }
                    .accessibilityIdentifier("debug.visitor.call")
                }
            }
            .navigationTitle("Debug")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            timeWarpOn = gameState.debugTimeScale > 1
            knobs = GameState.storedEconomyKnobs(in: .standard)
            probe.start()
        }
    }
}
#endif
