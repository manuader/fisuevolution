import Testing
@testable import FisuEvolution

/// La música por piso (PLAN-v2 §5) es un tema por piso con un crossfade de
/// 1,5 s, y lo que la puede arruinar es el jugador: el mismo piso
/// re-disparando el tema, o un scroll rápido que deja cuatro temas sonando a
/// la vez. Eso lo decide `FloorMusicDirector`, que es puro, así que se
/// prueba sin parlantes.
@Suite("Música por piso")
struct FloorMusicDirectorTests {
    private let alley = "music_alley_loop"
    private let urban = "music_urban_loop"
    private let corporate = "music_corporate_loop"

    @Test("cada piso de economy.json tiene su tema con el nombre que escribe el generador")
    func floorMapsToItsTrack() {
        #expect(FloorMusicDirector.track(forFloor: "alley") == alley)
        #expect(FloorMusicDirector.track(forFloor: "god_realm") == "music_god_realm_loop")
    }

    @Test("el primer piso entra desde silencio")
    func firstFloorFadesIn() {
        var director = FloorMusicDirector()
        let steps = director.show(floor: "alley")
        #expect(steps == [.fadeIn(alley)])
        #expect(director.voices == [alley])
    }

    @Test("el mismo piso no re-dispara el tema")
    func sameFloorDoesNotRetrigger() {
        var director = FloorMusicDirector()
        _ = director.show(floor: "alley")
        let steps = director.show(floor: "alley")
        #expect(steps.isEmpty)
        #expect(director.voices == [alley])
    }

    @Test("cambiar de piso es un crossfade: entra el nuevo y se va el viejo")
    func changingFloorsCrossfades() {
        var director = FloorMusicDirector()
        _ = director.show(floor: "alley")
        let steps = director.show(floor: "urban")
        #expect(steps == [
            .fadeOut(.init(track: alley, turn: 1)),
            .fadeIn(urban),
        ])
        #expect(director.voices == [urban, alley])
    }

    @Test("un cambio en medio de un fundido corta al que se iba en vez de apilar un tercero")
    func rapidChangesDoNotStackFades() {
        var director = FloorMusicDirector()
        _ = director.show(floor: "alley")
        _ = director.show(floor: "urban")
        let steps = director.show(floor: "corporate")
        #expect(steps == [
            .cut(alley),
            .fadeOut(.init(track: urban, turn: 2)),
            .fadeIn(corporate),
        ])
        #expect(director.voices == [corporate, urban])
    }

    @Test("recorrer la torre entera de un tirón nunca deja más de dos temas")
    func sweepingTheTowerKeepsTwoVoices() {
        let floors = ["alley", "urban", "corporate", "luxury", "island",
                      "moon", "mars", "solar", "galaxy", "god_realm"]
        var director = FloorMusicDirector()
        for floor in floors + floors.reversed() {
            _ = director.show(floor: floor)
            #expect(director.voices.count <= 2)
        }
        #expect(director.voices == [alley, urban])
    }

    @Test("volver al piso que se iba da vuelta el fundido sin recargar el tema")
    func returningRestoresWithoutReloading() {
        var director = FloorMusicDirector()
        _ = director.show(floor: "alley")
        _ = director.show(floor: "urban")
        let steps = director.show(floor: "alley")
        #expect(steps == [
            .fadeOut(.init(track: urban, turn: 2)),
            .restore(alley),
        ])
        #expect(director.voices == [alley, urban])
    }

    @Test("el fin de un fundido viejo no corta al tema que volvió a mandar")
    func staleExitDoesNotStopTheLead() {
        var director = FloorMusicDirector()
        _ = director.show(floor: "alley")
        _ = director.show(floor: "urban")
        _ = director.show(floor: "alley")
        // Se fue a la ciudad y volvió: el aviso del fundido del callejón
        // llega recién ahora. (`#expect` no acepta un método `mutating`
        // adentro: el resultado va a una constante.)
        let stopsAlley = director.exitFinished(.init(track: alley, turn: 1))
        #expect(!stopsAlley, "el callejón manda de nuevo")
        #expect(director.voices == [alley, urban])

        let stopsUrban = director.exitFinished(.init(track: urban, turn: 2))
        #expect(stopsUrban)
        #expect(director.voices == [alley])
    }

    @Test("dos salidas del mismo tema se distinguen por el turno")
    func exitsOfTheSameTrackAreDistinct() {
        var director = FloorMusicDirector()
        _ = director.show(floor: "alley")
        _ = director.show(floor: "urban")   // sale el callejón (turno 1)
        _ = director.show(floor: "alley")   // vuelve; sale la ciudad (turno 2)
        _ = director.show(floor: "urban")   // vuelve; sale el callejón (turno 3)

        let stopsOnFirstExit = director.exitFinished(.init(track: alley, turn: 1))
        #expect(!stopsOnFirstExit, "el aviso del primer fundido llega con el tercero a la mitad")
        let stopsOnThirdExit = director.exitFinished(.init(track: alley, turn: 3))
        #expect(stopsOnThirdExit)
        #expect(director.voices == [urban])
    }
}
