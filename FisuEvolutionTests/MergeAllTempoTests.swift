import Testing
@testable import FisuEvolution

@Suite("Fusionar todo: el tempo de la cadena")
@MainActor
struct MergeAllTempoTests {
    let tempo = MergeAllTempo(reduceMotion: false)

    @Test("el primer eslabón entra como cualquier cambio; los siguientes, casi sin pausa")
    func onlyTheFirstLinkWaits() {
        #expect(tempo.leadIn(index: 0, travels: false) == MergeAllTempo.firstBeat)
        #expect(tempo.leadIn(index: 0, travels: true) >= BoardScene.flightDuration(floors: 9, totalFloors: 10))
        #expect(tempo.leadIn(index: 1, travels: false) < 0.1)
        #expect(tempo.leadIn(index: 3, travels: true) >= BoardScene.flightDuration(floors: 9, totalFloors: 10),
                "si el jugador se fue de piso a mitad de cadena, se vuelve volando")
    }

    @Test("siete eslabones sin reveals entran en 3,5 s, y el primero es el más lento")
    func sevenLinksFitTheBudget() {
        let total = (0..<7).map { tempo.linkDuration(index: $0) }.reduce(0, +)
        #expect(total <= 3.5)
        #expect(tempo.linkDuration(index: 0) > tempo.linkDuration(index: 1))
        #expect(tempo.beat(index: 1) < 0.35, "más rápido que el destaque de un cambio suelto")
        #expect(tempo.slide(index: 1) <= 0.18)
    }

    @Test("el tono sube eslabón a eslabón y se planta en el techo")
    func pitchClimbsAndCaps() {
        #expect(tempo.pitch(index: 0) == 1)
        #expect(tempo.pitch(index: 1) > tempo.pitch(index: 0))
        #expect(tempo.pitch(index: 30) == MergeAllTempo.maxPitch)
        #expect((0..<30).map(tempo.pitch).allSatisfy { $0 <= MergeAllTempo.maxPitch })
    }

    @Test("con Reduce Motion, sin pausas ni deslizamiento")
    func reduceMotionCollapses() {
        let calm = MergeAllTempo(reduceMotion: true)
        #expect(calm.leadIn(index: 0, travels: true) <= 0.2)
        #expect(calm.slide(index: 0) <= 0.01)
        #expect((0..<7).map { calm.linkDuration(index: $0) }.reduce(0, +) <= 1.5)
    }
}
