import EconomyKit
import Foundation

/// Las lecciones contextuales del tutorial: después de la fase obligatoria
/// (tap → contratar → fusionar), el resto de la app se enseña de a una lección,
/// cada una la PRIMERA vez que hay algo que hacer en su pantalla — nunca antes.
///
/// La regla de oro es del dueño y es el criterio de aceptación: ninguna lección
/// manda a una pantalla donde EN ESE MOMENTO no hay nada que hacer. Por eso
/// cada lección declara su señal de gating (una proyección barata, nunca una
/// fila computada), y por eso viajan por la `CelebrationQueue` como
/// `.tutorialTip`: el "de a una" y el no-pisarse con premios y reveals salen
/// del árbitro que ya existe, no de un segundo tutorial paralelo.
extension GameState {
    /// Una pantalla de la app, con su momento. El orden de `allCases` es el
    /// desempate cuando hay más de una elegible a la vez (el de la tabla del
    /// prompt); en la práctica casi siempre decide el gating solo.
    enum TutorialRelease: Equatable, Sendable {
        case v1
        case v2
    }

    enum TutorialLesson: String, CaseIterable {
        /// Alguien en escena esperando que lo toquen: la primera visita enseña el
        /// chip. Va primera: una visita se va sola, y si esperara su turno
        /// detrás de otra lección se perdería.
        case visitor
        /// Un evento corriendo deja su chip: la primera vez se enseña a tocarlo.
        case eventChip
        /// Hay una mejora de personaje pagable: el multiplicador.
        case upgrades
        /// Hay un ingreso pasivo pagable (la v1 lo tenía, sin lección).
        case passive
        /// Se desbloqueó el segundo piso: recién ahora el mapa tiene a dónde ir.
        case elevator
        /// El tercer piso: la placa colgante (PLAN-v2 E13, ítem 13).
        case elevatorKeypad
        /// El atajo de contratar al mejor, cuando hay algo contratable: tocar, mantener, fijar,
        /// soltar y el botón gris.
        case quickHire
        /// Ya hay jerarquías: cuatro tipos vistos y el Menú abierto.
        case orgChart
        /// Dos pisos: también se cambia deslizando.
        case floorSwipe
        /// El atajo está gris por piso lleno.
        case floorFull
        /// Un piso con todos sus lugares ocupados (pisos en marcha, E2a).
        case staffedFloors
        /// Reencarnar pide llegar al tier más alto de la vida anterior (piso móvil, E2a).
        case prestigeGate
        /// La ficha del personaje (mantener presionado).
        case characterSheet
        /// Ya hay una pinta para ponerse. Desde que las 41 pintas de piso salen
        /// **sólo** de cofres, la primera llega en el cofre de bienvenida, al
        /// cerrar la fase obligatoria — la vía vieja (la skin de milestone del
        /// piso 2) no existe más.
        case skins
        /// El primer logro COBRABLE: enseña el circuito del puntito rojo.
        case achievements
        /// El primer ORO en el bolsillo (los logros lo pagan) con una mejora
        /// PERMANENTE pagable: la lección lleva a Mejoras a canjearlo — y
        /// adentro, la manito de la sección de ORO dice cuál (pedido del
        /// dueño, 2026-08-28: "que te lleve a la pestaña de mejoras
        /// permanentes y te haga elegir").
        case oroUpgrades
        /// El primer daily cobrado de verdad: el calendario vive en Regalos.
        case gifts
        /// Una vez, suave, en la segunda sesión con la fase hecha.
        case store
        /// El indicador de reencarnar se encendió por primera vez.
        case prestige
        /// El primer momento viral ofrecido: el botón de compartir y su premio.
        case share
        /// El primer especial conseguido: vive en el Álbum de la Oficina central.
        case album
        /// La columna de Premios con algo listo: enseña a abrirla. Las de sus
        /// cuatro botones la esperan (E7b).
        case sideRail
        /// Un Paquete de la Aduana esperando (E5).
        case packages
        /// El Colchón esperando (E5).
        case mattress
        /// La Ruleta, adentro de la columna (E5, E7b).
        case wheel
        /// Fusionar todo por video, adentro de la columna (E7b): con pares en el piso a la vista.
        case mergeAllVideo

        /// Las que señalan algo del tablero: nunca salen con el tablero ocupado.
        var needsCalmBoard: Bool {
            switch self {
            case .sideRail, .packages, .mattress, .wheel: true
            default: false
            }
        }

        /// La bandera persistida de "esta lección ya se dio". Versionable por
        /// prefijo, y `--uitest-reset` las barre (`+Debug`).
        var defaultsKey: String { TutorialFlags.lessonKey(rawValue) }

        /// En qué versión nació la mecánica que enseña. Al veterano de la v1 se le dan por vistas
        /// las de la v1 (`TutorialMigration`); las de la 2.0 las ve en su primera vez.
        var introducedIn: TutorialRelease {
            switch self {
            case .upgrades, .passive, .orgChart, .elevator, .floorSwipe, .floorFull, .skins, .achievements, .oroUpgrades,
                 .gifts, .store, .prestige: .v1
            default: .v2
            }
        }

        static var veteranKnownLessons: Set<String> {
            Set(allCases.filter { $0.introducedIn == .v1 }.map(\.rawValue))
        }

        /// El control que el coach-mark señala.
        var anchorTarget: TutorialTarget {
            switch self {
            case .visitor: .visitor
            case .eventChip: .eventChip
            case .upgrades, .passive: .upgrades
            case .orgChart, .album: .menu
            case .elevator, .elevatorKeypad, .staffedFloors: .map
            case .floorSwipe: .boardUnit
            case .quickHire, .floorFull: .quickHire
            case .prestigeGate: .prestige
            case .characterSheet: .boardUnit
            case .skins: .skins
            case .achievements: .menu
            case .oroUpgrades: .upgrades
            case .gifts: .gifts
            case .store: .store
            case .prestige: .prestige
            case .share: .share
            case .sideRail: .sideRail
            case .packages: .sidePackages
            case .mattress: .sideMattress
            case .wheel: .sideWheel
            case .mergeAllVideo: .sideBoost
            }
        }

        /// La hoja de la barra que "hace" la lección, para que abrirla la dé
        /// por cumplida. `nil` = el destino no es una hoja de la barra (el
        /// mapa, el atajo y el prestigio avisan desde su propia acción).
        var destinationScreen: GameScreen? {
            switch self {
            case .upgrades, .passive, .oroUpgrades: .upgrades
            case .skins: .skins
            case .achievements, .album, .orgChart: .menu
            case .gifts: .gifts
            case .store: .store
            case .visitor, .eventChip, .elevator, .elevatorKeypad, .quickHire, .floorSwipe, .floorFull, .staffedFloors,
                 .prestige, .prestigeGate, .characterSheet, .share, .sideRail, .packages, .mattress, .wheel, .mergeAllVideo: nil
            }
        }

        /// La clave del globo de las lecciones que todavía son un solo paso heredado. Escrita
        /// entera, nunca interpolada (trampa 5). `nil` en las que tienen guion propio (`script`).
        var textKey: String? {
            switch self {
            case .visitor: "tutorial.tip.visitor"
            case .eventChip: "tutorial.tip.event_chip"
            case .elevator: "tutorial.tip.elevator"
            case .elevatorKeypad: "tutorial.tip.elevator.hold"
            case .skins: "tutorial.tip.skins"
            case .achievements: "tutorial.tip.achievements"
            case .oroUpgrades: "tutorial.tip.oro"
            case .gifts: "tutorial.tip.gifts"
            case .store: "tutorial.tip.store"
            case .share: "tutorial.tip.share"
            case .album: "tutorial.tip.album"
            case .sideRail: "tutorial.tip.side_rail"
            case .packages: "tutorial.tip.packages"
            case .mattress: "tutorial.tip.mattress"
            case .wheel: "tutorial.tip.wheel.rail"
            case .mergeAllVideo: "tutorial.tip.merge_all_video"
            case .upgrades, .passive, .quickHire, .orgChart, .floorSwipe, .floorFull, .staffedFloors,
                 .prestigeGate, .prestige, .characterSheet: nil
            }
        }

        /// El guion de la lección (PLAN-v2 E9). E9b los reescribe uno por uno; las que todavía no
        /// tienen el suyo son un solo paso: el destino de siempre, con el texto de siempre.
        var steps: [TutorialStep] {
            script ?? [legacyStep]
        }

        /// Repite la conducta de la v1: si tiene hoja de destino, abrirla la
        /// cumple; si no, su acción firma (`tutorialTipCompleted`).
        var legacyStep: TutorialStep {
            let signal: TutorialSignal = destinationScreen.map { .screenOpened($0) } ?? .lessonAction
            return .act("\(rawValue).legacy", signal, text: textKey ?? "", on: anchorTarget)
        }

        /// ⚠️ El cierre «listo» de Mejoras y del pasivo vive en el tablero y no en la hoja: con la
        /// hoja cerrada `rewindToBoard` devuelve un paso de hoja al que abre la lección, y quien
        /// compró y cerró el menú volvería a oír «abrí Mejoras».
        private var script: [TutorialStep]? {
            switch self {
            case .quickHire: [
                .act("quick_hire.tap", .lessonAction, text: "tutorial.quick_hire.tap", on: .quickHire),
                .act("quick_hire.hold", .pickerOpened, text: "tutorial.quick_hire.hold", on: .quickHire, hand: .hold),
                .act("quick_hire.pin", .pinned, text: "tutorial.quick_hire.pin", on: .pickerFace, windows: [.quickHire]),
                .act("quick_hire.unpin", .unpinned, text: "tutorial.quick_hire.unpin", on: .quickHire,
                     hand: .hold, windows: [.pickerFace]),
                .explain("quick_hire.blocked", text: "tutorial.quick_hire.blocked", on: .quickHire),
            ]
            case .passive: [
                .act("passive.open", .screenOpened(.upgrades), text: "tutorial.passive.open", on: .upgrades),
                .act("passive.unlock", .passiveUnlocked, text: "tutorial.passive.unlock", on: .upgradesPassive,
                     surface: .page(.upgrades)),
                .explain("passive.done", text: "tutorial.passive.done"),
            ]
            case .upgrades: [
                .act("upgrades.open", .screenOpened(.upgrades), text: "tutorial.upgrades.open", on: .upgrades),
                .act("upgrades.buy", .upgradeBought, text: "tutorial.upgrades.buy", on: .upgradesRow,
                     surface: .page(.upgrades)),
                .explain("upgrades.done", text: "tutorial.upgrades.done"),
            ]
            case .orgChart: [
                .act("org_chart.open", .screenOpened(.menu), text: "tutorial.org_chart.open", on: .menu),
                .explain("org_chart.card", text: "tutorial.org_chart.card", on: .menuOrgChart, surface: .page(.menu)),
            ]
            case .floorSwipe: [
                .explain("floor_swipe.explain", text: "tutorial.floor_swipe.explain", hand: .swipe(.up)),
            ]
            case .floorFull: [
                .explain("floor_full.explain", text: "tutorial.floor_full.explain", on: .quickHire),
            ]
            case .staffedFloors: [
                .explain("staffed_floors.floor", text: "tutorial.staffed_floors.floor", on: .map),
                .explain("staffed_floors.bonus", text: "tutorial.staffed_floors.bonus", on: .map),
            ]
            case .prestigeGate: [
                .explain("prestige_gate.explain", text: "tutorial.prestige_gate.explain", on: .prestige),
            ]
            case .prestige: [
                .explain("prestige.oro", text: "tutorial.prestige.oro", on: .prestige),
                .act("prestige.open", .lessonAction, text: "tutorial.prestige.open", on: .prestige),
            ]
            case .characterSheet: [
                .act("character_sheet.hold", .characterSheetOpened, text: "tutorial.character_sheet.hold",
                     on: .boardUnit, hand: .hold, boardTarget: .anyUnit),
                .explain("character_sheet.inside", text: "tutorial.character_sheet.inside", surface: .characterSheet),
            ]
            default: nil
            }
        }
    }

    /// El payload de `.tutorialTip`: qué lección tiene (o espera) el turno.
    struct TutorialTip: Equatable {
        let lesson: TutorialLesson
    }

    static let sessionsAfterPhaseKey = TutorialFlags.sessionsAfterCoreKey

    /// Borra el progreso persistido de las lecciones (los flags por lección y
    /// el contador de sesiones). Lo comparten `--uitest-reset` y el "Resetear
    /// partida" del panel de debug: las lecciones viven en `UserDefaults` y
    /// sobrevivirían a cualquier partida nueva — la misma trampa que el
    /// tutorial y los ajustes.
    func wipeTutorialLessonProgress() {
        let defaults = flagDefaults
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(TutorialFlags.lessonPrefix) {
            defaults.removeObject(forKey: key)
        }
        defaults.removeObject(forKey: TutorialFlags.sessionsAfterCoreKey)
    }

    // MARK: La señal de gating

    /// La señal de cada lección, contra proyecciones ya publicadas. La lee el
    /// director (`+Tutorial`) al elegir la próxima y mientras espera turno.
    func isEligible(_ lesson: TutorialLesson) -> Bool {
        switch lesson {
        case .visitor:
            stageVisit?.phase == .waiting && stageVisit?.offer != nil && stageChallenge == nil
        case .eventChip:
            activeBonuses.contains { $0.eventId != nil }
        case .upgrades:
            canAffordAnyCharacterUpgrade()
        case .passive:
            canAffordAnyPassiveUnlock()
        case .orgChart:
            (player?.run.seenTypes.count ?? 0) >= 4 && unlockedTabs.contains(.menu)
        case .floorSwipe:
            unlockedFloorsCount >= 2 && isLessonDone(.elevator)
        case .floorFull:
            quickHireOffer?.blocker == .floorFull
        case .staffedFloors:
            hasStaffedFloor()
        case .prestigeGate:
            prestigePreview.isBlockedByWall
        case .characterSheet:
            (player?.meta.stats.totalHiresEver ?? 0) >= 3 && visibleFloorOccupancy.occupied > 0
        case .elevator:
            unlockedFloorsCount >= 2
        case .elevatorKeypad:
            unlockedFloorsCount >= 3
        case .quickHire:
            // Comprable de verdad: con el piso lleno la oferta existe pero no compra.
            quickHireOffer.map { $0.blocker == nil } ?? false
        case .skins:
            // "Tener una pinta que ponerse", literal — que es la regla de oro
            // aplicada a esta pantalla. La proyección publica `allOwnedSkins`
            // (tienda ∪ milestone ∪ ORO) y el cofre acredita en `milestoneSkins`, así
            // que el de bienvenida la enciende apenas se abre, y el carrusel
            // muestra a su dueño aunque el jugador todavía no lo haya conocido
            // (`skinnableTypes` incluye a los personajes con pinta).
            //
            // ⚠️ NO se mira `welcomeChestGiven`: esa bandera dice que el cofre se
            // DIO, no que haya una pinta en la bolsa, y además se olvidaría de la
            // vía de la tienda — dos formas de mandar a Pintas sin nada que hacer.
            !ownedSkins.isEmpty
        case .achievements:
            hasClaimableAchievements
        case .oroUpgrades:
            canAffordAnyOroUpgrade
        case .gifts:
            // `cycleDay` apunta al día que el ciclo VA a pagar y arranca en 1;
            // la instalación fresca marca `lastClaimDay` sin moverlo. O sea:
            // `> 1` es exactamente "ya cobró un daily de verdad" — sin bandera
            // nueva y persistido en el save.
            (player?.meta.daily.cycleDay ?? 1) > 1
        case .store:
            flagDefaults.integer(forKey: Self.sessionsAfterPhaseKey) >= 2
        case .prestige:
            prestigeAvailable
        case .share:
            shareOffer != nil
        case .album:
            // Una partida vieja con especiales la ve una vez: es justo el aviso
            // de que se mudaron del piso al Álbum.
            !(player?.meta.ownedSpecials.isEmpty ?? true)
        case .sideRail:
            sideRail.readyCount > 0
        case .packages:
            // Uno que se puede abrir: con todo lleno la lección mandaría a
            // tocar algo que tiembla y no hace nada.
            isLessonDone(.sideRail) && prizeAccess.packagesWaiting > 0 && !prizeAccess.packagesBlocked
        case .mattress:
            isLessonDone(.sideRail) && prizeAccess.mattressReady
        case .wheel:
            isLessonDone(.sideRail) && prizeAccess.wheelSpinsReady > 0
        case .mergeAllVideo:
            isLessonDone(.sideRail) && sideRail.status(of: .boost) == .ready(count: nil)
        }
    }

    func isLessonDone(_ lesson: TutorialLesson) -> Bool {
        TutorialFlags.isLessonDone(lesson.rawValue, in: flagDefaults)
    }

    /// Una lección que estuvo en pantalla no vuelve, la hayan hecho o ignorado:
    /// la marca la salida del turno (`releaseTutorialTurn`).
    func markLessonDone(_ lesson: TutorialLesson) {
        TutorialFlags.markLessonDone(lesson.rawValue, in: flagDefaults)
    }

    // MARK: Salidas

    /// El jugador desplegó la placa del ascensor: la lección se cumple y no vuelve.
    func elevatorKeypadOpened() {
        tutorialTipCompleted(.elevatorKeypad)
        markLessonDone(.elevatorKeypad)
    }

    // MARK: La señal de Mejoras

    /// Los tipos de los que hay mejora para comprar: los vistos, sin ordenar. Corre a 8 Hz.
    private func seenConcreteTypes(_ player: PlayerState, _ content: GameContent) -> [CharacterType] {
        content.tiers.concreteTypes.filter { player.run.seenTypes.contains($0.id) }
    }

    /// Un multiplicador de personaje pagable (la lección de Mejoras).
    func canAffordAnyCharacterUpgrade() -> Bool {
        guard let player, let content else { return false }
        return seenConcreteTypes(player, content).contains {
            characterUpgradeCost(of: $0).map { player.run.coins >= $0 } ?? false
        }
    }

    /// Un ingreso pasivo pagable y todavía sin desbloquear (la lección del pasivo).
    func canAffordAnyPassiveUnlock() -> Bool {
        guard let player, let content else { return false }
        return seenConcreteTypes(player, content).contains {
            player.run.passiveUnlocked[$0.id] != true && player.run.coins >= $0.passiveUnlockCost
        }
    }

    /// Hay un piso con todos sus lugares ocupados y la perilla de pisos en marcha prendida.
    func hasStaffedFloor() -> Bool {
        guard let player, let content, content.economy.staffedBonusPerFloor > 0 else { return false }
        return !StaffedFloors.ordinals(state: player, tiers: content.tiers, floorTable: content.floorTable).isEmpty
    }

    /// Cotiza costos CRUDOS contra los dos balances. Nunca `characterUpgradeRows`
    /// —que arma textos localizados por fila— ni nada por frame que no sea una
    /// comparación: esto corre a 8 Hz.
    func computeCanAffordAnyUpgrade(player: PlayerState, content: GameContent) -> Bool {
        let coins = player.run.coins
        for type in characterUpgradeTypes {
            if let cost = characterUpgradeCost(of: type), coins >= cost { return true }
            if player.run.passiveUnlocked[type.id] != true, coins >= type.passiveUnlockCost { return true }
        }
        let oro = Double(player.meta.oro)
        for line in content.upgradesConfig.upgrades where upgradeLevel(of: line.id) < line.maxLevel {
            let balance = line.currency == .oro ? oro : coins
            if balance >= upgradeCost(of: line) { return true }
        }
        return false
    }

    /// La señal de la lección del primer ORO: hay una línea de ORO pagable
    /// (lo que implica ORO en el bolsillo — el primero lo paga un logro).
    /// Misma dieta que la de arriba: costos crudos contra el balance, a 8 Hz.
    func computeCanAffordAnyOroUpgrade(player: PlayerState, content: GameContent) -> Bool {
        let oro = Double(player.meta.oro)
        guard oro > 0 else { return false }
        for line in content.upgradesConfig.upgrades
        where line.currency == .oro && upgradeLevel(of: line.id) < line.maxLevel {
            if oro >= upgradeCost(of: line) { return true }
        }
        return false
    }
}

extension GameState {
    /// Corre una vez por instalación (las siguientes es un `nil`). Un veterano es quien tiene
    /// save y ninguna versión: queda con el núcleo hecho y el Tour pendiente (E9b).
    func applyTutorialMigration(hasSave: Bool) {
        guard let plan = TutorialFlags.migrate(hasSave: hasSave,
                                               veteranKnownLessons: TutorialLesson.veteranKnownLessons,
                                               in: flagDefaults)
        else { return }
        Log.lifecycle.info("tutorial migrado: núcleo \(plan.coreCompleted), tour \(plan.tourPending)")
    }
}

/// Las primeras veces que llegan en un popup (PLAN-v2 E9): las aloja la propia celebración.
enum TutorialInlineLesson: String, CaseIterable, Sendable {
    case offline
    case career
    case visitorPopup = "visitor_popup"

    var steps: [TutorialStep] {
        [.explain("\(rawValue).inline", text: "tutorial.\(rawValue).inline", surface: .embedded)]
    }
}
