import AVFoundation
import SwiftUI

/// Los fondos de los pisos que pasan por la ventana, achicados y sólo los del viaje.
enum FloorBackdrops {
    /// Cada fondo llega por `onEach` apenas está listo. Se achica fuera del main; el tamaño es el
    /// ancho de la pantalla y la mitad del alto (`scaledToFill` lo estira, por la ventana no se nota),
    /// y menor aún si pasan muchos pisos.
    @MainActor
    static func load(
        ordinals: [Int], entries: [FloorMapEntry], backgrounds: [String: String], pixelSize: CGSize,
        onEach: @MainActor (Int, UIImage) -> Void
    ) async {
        let side = min(pixelSize.width, pixelSize.height / 2) * (ordinals.count > 5 ? 0.6 : 1)
        let target = CGSize(width: side, height: side)
        let assets = ordinals.compactMap { ordinal -> (Int, String)? in
            guard let entry = entries.first(where: { $0.ordinal == ordinal }),
                  let asset = backgrounds[entry.backgroundKey], !asset.isEmpty else { return nil }
            return (ordinal, asset)
        }
        await withTaskGroup(of: (Int, UIImage?).self) { group in
            for (ordinal, asset) in assets {
                group.addTask { (ordinal, await thumbnail(asset: asset, target: target)) }
            }
            for await (ordinal, image) in group {
                if let image, !Task.isCancelled { onEach(ordinal, image) }
            }
        }
    }

    private static func thumbnail(asset: String, target: CGSize) async -> UIImage? {
        guard let full = UIImage(named: asset) else { return nil }
        return await full.byPreparingThumbnail(ofSize: target)
    }
}

/// El viaje visto desde adentro de la cabina: las puertas cierran con el juego detrás del hueco,
/// los fondos de los pisos pasan por las ventanas y las puertas abren con el destino detrás.
/// Tocar la pantalla saltea.
struct ElevatorRideView: View {
    let ride: ElevatorRide
    let plan: ElevatorRidePlan
    let art: ElevatorCabinArt

    @Environment(GameState.self) private var gameState: GameState?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.displayScale) private var displayScale
    @State private var backdrops: [Int: UIImage] = [:]

    private let warmup = ElevatorCabinWarmup.shared

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { _ in
                let moment = Moment(ride: ride, plan: plan)
                ZStack {
                    if moment.phase == .traveling { backdropLayer(moment, in: geo.size) }
                    cabin(moment, in: geo.size)
                        .offset(y: vibration(moment))
                    indicator(moment, in: geo.size)
                    Button { ride.skip() } label: {
                        Color.clear.contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("elevator.ride.skip")
                    .accessibilityLabel(Text("elevator.ride.skip.ax"))
                }
            }
            .task(id: plan) { await loadBackdrops(size: geo.size) }
            .task(id: ride.phase) { advance(to: ride.phase) }
            .onDisappear {
                backdrops = [:]
                warmup.release()
            }
        }
        .ignoresSafeArea()
    }

    // MARK: Tiempos

    /// Dónde va el viaje en este cuadro: la fase, qué tanto de ella pasó y de ahí la tira y las puertas.
    @MainActor
    private struct Moment {
        let phase: ElevatorRide.Phase
        let position: Double
        /// 0 puertas abiertas, 1 cerradas.
        let doors: Double

        init(ride: ElevatorRide, plan: ElevatorRidePlan) {
            phase = ride.phase
            let elapsed = (ContinuousClock.now - ride.phaseStartedAt).seconds
            func progress(_ span: Duration) -> Double {
                span > .zero ? min(max(elapsed / span.seconds, 0), 1) : 1
            }
            func eased(_ t: Double) -> Double { t * t * (3 - 2 * t) }
            switch phase {
            case .idle, .closing:
                position = Double(plan.origin)
                doors = phase == .closing ? eased(progress(plan.close)) : 0
            case .traveling:
                position = plan.position(atTravelProgress: progress(plan.travel))
                doors = 1
            case .opening:
                position = Double(plan.destination)
                doors = 1 - eased(progress(plan.open))
            }
        }
    }

    private func vibration(_ moment: Moment) -> CGFloat {
        guard moment.phase == .traveling, !plan.fades else { return 0 }
        return CGFloat(sin((ContinuousClock.now - ride.phaseStartedAt).seconds * 2 * .pi * 16) * 1.2)
    }

    // MARK: Fondos

    private func backdropLayer(_ moment: Moment, in size: CGSize) -> some View {
        ZStack {
            Color("PaletteInk")
            if plan.fades {
                backdrop(plan.origin)
                backdrop(plan.destination).opacity(moment.position == Double(plan.origin) ? 0 : fadeProgress(moment))
            } else {
                ForEach(plan.passingOrdinals, id: \.self) { ordinal in
                    let y = (moment.position - Double(ordinal)) * size.height
                    if abs(y) < size.height {
                        backdrop(ordinal).offset(y: y)
                    }
                }
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }

    private func fadeProgress(_ moment: Moment) -> Double {
        let span = Double(plan.destination - plan.origin)
        return span == 0 ? 1 : min(max((moment.position - Double(plan.origin)) / span, 0), 1)
    }

    @ViewBuilder
    private func backdrop(_ ordinal: Int) -> some View {
        if let image = backdrops[ordinal] {
            Image(uiImage: image).resizable().scaledToFill()
        } else {
            Color("PaletteInk").opacity(0.25)
        }
    }

    private func loadBackdrops(size: CGSize) async {
        guard let gameState, let content = gameState.content else { return }
        let pixels = CGSize(width: size.width * displayScale, height: size.height * displayScale)
        await FloorBackdrops.load(
            ordinals: plan.passingOrdinals, entries: gameState.floorMap,
            backgrounds: content.manifest.backgrounds, pixelSize: pixels
        ) { ordinal, image in backdrops[ordinal] = image }
    }

    // MARK: Cabina

    @ViewBuilder
    private func cabin(_ moment: Moment, in size: CGSize) -> some View {
        let rect = CabinFrame.rect(in: size)
        ZStack(alignment: .topLeading) {
            if rect.width < size.width { sideWalls(moment, rect: rect, in: size) }
            cabinArt(moment, rect: rect)
                .frame(width: rect.width, height: rect.height)
                .offset(x: rect.minX, y: rect.minY)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }

    /// Los costados del iPad: pared crema con una franja de acero junto a la cabina.
    private func sideWalls(_ moment: Moment, rect: CGRect, in size: CGSize) -> some View {
        let strip = Color(red: 0.624, green: 0.667, blue: 0.671)
        return ZStack(alignment: .topLeading) {
            Color("PaletteCream").frame(width: rect.minX, height: size.height)
            strip.frame(width: 6, height: size.height).offset(x: rect.minX - 6)
            Color("PaletteCream").frame(width: size.width - rect.maxX, height: size.height).offset(x: rect.maxX)
            strip.frame(width: 6, height: size.height).offset(x: rect.maxX)
        }
        .opacity(plan.fades ? moment.doors : 1)
    }

    @ViewBuilder
    private func cabinArt(_ moment: Moment, rect: CGRect) -> some View {
        switch art {
        case .video(let close, let open):
            // Con Reduce Motion el clip no corre: un cuadro quieto que se funde.
            let player = moment.phase == .opening
                ? warmup.openingPlayer(url: open)
                : warmup.closingPlayer(url: close)
            ChestCinematicView(player: player.player)
                .opacity(plan.fades ? moment.doors : 1)
        case .stills(let closed, let open):
            ZStack {
                Image(uiImage: open).resizable()
                Image(uiImage: closed).resizable().opacity(moment.doors)
            }
        case .vector:
            VectorCabin(doors: plan.fades ? 1 : moment.doors)
                .opacity(plan.fades ? moment.doors : 1)
        }
    }

    // MARK: Indicador

    private func indicator(_ moment: Moment, in size: CGSize) -> some View {
        let rect = CabinFrame.rect(in: size)
        let center = CGPoint(x: rect.minX + rect.width * 0.5, y: rect.minY + rect.height * 0.105)
        return LEDIndicator(number: Int(moment.position.rounded()) + 1, direction: plan.direction, animated: !reduceMotion)
            .position(center)
            .opacity(plan.fades ? moment.doors : 1)
    }

    // MARK: Video

    private func advance(to phase: ElevatorRide.Phase) {
        guard case .video(let close, let open) = art else { return }
        switch phase {
        case .idle:
            warmup.release()
        case .closing:
            let player = warmup.closingPlayer(url: close)
            if plan.fades { Self.showLastFrame(player) } else { Self.play(player, over: plan.close) }
        case .traveling:
            _ = warmup.openingPlayer(url: open)
        case .opening:
            if !plan.fades { Self.play(warmup.openingPlayer(url: open), over: plan.open) }
            warmup.releaseClosing()
        }
    }

    /// El clip dura lo que dura, la fase lo que dice el plan: la velocidad los iguala.
    private static func play(_ player: ChestCinematicPlayer, over span: Duration) {
        let clip = player.player.currentItem?.duration.seconds ?? 0
        let rate = clip.isFinite && clip > 0 && span > .zero ? clip / span.seconds : 1
        player.play(rate: Float(min(max(rate, 0.25), 4)), volume: 0)
    }

    private static func showLastFrame(_ player: ChestCinematicPlayer) {
        guard let end = player.player.currentItem?.duration, end.isNumeric else { return }
        Task { await player.player.seek(to: end, toleranceBefore: .zero, toleranceAfter: .zero) }
    }
}

private extension Duration {
    var seconds: Double {
        Double(components.seconds) + Double(components.attoseconds) / 1e18
    }
}

/// El display chico de la cabina: el piso en LED y una flecha hacia donde va.
private struct LEDIndicator: View {
    let number: Int
    let direction: ElevatorRidePlan.Direction
    let animated: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: direction == .up ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                .font(.system(size: 9))
            Text(String(number))
                .font(.system(size: 17, weight: .heavy, design: .monospaced))
                .contentTransition(animated ? .numericText() : .identity)
        }
        .foregroundStyle(ElevatorLED.lit)
        .frame(width: 56, height: 26)
        .background(ElevatorLED.screen, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .animation(animated ? .snappy(duration: 0.12) : nil, value: number)
        .accessibilityHidden(true)
    }
}

// MARK: - Previews

#if DEBUG
@MainActor
private func previewRide(to destination: Int) -> (ElevatorRide, ElevatorRidePlan) {
    let ride = ElevatorRide()
    ride.attach(.init(
        visibleOrdinal: { 0 }, isUnlocked: { _ in true }, jump: { _ in }, cue: { _ in },
        sleep: { _ = try? await Task.sleep(for: $0) }, reduceMotion: { false }, instant: false
    ))
    ride.select(ordinal: destination)
    return (ride, ride.plan!)
}

#Preview("Vectorial, cerrando") {
    let (ride, plan) = previewRide(to: 3)
    return ElevatorRideView(ride: ride, plan: plan, art: .vector)
}

#Preview("Cuadros, viajando") {
    let (ride, plan) = previewRide(to: 3)
    return ElevatorRideView(ride: ride, plan: plan, art: ElevatorCabinArt.resolve(url: { _ in nil }))
}

#Preview("Clip") {
    let (ride, plan) = previewRide(to: 3)
    return ElevatorRideView(ride: ride, plan: plan, art: .shared)
}
#endif
