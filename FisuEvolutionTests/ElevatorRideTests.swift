import Testing
@testable import FisuEvolution

@Suite("El viaje en cabina")
@MainActor
struct ElevatorRideTests {
    private func seconds(_ d: Duration) -> Double {
        Double(d.components.seconds) + Double(d.components.attoseconds) / 1e18
    }

    @Test("del 1 al 10 entra en 3 s, y un piso solo es más corto")
    func theWholeTowerFitsTheBudget() throws {
        let long = try #require(ElevatorRidePlan(origin: 0, destination: 9, reduceMotion: false, instant: false))
        let short = try #require(ElevatorRidePlan(origin: 0, destination: 1, reduceMotion: false, instant: false))
        #expect(seconds(long.total) <= 3.0)
        #expect(seconds(short.total) < seconds(long.total))
        #expect(long.direction == .up)
        #expect(ElevatorRidePlan(origin: 9, destination: 2, reduceMotion: false, instant: false)?.direction == .down)
    }

    @Test("el viaje nunca dura menos que el vuelo de la cámara: al abrir, ya llegó")
    func travelOutlastsTheCameraFlight() throws {
        for distance in 2...9 {
            let plan = try #require(ElevatorRidePlan(origin: 0, destination: distance, reduceMotion: false, instant: false))
            #expect(seconds(plan.travel) >= BoardScene.flightDuration(floors: distance, totalFloors: 10))
        }
        let hop = try #require(ElevatorRidePlan(origin: 3, destination: 4, reduceMotion: false, instant: false))
        #expect(seconds(hop.travel) >= 0.35, "el salto corto de BoardScene (floorHopDuration)")
    }

    @Test("los pisos del medio pasan más rápido que los de las puntas")
    func middleFloorsPassFaster() throws {
        let plan = try #require(ElevatorRidePlan(origin: 0, destination: 8, reduceMotion: false, instant: false))
        #expect(plan.position(atTravelProgress: 0) == 0)
        #expect(plan.position(atTravelProgress: 1) == 8)
        let start = plan.position(atTravelProgress: 0.1) - plan.position(atTravelProgress: 0)
        let middle = plan.position(atTravelProgress: 0.55) - plan.position(atTravelProgress: 0.45)
        #expect(middle > start)
        #expect(plan.passingOrdinals == Array(0...8))
        #expect(ElevatorRidePlan(origin: 4, destination: 1, reduceMotion: false, instant: false)?.passingOrdinals == [4, 3, 2, 1])
    }

    @Test("al mismo piso no hay viaje; con Reduce Motion son fundidos; bajo los UI tests, cero")
    func degenerateAndAccessibleRides() throws {
        #expect(ElevatorRidePlan(origin: 3, destination: 3, reduceMotion: false, instant: false) == nil)
        let faded = try #require(ElevatorRidePlan(origin: 0, destination: 9, reduceMotion: true, instant: false))
        #expect(faded.fades)
        #expect(seconds(faded.total) < 1.5)
        let instant = try #require(ElevatorRidePlan(origin: 0, destination: 9, reduceMotion: false, instant: true))
        #expect(instant.total == .zero)
    }

    /// Hooks que anotan todo y no duermen de verdad.
    private final class Recorder {
        var jumps: [Int] = []
        var cues: [ElevatorRide.Cue] = []
        var phasesAtJump: [ElevatorRide.Phase] = []
    }

    private func director(_ recorder: Recorder, instant: Bool = false,
                          unlocked: Set<Int> = Set(0...9), visible: Int = 0) -> ElevatorRide {
        let ride = ElevatorRide()
        ride.attach(ElevatorRide.Hooks(
            visibleOrdinal: { visible },
            isUnlocked: { unlocked.contains($0) },
            jump: { [unowned ride] in recorder.jumps.append($0); recorder.phasesAtJump.append(ride.phase) },
            cue: { recorder.cues.append($0) },
            sleep: { _ in await Task.yield() },
            reduceMotion: { false },
            instant: instant
        ))
        return ride
    }

    @Test("elegir un piso de la placa la recoge, cierra, salta al empezar el viaje y abre")
    func selectingRunsTheWholeRide() async {
        let recorder = Recorder()
        let ride = director(recorder)
        ride.openKeypad()
        #expect(ride.isKeypadOpen)
        ride.select(ordinal: 4)
        #expect(!ride.isKeypadOpen)
        await ride.waitUntilIdle()
        #expect(recorder.jumps == [4])
        #expect(recorder.phasesAtJump == [.traveling])
        #expect(recorder.cues == [.keypadOpen, .button, .doorsClose, .motorStart, .motorStop, .ding, .doorsOpen])
        #expect(ride.phase == .idle)
    }

    @Test("un piso cerrado, el mismo piso o un viaje en curso no arrancan otro")
    func ignoredRequests() async {
        let recorder = Recorder()
        let ride = director(recorder, unlocked: [0, 1], visible: 1)
        ride.select(ordinal: 5)
        ride.select(ordinal: 1)
        await ride.waitUntilIdle()
        #expect(recorder.jumps.isEmpty)
        ride.select(ordinal: 0)
        ride.select(ordinal: 0)
        await ride.waitUntilIdle()
        #expect(recorder.jumps == [0])
    }

    @Test("saltear lleva directo a la llegada, con el piso ya cambiado")
    func skipJumpsToTheArrival() async {
        let recorder = Recorder()
        let ride = ElevatorRide()
        ride.attach(ElevatorRide.Hooks(
            visibleOrdinal: { 0 }, isUnlocked: { _ in true },
            jump: { recorder.jumps.append($0) }, cue: { recorder.cues.append($0) },
            sleep: { try? await Task.sleep(for: $0) }, reduceMotion: { false }, instant: false
        ))
        ride.select(ordinal: 6)
        #expect(ride.phase == .closing)
        ride.skip()
        #expect(ride.phase == .idle)
        #expect(recorder.jumps == [6])
        #expect(recorder.cues.suffix(2) == [.motorStop, .ding])
    }

    @Test("el pedido del mapa espera a que el mapa se cierre")
    func mapRequestWaitsForTheSheet() async {
        let recorder = Recorder()
        let ride = director(recorder)
        ride.requestFromMap(ordinal: 3)
        #expect(ride.phase == .idle)
        ride.startPendingRide()
        await ride.waitUntilIdle()
        #expect(recorder.jumps == [3])
        ride.startPendingRide()
        await ride.waitUntilIdle()
        #expect(recorder.jumps == [3], "el pedido se consume una vez")
    }

    @Test("instantáneo: salta en el acto, sin fases ni sonidos de viaje")
    func instantRideJumpsRightAway() async {
        let recorder = Recorder()
        let ride = director(recorder, instant: true)
        ride.select(ordinal: 2)
        #expect(recorder.jumps == [2])
        #expect(ride.phase == .idle)
        #expect(!recorder.cues.contains(.doorsClose))
    }

    @Test("saltear con las puertas abriendo no repite el ding")
    func skipWhileOpeningDoesNotDingTwice() async {
        let recorder = Recorder()
        let ride = director(recorder)
        ride.select(ordinal: 4)
        for _ in 0..<100 where ride.phase != .opening { await Task.yield() }
        #expect(ride.phase == .opening)
        ride.skip()
        #expect(ride.phase == .idle)
        #expect(recorder.cues.filter { $0 == .ding }.count == 1)
    }

    @Test("el pedido del mapa se descarta si ya hay un viaje en curso")
    func mapRequestIsIgnoredDuringARide() async {
        let recorder = Recorder()
        let ride = director(recorder)
        ride.select(ordinal: 4)
        ride.requestFromMap(ordinal: 2)
        ride.startPendingRide()
        await ride.waitUntilIdle()
        #expect(recorder.jumps == [4])
    }

    @Test("el slowdown de los UI tests estira las tres fases")
    func slowdownStretchesThePlan() throws {
        let plan = try #require(ElevatorRidePlan(origin: 0, destination: 1, reduceMotion: false, instant: false))
        let slow = try #require(ElevatorRidePlan(origin: 0, destination: 1, reduceMotion: false, instant: false,
                                                 slowdown: 5))
        #expect(slow.total == plan.total * 5)
    }

    @Test("cada borde del viaje tiene sonido; el motor arranca y corta el mismo loop")
    func cuesMapToSounds() {
        #expect(ElevatorRide.Cue.motorStart.sound == .startLoop(.elevatorMotor))
        #expect(ElevatorRide.Cue.motorStop.sound == .stopLoop(.elevatorMotor))
        #expect(ElevatorRide.Cue.ding.sound == .oneShot(.elevatorDing, nil))
        #expect(ElevatorRide.Cue.button.sound == .oneShot(.elevatorClick, .action))
        #expect(Set(ElevatorRide.Cue.all.map(\.sound.sfx)) == [
            .elevatorSpring, .elevatorClick, .elevatorDoors, .elevatorMotor, .elevatorDing,
        ])
    }
}
