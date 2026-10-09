import EconomyKit
import Foundation
import SwiftUI

extension GameState {
    var isRecoveryPending: Bool {
        if case .recovery = phase { true } else { false }
    }

    func bootstrap() async {
        do {
            let content = try GameContentLoader.load(from: .main)
            self.content = content
            self.economy = StandardEconomy(config: content.economy)
            UIArt.configure(available: Set(content.manifest.ui.keys))

            let repository = self.repository ?? injectedRepository ?? PlayerStateRepository(
                persistence: PersistenceController(),
                snapshotURL: PlayerStateRepository.defaultSnapshotURL(),
                backups: SaveBackupStore(directory: SaveBackupStore.defaultDirectory())
            )
            self.repository = repository

            // Infra de UI tests: estado limpio y determinístico por launch argument.
            var forceNewGame = false
            #if DEBUG
            forceNewGame = ProcessInfo.processInfo.arguments.contains("--uitest-reset")
            applyLaunchArgumentDefaults(forceNewGame: forceNewGame)
            #endif

            if content.flags.cloudKitEnabled {
                cloudSync = CloudSaveSync()
            }

            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--uitest-unreadable-save") {
                await repository.debugWriteUnreadableSave()
            }
            #endif
            var loaded: SaveLoadResult = .empty
            if !forceNewGame {
                loaded = await repository.load()
            }
            let isFreshInstall: Bool
            switch loaded {
            case .loaded(let saved):
                var resolved = saved
                if let cloudSync, let remote = try? await cloudSync.fetch() {
                    resolved = SaveConflictResolver.resolve(local: saved, remote: remote)
                }
                player = resolved
                isFreshInstall = false
                Log.lifecycle.info("save loaded: prestige \(resolved.meta.prestigeLevel), maxTier \(resolved.run.maxTierReached)")
            case .empty:
                let fresh = newGame(content: content)
                player = fresh
                await repository.save(fresh)
                isFreshInstall = true
                Log.lifecycle.info("new game started")
            case .unreadable(let info):
                phase = .recovery(info)
                return
            }
            finishBootstrap(isFreshInstall: isFreshInstall)
        } catch let error as GameError {
            Log.lifecycle.critical("bootstrap failed: \(error.debugDetail)")
            assertionFailure(error.debugDetail)
            phase = .failed(error.localizedDescription)
        } catch {
            Log.lifecycle.critical("bootstrap failed: \(error)")
            assertionFailure("\(error)")
            phase = .failed(String(localized: "error.content.message"))
        }
    }

    private func newGame(content: GameContent) -> PlayerState {
        PlayerState.newGame(
            startTypeId: content.tiers.baseType.id,
            startFloorId: content.floorTable[0].id,
            offlineEfficiencyBase: content.economy.offlineEfficiencyBase,
            critChanceBase: content.economy.critChanceBase,
            now: Date().timeIntervalSince1970
        )
    }

    func retryLoad() async {
        guard isRecoveryPending else { return }
        phase = .loading
        await bootstrap()
    }

    /// Empieza una partida nueva. La copia ilegible ya quedó en `SaveBackups/`; si al
    /// arrancar no se pudo escribir, se reintenta ahora que el snapshot todavía está.
    func startOverFromRecovery() async {
        guard isRecoveryPending, let content, let repository else { return }
        repository.keepSnapshotCopy()
        let fresh = newGame(content: content)
        player = fresh
        phase = .loading
        await repository.save(fresh)
        finishBootstrap(isFreshInstall: true)
    }

    /// Todo lo que va después de tener un `player`: la torre, los fixtures de DEBUG, el
    /// tutorial, offline y daily, y el paso a `.ready`. Lo comparten el arranque normal y
    /// `startOverFromRecovery`.
    private func finishBootstrap(isFreshInstall: Bool) {
        guard let content else { return }
        reconcileTower()
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--uitest-unlock-tower") {
            debugUnlockFloors(throughTier: 5)
        }
        // La torre entera (diez pisos): la placa del ascensor en el peor caso.
        if ProcessInfo.processInfo.arguments.contains("--uitest-unlock-tower-all") {
            debugUnlockFloors(throughTier: .max)
        }
        if ProcessInfo.processInfo.arguments.contains("--uitest-board-change") {
            debugPlanBoardChange()
        }
        // RF-05: el menú de mejoras lista lo que el jugador VIO, no los pisos
        // que abrió, así que abrir la torre no alcanza para tener varias
        // filas en pantalla.
        if ProcessInfo.processInfo.arguments.contains("--uitest-seen-types") {
            // Hasta 8 y no hasta 6 para que entre "Empleado de Fast Food":
            // el nombre más largo del tramo, que es el que muestra si el
            // encabezado aguanta al lado de la carita grande.
            debugMarkTypesSeen(throughTier: 8)
        }
        // Las skins de milestone de los personajes que el jugador YA vio.
        // Ganarlas jugando pide abrir pisos o reencarnar, así que sin esta
        // puerta el Customization Shop no tiene una sola pinta que ponerse y
        // no hay forma de ejercer "Ponérsela". Va DESPUÉS de
        // `--uitest-seen-types` porque se apoya en lo que ese marcó.
        if ProcessInfo.processInfo.arguments.contains("--uitest-skins"), let player {
            let seen = player.run.seenTypes
            grantMilestoneSkinsForTests(
                content.skins.skins
                    .filter { $0.isMilestone && seen.contains($0.characterType) }
                    .map(\.id)
            )
        }
        // Y su opuesto: la pinta de alguien que el jugador NUNCA vio, que es
        // lo que un cofre reparte casi siempre. Va DESPUÉS del de arriba por
        // el mismo motivo —se apoya en `seenTypes`— y separado porque son
        // los dos lados del criterio de Pintas: uno deja las dos pantallas
        // listando lo mismo y el otro las separa.
        if ProcessInfo.processInfo.arguments.contains("--uitest-unseen-skin") {
            debugGrantUnseenChestSkin()
        }
        // El Fisura con el multiplicador al tope. Llegar jugando pide
        // comprar las 19 mejoras de la línea: sin esta puerta, el estado
        // "Al máximo" de la fila no se puede ni fotografiar ni ejercitar.
        if ProcessInfo.processInfo.arguments.contains("--uitest-char-upgrades-maxed"),
           var player {
            player.run.charUpgradeLevels["homeless"] = content.economy.charUpgrades.maxLevel
            self.player = player
        }
        // RF-16: el ORO va con la raíz de lifetime/divisor, así que llegar
        // al prestigio jugando no es automatizable. El fixture lo acredita —
        // derivado de la config y no un literal, que es lo que se rompía en
        // silencio cada vez que el balance movía el divisor.
        if ProcessInfo.processInfo.arguments.contains("--uitest-prestige") {
            giveEarningsForPrestigeTesting(oro: 9)
        }
        // El primer Fisura cuesta 25 y un tap rinde 1: llegar a contratar
        // jugando son ~25 toques sobre un personaje que deambula. El fixture
        // acredita la plata para que el test del tutorial mida el TUTORIAL y
        // no la puntería del runner.
        if ProcessInfo.processInfo.arguments.contains("--uitest-coins") {
            debugGrantCoins()
        }
        // El Corralito en curso, con su banner y su salida por video: el evento
        // real es RNG con cooldown de 40 minutos y tier mínimo 6.
        if ProcessInfo.processInfo.arguments.contains("--uitest-corralito") {
            debugStartCorralito()
        }
        // La tira del calendario de Regalos con días ya cobrados atrás. Va
        // ANTES del claim automático de más abajo a propósito: en una partida
        // nueva ese claim no corre (FTUE) y sólo marca `lastClaimDay`, así que
        // el `cycleDay` que se pone acá es el que termina en pantalla.
        if ProcessInfo.processInfo.arguments.contains("--uitest-daily-streak") {
            debugSetDailyCycleDay(4)
        }
        // El popup de ganancias offline, con su oferta de duplicar por
        // video. El camino real pide cerrar la app y volver horas después
        // CON producción pasiva armada; una partida nueva produce 0/s y el
        // offline acredita cero, así que la hoja no aparecería. El fixture
        // entrega el estado final — el porqué está en
        // `debugPresentOfflineReward`.
        if ProcessInfo.processInfo.arguments.contains("--uitest-offline") {
            debugPresentOfflineReward(amount: 12_345)
        }
        // El primer special del catálogo, cayendo ya mismo: el drop real es
        // RNG sobre merges (la carta no se puede ni fotografiar ni
        // ejercitar sin suerte) y activarlo deja al personaje en el
        // tablero, que es lo que necesita el recap del mantener-apretado.
        if ProcessInfo.processInfo.arguments.contains("--uitest-special") {
            debugDropFirstSpecial()
        }
        // Un cofre abierto, con su animación esperando el primer toque. El
        // camino real pide dos pisos desbloqueados o un video con cooldown,
        // así que sin la puerta el smoke de la animación mediría la suerte.
        if ProcessInfo.processInfo.arguments.contains("--uitest-chest") {
            debugOpenChest()
        }
        // Tres logros conseguidos y sin cobrar: es la única forma de ver la
        // sección "Para cobrar" de la pantalla de Logros con algo adentro.
        // Va DESPUÉS de los otros fixtures a propósito —`--uitest-coins`
        // mueve `lifetimeEarnings` y cruza su propio logro— para que su
        // `evaluateAchievements()` acredite todo de una pasada.
        if ProcessInfo.processInfo.arguments.contains("--uitest-achievements") {
            debugSeedAchievements()
        }
        // El long-press sobre SpriteKit no es determinista en el runner: para
        // el smoke de la ficha alcanza con abrirla sobre la primera unidad.
        if ProcessInfo.processInfo.arguments.contains("--uitest-open-sheet"),
           let slot = visiblePlacements.first?.slot {
            presentCharacterSheet(cellIndex: slot)
        }
        // El fork de carrera, abierto.
        //
        // Es la pantalla más cara de alcanzar del juego: hay que llegar a T9
        // y fusionar el par, o sea horas de partida, y una vez elegida NO
        // vuelve a aparecer hasta la próxima reencarnación. Sin esta puerta
        // no se puede ni fotografiar ni ejercitar — y de hecho es la única
        // pantalla que quedó sin un solo test de UI, que es exactamente por
        // qué se hizo vieja sin que nadie lo notara.
        if ProcessInfo.processInfo.arguments.contains("--uitest-career") {
            debugPresentCareerChoice()
        }
        // La partida rankeada corriendo y a un tier de Dios: el test sólo arma el escenario del
        // servidor (`--uitest-ranking-<escenario>`) y llega con `debugReachGod()`.
        if ProcessInfo.processInfo.arguments.contains("--uitest-ranking-god") {
            debugStartRankedRunNearGod()
        }
        // El peor caso de la spec de los videos (fondo + especial + ícono) con la sonda corriendo.
        // El manifest de estrés lo arma `LoopsManifest.main`; con los videos prendidos hace falta
        // pasar también `--uitest-video`.
        if ProcessInfo.processInfo.arguments.contains("--uitest-anim-stress") {
            debugStartAnimStress()
        }
        #endif
        // El tutorial entra a la cola ANTES de que nadie encole nada: el
        // offline, el daily del día 2 y los logros de un save viejo pasan
        // todos por `syncCelebrations`, y el gate tiene que estar puesto
        // primero o alguno toma el turno con el tutorial arriba (el
        // deadlock medido el 2026-08-21: sheet gateado que nunca se
        // presenta y cola congelada).
        //
        // Bajo XCTest no: el host de los unit tests arranca con los
        // defaults en cualquier estado y cada test arma su propio
        // escenario con `beginTutorialPhase()` (mismo criterio que
        // `StoreManager` con su `SKTestSession`).
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil {
            if !UserDefaults.standard.bool(forKey: "fisuTutorialDone") {
                beginTutorialPhase()
            } else {
                // La lección de Tienda espera a la SEGUNDA sesión con la
                // fase hecha ("una vez, suave": nunca en el mismo arranque
                // en el que el jugador recién aprendió a jugar).
                let sessions = UserDefaults.standard.integer(forKey: Self.sessionsAfterPhaseKey)
                UserDefaults.standard.set(sessions + 1, forKey: Self.sessionsAfterPhaseKey)
            }
        }
        applyOfflineProgressIfNeeded()
        // El primer launch de una cuenta nueva no reclama daily: el jugador
        // todavía no jugó y el popup compite con el tutorial (FTUE).
        if !isFreshInstall {
            claimDailyIfAvailable()
        } else if var player {
            player.meta.daily.lastClaimDay = DailyRewardManager.dayString(for: Date())
            self.player = player
        }
        #if DEBUG
        // El popup del premio del día, abierto. Va DESPUÉS del bloque de
        // arriba porque es justamente ese bloque el que lo hace imposible:
        // una partida nueva marca `lastClaimDay` en HOY para no pisar el
        // tutorial, y el daily se cobra una sola vez por día. Sin esta
        // puerta, la única pantalla que celebra la racha no se puede ni
        // fotografiar ni ejercitar sin cambiarle la fecha al simulador.
        // Combinado con `--uitest-daily-streak` muestra el día 4.
        if ProcessInfo.processInfo.arguments.contains("--uitest-daily-popup") {
            debugClaimDailyAgain()
        }
        #endif
        scheduleNextEvent(from: Date().timeIntervalSince1970)
        // Una sola pasada post-carga: un save escrito ANTES de que
        // existieran los logros llega con medio catálogo ya ganado, y sin
        // esto quedaría esperando a la próxima fusión para enterarse.
        // Corre con `phase == .loading`, así que acredita sin toastear.
        evaluateAchievements()
        refreshProjections()
        phase = .ready
    }
}
