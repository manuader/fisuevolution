import Testing
@testable import FisuEvolution

/// La botonera del ascensor (PLAN-v2 E3): qué botón va dónde, cuál está "en
/// marcha" y cuánto brilla cada uno con la cámara en camino.
@Suite("La botonera del ascensor")
struct ElevatorPanelModelTests {
    /// El mapa viene de Dios para abajo, como lo arma `GameState.floorMap`.
    private func map(_ floors: [(id: String, occupied: Int, capacity: Int, unlocked: Bool)]) -> [FloorMapEntry] {
        floors.enumerated().map { index, floor in
            FloorMapEntry(
                id: floor.id,
                ordinal: floors.count - 1 - index,
                backgroundKey: "bg_\(floor.id)",
                occupied: floor.occupied,
                capacity: floor.capacity,
                isUnlocked: floor.unlocked,
                isVisible: false
            )
        }
    }

    @Test("los botones van de arriba abajo y numerados desde el callejón")
    func floorsGoTopDownNumberedFromTheAlley() {
        let model = ElevatorPanelModel(map: map([
            ("corporate", 0, 10, false),
            ("urban", 4, 10, true),
            ("alley", 10, 10, true),
        ]))
        #expect(model.floors.map(\.id) == ["corporate", "urban", "alley"])
        #expect(model.floors.map(\.number) == [3, 2, 1])
    }

    @Test("un piso está en marcha con todos sus lugares ocupados, y nunca si está cerrado")
    func staffedMeansFullAndOpen() {
        let model = ElevatorPanelModel(map: map([
            ("corporate", 10, 10, false),
            ("urban", 9, 10, true),
            ("alley", 10, 10, true),
        ]))
        #expect(model.floors.map(\.isStaffed) == [false, false, true])
        #expect(model.floors.map(\.isUnlocked) == [false, true, true])
    }

    @Test("la luz viaja suave: 1 en el piso, la mitad a medio camino, 0 a un piso")
    func glowFollowsTheCamera() {
        #expect(ElevatorPanelModel.glow(forOrdinal: 2, cameraFloor: 2) == 1)
        #expect(abs(ElevatorPanelModel.glow(forOrdinal: 2, cameraFloor: 2.5) - 0.5) < 0.0001)
        #expect(abs(ElevatorPanelModel.glow(forOrdinal: 3, cameraFloor: 2.5) - 0.5) < 0.0001)
        #expect(ElevatorPanelModel.glow(forOrdinal: 2, cameraFloor: 3.2) == 0)
    }
}
