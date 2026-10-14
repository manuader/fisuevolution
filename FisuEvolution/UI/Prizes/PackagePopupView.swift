import SwiftUI

/// Los toques que abren el paquete (E14 C28 «durante»): cada uno lo sacude y el
/// tercero lo abre. Con Reduce Motion alcanza un toque. Puro, para pinearlo.
struct PackageOpening: Equatable {
    static let tapsToOpen = 3

    private(set) var taps = 0
    /// El clip de la sacudida corre (el toque acaba de pasar).
    private(set) var shaking = false

    var isOpen: Bool { taps >= Self.tapsToOpen }

    mutating func tap(reduceMotion: Bool) {
        guard !isOpen else { return }
        taps = reduceMotion ? Self.tapsToOpen : taps + 1
        shaking = !isOpen
    }

    mutating func shakeEnded() { shaking = false }

    /// El clip que corresponde ahora: respira, salta con el toque o se abre.
    var clipID: String {
        if isOpen { return "paquete_abre" }
        return shaking ? "paquete_sacude" : "paquete_espera"
    }
}

/// El Paquete de la Aduana (PLAN-v2 E5, E14 C28) en tres momentos. Antes: la
/// caja, qué trae y quiénes pueden salir con su chance. Durante: ya se sorteó y
/// la caja se toca tres veces. Después: el empleado que salió, grande, y a qué
/// piso llega; al cerrar, cae al tablero. Sin lugar, lo dice antes de abrir.
/// Vive en el `PopupContainer` de la casa.
struct PackagePopupView: View {
    @Environment(GameState.self) private var gameState
    let onClose: () -> Void
    /// El clip de apertura terminó (o la política lo dejó quieto): ya se ve quién salió.
    @State private var revealed = false
    @State private var opening = PackageOpening()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var arrivals: [PackageArrival] { gameState.packagePopup?.arrivals ?? [] }

    var body: some View {
        let stage = MattressStage(hasOutcome: !arrivals.isEmpty, revealed: revealed)
        PopupContainer("package.title", ribbonTint: Color("PaletteBrown").lifted(0.15), onClose: onClose) {
            switch stage {
            case .waiting: before
            case .opening: tapTheBox
            case .revealed: result
            }
        } actions: {
            switch stage {
            case .waiting: openActions
            case .opening: EmptyView()
            case .revealed: resultActions
            }
        }
        .onChange(of: gameState.packagePopup?.id) {
            revealed = false
            opening = PackageOpening()
        }
    }

    // MARK: Antes

    @ViewBuilder private var before: some View {
        Text("package.subtitle")
            .font(Tokens.body)
            .multilineTextAlignment(.center)
            .foregroundStyle(Color("PaletteInk"))
        AnimatedArtView(clip: .object("paquete_espera"), role: .popup) {
            GameIcon(artKey: "pickup_package", size: Self.waitingSide) { RewardArt(kind: .package) }
        }
        if gameState.packagesBlocked {
            Text("package.full")
                .font(Tokens.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color("PaletteInk"))
                .accessibilityIdentifier("package.full")
        }
        PackageChancesView(chances: gameState.packageChances)
    }

    @ViewBuilder private var openActions: some View {
        if gameState.packagesBlocked {
            GameButton("package.full.ok", role: .neutral, identifier: "package.full.ok", action: onClose)
        } else {
            // Apilados: con dos botones lado a lado «Abrir todos» no entra en el SE.
            VStack(spacing: Tokens.s8) {
                GameButton("package.open", role: .free, identifier: "package.open", action: openOne)
                if gameState.packagesWaiting > 1 {
                    GameButton("package.open_all", role: .neutral, identifier: "package.open_all", action: openAll)
                }
            }
        }
    }

    private func openOne() {
        revealed = false
        opening = PackageOpening()
        gameState.openPackageFromPopup()
    }

    private func openAll() {
        revealed = false
        opening = PackageOpening()
        gameState.openAllPackagesFromPopup()
    }

    // MARK: Durante

    /// La caja es el botón.
    private var tapTheBox: some View {
        VStack(spacing: Tokens.s8) {
            Text("package.tap")
                .font(Tokens.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color("PaletteInk"))
            Button(action: tapBox) {
                AnimatedArtView(clip: .object(opening.clipID), role: .popup, playback: playback) {
                    GameIcon(artKey: "pickup_package", size: Self.boxSide) { RewardArt(kind: .package) }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("package.tap")
            .accessibilityLabel(Text("package.tap"))
            .accessibilityValue(Text(verbatim: String(opening.taps)))
        }
        .task(id: opening.taps) {
            // Quien no toca no se queda trabado: el empleado ya está sorteado.
            try? await Task.sleep(for: .seconds(Self.idleSeconds))
            if !Task.isCancelled { tapBox() }
        }
    }

    private static let boxSide: CGFloat = 180
    private static let waitingSide: CGFloat = 120
    private static let idleSeconds = 2.0

    private var playback: ArtPlayback {
        if opening.isOpen { return .once { revealed = true } }
        return opening.shaking ? .once { opening.shakeEnded() } : .loop
    }

    private func tapBox() {
        guard !opening.isOpen else { return }
        opening.tap(reduceMotion: reduceMotion)
        gameState.playHaptic(opening.isOpen ? .rarity : .merge)
    }

    // MARK: Después

    @ViewBuilder private var result: some View {
        if let only = arrivals.first, arrivals.count == 1 {
            let name = gameState.content?.tiers.type(id: only.typeId)?.localizedName ?? ""
            PackageReveal(faceKey: "\(only.typeId)_face", name: name)
            Text("package.arrives \(TowerNaming.floorName(for: only.floorId))")
                .font(Tokens.display)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color("PaletteInk"))
                .minimumScaleFactor(0.6)
                .accessibilityIdentifier("package.result.floor")
        } else {
            Text("package.arrives.many \(arrivals.count)")
                .font(Tokens.display)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color("PaletteInk"))
            PackageArrivalsGrid(arrivals: arrivals)
        }
    }

    @ViewBuilder private var resultActions: some View {
        VStack(spacing: Tokens.s8) {
            if gameState.packagesWaiting > 0, !gameState.packagesBlocked {
                GameButton("package.another", role: .neutral, identifier: "package.another") {
                    gameState.packagePopupOpenAnother()
                }
            }
            GameButton("package.collect", role: .free, identifier: "package.collect", action: onClose)
        }
    }
}

// MARK: - Las caras

/// La cara de un empleado en su plato: la de la ficha, con el mismo cuidado que
/// FisuJobs. Sin la clave en el atlas, un CV sin foto.
struct PackageFace: View {
    let faceKey: String
    var side: CGFloat = 52

    var body: some View {
        Color.clear
            .frame(width: side, height: side)
            .overlay { face.padding(side * 0.05) }
            .background(Color("PaletteYellow").opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: side * 0.17, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: side * 0.17, style: .continuous)
                    .strokeBorder(Color("PaletteBrown").opacity(0.7), lineWidth: 2)
            )
            .accessibilityHidden(true)
    }

    @ViewBuilder private var face: some View {
        if let image = UIArt.image(faceKey) {
            image.resizable().scaledToFit()
        } else {
            IconCanvas { MarkDisc(mark: "?", fill: Color("PaletteBrown").lifted(0.3)) }
        }
    }
}

/// «Adentro puede venir»: las caras de la ventana del sorteo, cada una con su
/// chance debajo (Apple 3.1.1: es la tabla con la que se sortea).
struct PackageChancesView: View {
    let chances: [PackageChance]

    private static let columns = Array(repeating: GridItem(.flexible(), spacing: Tokens.s8), count: 4)

    var body: some View {
        GameCard {
            VStack(spacing: Tokens.s8) {
                Text("package.odds.title")
                    .font(Tokens.caption)
                    .foregroundStyle(Color("PaletteInk").opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .leading)
                LazyVGrid(columns: Self.columns, spacing: Tokens.s8) {
                    ForEach(chances) { chance in
                        VStack(spacing: 2) {
                            PackageFace(faceKey: chance.faceKey)
                            Text(verbatim: OddsDisclosureView.percent(chance.probability))
                                .font(Tokens.caption)
                                .monospacedDigit()
                                .foregroundStyle(Color("PaletteInk"))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(Text("package.chance.ax \(chance.name) \(OddsDisclosureView.percent(chance.probability))"))
                        .accessibilityIdentifier("package.chance.\(chance.typeId)")
                    }
                }
            }
        }
        .accessibilityIdentifier("package.odds")
    }
}

/// El empleado que salió, grande y con rayos, con el pop de siempre.
struct PackageReveal: View {
    let faceKey: String
    let name: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var popped = false

    var body: some View {
        VStack(spacing: Tokens.s4) {
            ZStack {
                RewardRays()
                PackageFace(faceKey: faceKey, side: 104)
                    .scaleEffect(popped ? 1 : 0.4)
                PrizePop()
            }
            .frame(width: 150, height: 150)
            Text(verbatim: name)
                .font(Tokens.display)
                .foregroundStyle(Color("PaletteInk"))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .accessibilityIdentifier("package.result.name")
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("package.result")
        .onAppear {
            guard !reduceMotion else { popped = true; return }
            withAnimation(.spring(duration: 0.45, bounce: 0.45)) { popped = true }
        }
    }
}

/// «Abrir todos»: cada empleado con el piso al que llega.
private struct PackageArrivalsGrid: View {
    let arrivals: [PackageArrival]

    private static let columns = Array(repeating: GridItem(.flexible(), spacing: Tokens.s8), count: 3)

    var body: some View {
        LazyVGrid(columns: Self.columns, spacing: Tokens.s8) {
            ForEach(arrivals) { arrival in
                VStack(spacing: 2) {
                    PackageFace(faceKey: "\(arrival.typeId)_face")
                    Text(verbatim: TowerNaming.floorName(for: arrival.floorId))
                        .font(Tokens.caption)
                        .foregroundStyle(Color("PaletteInk"))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
        }
        .accessibilityIdentifier("package.result")
    }
}
