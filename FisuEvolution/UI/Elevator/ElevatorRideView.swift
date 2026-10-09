import AVFoundation
import SwiftUI

/// Los fondos de los pisos que pasan por la ventana, achicados y sólo los del viaje.
enum FloorBackdrops {
    private static let parallel = 2

    /// Cada fondo llega por `onEach` apenas está listo (un asset compartido por varios pisos se
    /// achica una vez). Se achica fuera del main, de a dos; el thumbnail es un cuadrado de lado
    /// `min(ancho, alto / 2)` en píxeles (`scaledToFill` lo estira, por la ventana no se nota),
    /// y más chico aún si pasan muchos pisos.
    @MainActor
    static func load(
        ordinals: [Int], entries: [FloorMapEntry], backgrounds: [String: String], pixelSize: CGSize,
        onEach: @MainActor (Int, UIImage) -> Void
    ) async {
        let side = min(pixelSize.width, pixelSize.height / 2) * (ordinals.count > 5 ? 0.6 : 1)
        let target = CGSize(width: side, height: side)
        var ordinalsByAsset: [String: [Int]] = [:]
        var assets: [String] = []
        for ordinal in ordinals {
            guard let entry = entries.first(where: { $0.ordinal == ordinal }),
                  let asset = backgrounds[entry.backgroundKey], !asset.isEmpty else { continue }
            if ordinalsByAsset[asset] == nil { assets.append(asset) }
            ordinalsByAsset[asset, default: []].append(ordinal)
        }
        await withTaskGroup(of: (String, UIImage?).self) { group in
            var pending = assets[...]
            func addNext() {
                guard let asset = pending.popFirst() else { return }
                group.addTask { (asset, await thumbnail(asset: asset, target: target)) }
            }
            for _ in 0..<parallel { addNext() }
            for await (asset, image) in group {
                if let image, !Task.isCancelled {
                    for ordinal in ordinalsByAsset[asset] ?? [] { onEach(ordinal, image) }
                }
                if !Task.isCancelled { addNext() }
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
            case .closing:
                position = Double(plan.origin)
                doors = eased(progress(plan.close))
            case .traveling:
                position = plan.position(atTravelProgress: progress(plan.travel))
                doors = 1
            case .opening:
                position = Double(plan.destination)
                doors = 1 - eased(progress(plan.open))
            case .idle:
                // El fundido de salida: la cabina ya llegó, con las puertas abiertas.
                position = Double(plan.destination)
                doors = 0
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
            ordinals: plan.fades ? [plan.origin, plan.destination] : plan.passingOrdinals, entries: gameState.floorMap,
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
        let strip = MetalTone.base
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
            if plan.fades {
                VectorCabin(doors: 1).opacity(moment.doors)
            } else {
                videoCabin(moment, close: close, open: open)
            }
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

    /// Dos capas desde que arranca el viaje: la de "abre" (en su primer cuadro, igual al último de
    /// "cierra") queda debajo y la de "cierra" se oculta al abrir, así el empalme no parpadea.
    /// Sin player (no se creó, se soltó o falló) cae a la cabina vectorial.
    @ViewBuilder
    private func videoCabin(_ moment: Moment, close: URL, open: URL) -> some View {
        let closer = warmup.currentClosing(url: close)
        let opener = warmup.currentOpening(url: open)
        switch moment.phase {
        case .closing:
            if let closer { ChestCinematicView(player: closer.player) } else { VectorCabin(doors: moment.doors) }
        case .traveling:
            ZStack {
                if let opener { ChestCinematicView(player: opener.player) }
                if let closer { ChestCinematicView(player: closer.player) } else { VectorCabin(doors: 1) }
            }
        case .opening, .idle:
            if let opener { ChestCinematicView(player: opener.player) } else { VectorCabin(doors: moment.doors) }
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

    /// Sólo acá se crean los players; el dibujo únicamente los busca.
    private func advance(to phase: ElevatorRide.Phase) {
        guard case .video(let close, let open) = art, !plan.fades else { return }
        switch phase {
        case .idle:
            break
        case .closing:
            warmup.cancelExpiry()
            Self.play(warmup.closingPlayer(url: close), over: plan.close)
        case .traveling:
            _ = warmup.openingPlayer(url: open)
        case .opening:
            Self.play(warmup.openingPlayer(url: open), over: plan.open)
            warmup.releaseClosing()
        }
    }

    /// El clip dura lo que dura, la fase lo que dice el plan: la velocidad los iguala. Los de la
    /// cabina son el master entero (3 s): "abre" en 650 ms pide ×4,7, y con tope 4 las puertas no
    /// terminarían de abrir antes de que la cabina se vaya.
    private static func play(_ player: ChestCinematicPlayer, over span: Duration) {
        let clip = player.player.currentItem?.duration.seconds ?? 0
        let rate = clip.isFinite && clip > 0 && span > .zero ? clip / span.seconds : 1
        player.play(rate: Float(min(max(rate, 0.25), 5)), volume: 0)
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
