import Testing
import CoreGraphics
@testable import FisuEvolution

@Suite("La placa colgante del ascensor")
struct ElevatorKeypadModelTests {
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

    @Test("un botón por piso abierto, del más alto arriba, numerados desde el callejón")
    func onlyUnlockedFloorsTopDown() {
        let model = ElevatorKeypadModel(map: map([
            ("corporate", 0, 10, false), ("urban", 4, 10, true), ("alley", 10, 10, true),
        ]), visibleOrdinal: 1)
        #expect(model.floors.map(\.id) == ["urban", "alley"])
        #expect(model.floors.map(\.number) == [2, 1])
        #expect(model.floors.map(\.isCurrent) == [true, false])
    }

    @Test("la placa crece con los pisos abiertos, de 1 a 10")
    func growsWithTheTower() {
        let ids = ["god_realm", "galaxy", "solar", "mars", "moon", "island", "luxury", "corporate", "urban", "alley"]
        for open in 1...10 {
            let floors = ids.enumerated().map { index, id in (id, 0, 10, index >= ids.count - open) }
            let model = ElevatorKeypadModel(map: map(floors), visibleOrdinal: 0)
            #expect(model.floors.count == open)
        }
        #expect(ElevatorKeypadModel.maxButtons == 10)
    }

    @Test("diez botones entran en el SE entre el HUD y la barra, y nunca bajan de 34 ni pasan de 46")
    func tenButtonsFitTheSE() {
        let available: CGFloat = 667 - 80 - 84 - 12 - 8
        let side = ElevatorKeypadLayout.buttonSide(count: 10, availableHeight: available)
        #expect(side >= 34)
        #expect(ElevatorKeypadLayout.plateSize(count: 10, buttonSide: side).height
                + ElevatorKeypadLayout.springHeight <= available)
        #expect(ElevatorKeypadLayout.buttonSide(count: 2, availableHeight: 2000) == 46)
        #expect(ElevatorKeypadLayout.buttonSide(count: 10, availableHeight: 100) == 34)
    }
}
