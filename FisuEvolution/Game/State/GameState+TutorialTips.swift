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
        /// El atajo de contratar al mejor, cuando hay algo contratable: tocar, mantener, fijar,
        /// soltar y el botón gris.
        case quickHire
        /// Hay una mejora de personaje pagable: el multiplicador.
        case upgrades
        /// Hay un ingreso pasivo pagable (la v1 lo tenía, sin lección).
        case passive
        /// Una pestaña recién abierta, con su «¡Nuevo!».
        case newTabs
        /// Ya hay una pinta para ponerse. Desde que las 41 pintas de piso salen
        /// **sólo** de cofres, la primera llega en el cofre de bienvenida, al
        /// cerrar la fase obligatoria — la vía vieja (la skin de milestone del
        /// piso 2) no existe más.
        case skins
        /// El primer daily cobrado de verdad: el calendario vive en Regalos.
        case gifts
        /// Un boost listo para activar en Regalos y ninguno usado todavía.
        case boosts
        /// Un cofre ganado y abrible en Regalos.
        case chests
        /// El primer logro COBRABLE: enseña el circuito del puntito rojo.
        case achievements
        /// El primer ORO en el bolsillo (los logros lo pagan) con una mejora
        /// PERMANENTE pagable: la lección lleva a Mejoras a canjearlo — y
        /// adentro, la manito de la sección de ORO dice cuál (pedido del
        /// dueño, 2026-08-28: "que te lleve a la pestaña de mejoras
        /// permanentes y te haga elegir").
        case oroUpgrades
        /// Se desbloqueó el segundo piso: recién ahora el mapa tiene a dónde ir.
        case elevator
        /// El tercer piso: la placa colgante (PLAN-v2 E13, ítem 13).
        case elevatorKeypad
        /// Dos pisos: también se cambia deslizando.
        case floorSwipe
        /// El atajo está gris por piso lleno.
        case floorFull
        /// La ficha del personaje (mantener presionado).
        case characterSheet
        /// Tres pestañas abiertas: el menú también se desliza.
        case menuSwipe
        /// Cinco contrataciones: cada compra del mismo empleado encarece la siguiente (+6 %).
        case hirePriceStep
        /// Una vez, suave, en la segunda sesión con la fase hecha.
        case store
        /// Un piso con todos sus lugares ocupados (pisos en marcha, E2a).
        case staffedFloors
        /// El indicador de reencarnar se encendió por primera vez.
        case prestige
        /// Reencarnar pide llegar al tier más alto de la vida anterior (piso móvil, E2a).
        case prestigeGate
        /// El primer momento viral ofrecido: el botón de compartir y su premio.
        case share
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
        /// Alguien en escena esperando que lo toquen: la primera visita enseña el
        /// chip. Una visita se va sola: si otra lección tiene el turno, se pierde.
        case visitor
        /// Un evento corriendo deja su chip: la primera vez se enseña a tocarlo.
        case eventChip
        /// El primer especial conseguido: vive en el Álbum de la Oficina central.
        case album
        /// ORO para gastar: la mitad «Gastar ORO» de la Tienda y los topes del día.
        case oroShop
        /// El azar pagado con ORO muestra sus probabilidades a la vista.
        case luck
        /// Una pinta de ORO a la venta que el saldo alcanza.
        case cosmetics
        /// Un ×3 comprado, esperando a la próxima vuelta o al próximo premio diario.
        case pendingTriple
        /// El auto-tap corriendo.
        case autoTap
        /// Una oferta de 24 h ya vista, con su chip bajo el HUD.
        case offers
        /// Lugares extra comprados.
        case extraSlots
        /// Ya hay jerarquías: cuatro tipos vistos y el Menú abierto.
        case orgChart

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
                 .gifts, .store, .prestige, .boosts, .chests: .v1
            case .quickHire, .newTabs, .elevatorKeypad, .characterSheet, .menuSwipe, .hirePriceStep, .staffedFloors,
                 .prestigeGate, .share, .sideRail, .packages, .mattress, .wheel, .mergeAllVideo, .visitor, .eventChip,
                 .album, .oroShop, .luck, .cosmetics, .pendingTriple, .autoTap, .offers, .extraSlots: .v2
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
            case .boosts, .chests: .gifts
            case .hirePriceStep: .hire
            case .menuSwipe: .upgrades
            case .newTabs, .pendingTriple, .extraSlots: .bottomBar
            case .oroShop, .luck, .cosmetics: .store
            case .autoTap: .autoTapChip
            case .offers: .offerChip
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
            case .gifts, .boosts, .chests: .gifts
            case .store, .oroShop, .luck, .cosmetics: .store
            case .hirePriceStep: .jobs
            case .visitor, .eventChip, .elevator, .elevatorKeypad, .quickHire, .floorSwipe, .floorFull, .staffedFloors,
                 .prestige, .prestigeGate, .characterSheet, .share, .sideRail, .packages, .mattress, .wheel, .mergeAllVideo,
                 .menuSwipe, .newTabs, .pendingTriple, .autoTap, .offers, .extraSlots: nil
            }
        }

        /// El guion de la lección (PLAN-v2 E9): cada una declara el suyo. Las que venían de la v1 y de
        /// E3b–E7b conservan su señal —abrir su hoja, o su acción firma— y su texto de siempre.
        ///
        /// ⚠️ El cierre «listo» de Mejoras y del pasivo vive en el tablero y no en la hoja: con la
        /// hoja cerrada `rewindToBoard` devuelve un paso de hoja al que abre la lección, y quien
        /// compró y cerró el menú volvería a oír «abrí Mejoras».
        var steps: [TutorialStep] {
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
            case .boosts: [
                .act("boosts.open", .screenOpened(.gifts), text: "tutorial.boosts.open", on: .gifts),
                .explain("boosts.explain", text: "tutorial.boosts.explain", on: .giftsBoosts, surface: .page(.gifts)),
            ]
            case .chests: [
                .act("chests.open", .screenOpened(.gifts), text: "tutorial.chests.open", on: .gifts),
                .explain("chests.explain", text: "tutorial.chests.explain", on: .giftsChest, surface: .page(.gifts)),
            ]
            case .hirePriceStep: [
                .act("hire_price_step.open", .screenOpened(.jobs), text: "tutorial.hire_price_step.open", on: .hire),
                .explain("hire_price_step.explain", text: "tutorial.hire_price_step.explain", on: .jobsPriceStep,
                         surface: .page(.jobs)),
            ]
            case .menuSwipe: [
                .act("menu_swipe.open", .screenOpened(.upgrades), text: "tutorial.menu_swipe.open", on: .upgrades),
                .act("menu_swipe.swipe", .pagerMoved, text: "tutorial.menu_swipe.swipe", on: .menuPager,
                     surface: .page(.upgrades), hand: .swipe(.left)),
            ]
            case .newTabs: [
                .explain("new_tabs.explain", text: "tutorial.new_tabs.explain"),
            ]
            case .oroShop: [
                .act("oro_shop.open", .screenOpened(.store), text: "tutorial.oro_shop.open", on: .store),
                .act("oro_shop.spend", .lessonAction, text: "tutorial.oro_shop.spend", on: .oroShop, surface: .page(.store)),
                .explain("oro_shop.caps", text: "tutorial.oro_shop.caps", surface: .page(.store)),
            ]
            case .luck: [
                .act("luck.open", .screenOpened(.store), text: "tutorial.luck.open", on: .store),
                .act("luck.spend", .lessonAction, text: "tutorial.luck.spend", on: .oroShop, surface: .page(.store)),
                .explain("luck.odds", text: "tutorial.luck.odds", on: .storeOdds, surface: .page(.store)),
            ]
            case .cosmetics: [
                .act("cosmetics.open", .screenOpened(.store), text: "tutorial.cosmetics.open", on: .store),
                .act("cosmetics.spend", .lessonAction, text: "tutorial.cosmetics.spend", on: .oroShop, surface: .page(.store)),
                .explain("cosmetics.where", text: "tutorial.cosmetics.where", on: .storeCosmetics, surface: .page(.store)),
            ]
            case .pendingTriple: [
                .explain("pending_triple.explain", text: "tutorial.pending_triple.explain"),
            ]
            case .autoTap: [
                .explain("auto_tap.explain", text: "tutorial.auto_tap.explain", on: .autoTapChip),
            ]
            case .offers: [
                .explain("offers.chip", text: "tutorial.offers.chip", on: .offerChip),
            ]
            case .extraSlots: [
                .explain("extra_slots.explain", text: "tutorial.extra_slots.explain"),
            ]
            case .elevator: [
                .act("elevator.open", .lessonAction, text: "tutorial.tip.elevator", on: .map),
            ]
            case .elevatorKeypad: [
                .act("elevator_keypad.open", .lessonAction, text: "tutorial.tip.elevator.hold", on: .map),
            ]
            case .skins: [
                .act("skins.open", .screenOpened(.skins), text: "tutorial.tip.skins", on: .skins),
            ]
            case .achievements: [
                .act("achievements.open", .screenOpened(.menu), text: "tutorial.tip.achievements", on: .menu),
            ]
            case .oroUpgrades: [
                .act("oro_upgrades.open", .screenOpened(.upgrades), text: "tutorial.tip.oro", on: .upgrades),
            ]
            case .gifts: [
                .act("gifts.open", .screenOpened(.gifts), text: "tutorial.tip.gifts", on: .gifts),
            ]
            case .store: [
                .act("store.open", .screenOpened(.store), text: "tutorial.tip.store", on: .store),
            ]
            case .share: [
                .act("share.tap", .lessonAction, text: "tutorial.tip.share", on: .share),
            ]
            case .visitor: [
                .act("visitor.tap", .lessonAction, text: "tutorial.tip.visitor", on: .visitor),
            ]
            case .eventChip: [
                .act("event_chip.tap", .lessonAction, text: "tutorial.tip.event_chip", on: .eventChip),
            ]
            case .album: [
                .act("album.open", .screenOpened(.menu), text: "tutorial.tip.album", on: .menu),
            ]
            case .sideRail: [
                .act("side_rail.open", .lessonAction, text: "tutorial.tip.side_rail", on: .sideRail),
            ]
            case .packages: [
                .act("packages.tap", .lessonAction, text: "tutorial.tip.packages", on: .sidePackages),
            ]
            case .mattress: [
                .act("mattress.tap", .lessonAction, text: "tutorial.tip.mattress", on: .sideMattress),
            ]
            case .wheel: [
                .act("wheel.tap", .lessonAction, text: "tutorial.tip.wheel.rail", on: .sideWheel),
            ]
            case .mergeAllVideo: [
                .act("merge_all_video.tap", .lessonAction, text: "tutorial.tip.merge_all_video", on: .sideBoost),
            ]
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
        case .boosts:
            unlockedTabs.contains(.gifts) && isLessonDone(.gifts)
                && (player?.meta.stats.boostsActivatedEver ?? 0) == 0 && hasUsableBoost()
        case .chests:
            unlockedTabs.contains(.gifts) && canOpenChest
        case .hirePriceStep:
            (player?.meta.stats.totalHiresEver ?? 0) >= 5 && quickHirePriceStepIsShown()
        case .menuSwipe:
            unlockedTabsInBarOrder.count >= 3
        case .newTabs:
            !newTabs.isEmpty
        case .oroShop:
            cheapestOroShopPrice().map { (player?.meta.oro ?? 0) >= $0 } ?? false
        case .luck:
            luckMomentIsOn()
        case .cosmetics:
            isLessonDone(.oroShop) && cheapestCosmeticPrice().map { (player?.meta.oro ?? 0) >= $0 } ?? false
        case .pendingTriple:
            hasPendingTriple
        case .autoTap:
            activeBonuses.contains { $0.effect == .autoTapPerSecond }
        case .offers:
            visibleOffers().contains(where: \.presented)
        case .extraSlots:
            (player?.meta.engagement.shop.levels["extra_slots"] ?? 0) > 0
        }
    }

    /// Un boost desbloqueado y sin enfriamiento: lo que Regalos ofrece activar hoy.
    private func hasUsableBoost() -> Bool {
        guard let content, let player else { return false }
        let now = Date().timeIntervalSince1970
        return content.boosts.boosts.contains {
            isBoostUnlocked($0) && BoostManager.cooldownRemaining(of: $0, state: player, now: now) <= 0
        }
    }

    /// FisuJobs muestra el «+6 %» en la fila que el atajo contrataría hoy, y a ésa la alcanza la plata.
    private func quickHirePriceStepIsShown() -> Bool {
        guard let player, let offer = quickHireOffer, offer.affordable else { return false }
        return priceTrend(player: player, typeId: offer.typeId).step != nil
    }

    /// El ×3 de la vuelta o del premio diario, comprado y esperando su momento.
    private var hasPendingTriple: Bool {
        guard let shop = player?.meta.engagement.shop else { return false }
        return shop.pendingOfflineMultiplier != nil || shop.pendingDailyMultiplier != nil
    }

    /// Lo más barato que la tienda de ORO ofrece hoy (lo que no se vende, no cuenta).
    func cheapestOroShopPrice() -> Int? {
        guard let content, let player else { return nil }
        return content.oroShop.items.compactMap { item -> Int? in
            if item.isChance, !LootBoxGate.lastKnown { return nil }
            if let floor = item.unlockFloorId,
               (content.floorTable.ordinal(of: floor) ?? .max) > player.meta.stats.maxFloorOrdinalEver { return nil }
            return item.price ?? item.levels.first?.price
        }.min()
    }

    /// La pinta de ORO más barata que todavía no es tuya.
    func cheapestCosmeticPrice() -> Int? {
        guard let content, let player else { return nil }
        let owned = player.meta.allOwnedSkins
        return content.skins.skins.compactMap { skin in
            skin.oroPrice.flatMap { owned.contains(skin.id) ? nil : $0 }
        }.min()
    }

    /// El azar pagado muestra sus probabilidades: la tienda de ORO ya se enseñó, la puerta del azar
    /// está abierta y el cofre tiene qué sortear.
    func luckMomentIsOn(chanceAllowed: Bool = LootBoxGate.lastKnown) -> Bool {
        isLessonDone(.oroShop) && chanceAllowed && chestOdds != .nothingYet
    }

    /// El jugador eligió «Gastar ORO» en la Tienda: cumple el paso que lo pide.
    func oroShopSpendChosen() {
        guard let id = tutorialRun?.lessonID, [TutorialLesson.oroShop, .luck, .cosmetics].map(\.rawValue).contains(id)
        else { return }
        tutorialSignal(.lessonAction(id))
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
