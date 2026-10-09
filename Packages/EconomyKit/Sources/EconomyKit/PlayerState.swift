import Foundation

/// Derived upgrade effects cached in the save (recomputed by UpgradeManager
/// from `meta.oroUpgradeLevels` × upgrades.json; bible §2.2 + las 7 líneas del plan).
public struct UpgradeState: Codable, Sendable, Equatable {
    public var offlineEfficiency: Double
    public var tapMultiplier: Double
    public var critChance: Double
    /// Multiplicador global de income de la línea de upgrade "income" (v3).
    public var incomeMultiplier: Double
    /// Chance de tap dorado (paga x10) de la línea "golden" (v3).
    public var goldenChance: Double
    /// Descuento de hire de la línea "spawn", 0…1 (v3).
    public var spawnDiscount: Double
    /// Bonus sobre el multiplicador por ORO de la línea "prestige" (v3).
    public var prestigeBonus: Double

    public init(
        offlineEfficiency: Double,
        tapMultiplier: Double,
        critChance: Double,
        incomeMultiplier: Double = 1.0,
        goldenChance: Double = 0.0,
        spawnDiscount: Double = 0.0,
        prestigeBonus: Double = 0.0
    ) {
        self.offlineEfficiency = offlineEfficiency
        self.tapMultiplier = tapMultiplier
        self.critChance = critChance
        self.incomeMultiplier = incomeMultiplier
        self.goldenChance = goldenChance
        self.spawnDiscount = spawnDiscount
        self.prestigeBonus = prestigeBonus
    }

    /// Decodificador a mano, por lo mismo que el de `RunState` y el de
    /// `MetaState`: el sintetizado exige TODA clave que no sea opcional y se
    /// saltea los valores por defecto de las propiedades.
    ///
    /// ⚠️ **Acá el agujero era un save v3, no un v4.** `SaveMigrator.migrate`
    /// entra por `case 3` derecho a `migrateV3toV4`, que **no** pasa por el
    /// backfill de `migrateV2toV3` y copia `old["upgrades"]` tal cual —o `[:]`
    /// si la clave no está—. O sea: un v3 al que le falte cualquiera de estas
    /// siete claves reventaba con `keyNotFound`, el repositorio caía a "starting
    /// fresh" y el jugador perdía la partida entera por un diccionario.
    ///
    /// Los siete van con `decodeIfPresent` y no sólo los cuatro de v3: son
    /// **efectos derivados** —la fuente de verdad es `meta.oroUpgradeLevels`, y
    /// `UpgradeManager.recomputeDerivedEffects` los reconstruye desde ahí en
    /// cuanto el jugador compra algo—, así que caer al valor neutro es
    /// recuperable y perder el save no.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        offlineEfficiency = try container.decodeIfPresent(Double.self, forKey: .offlineEfficiency) ?? 0
        tapMultiplier = try container.decodeIfPresent(Double.self, forKey: .tapMultiplier) ?? 1.0
        critChance = try container.decodeIfPresent(Double.self, forKey: .critChance) ?? 0
        incomeMultiplier = try container.decodeIfPresent(Double.self, forKey: .incomeMultiplier) ?? 1.0
        goldenChance = try container.decodeIfPresent(Double.self, forKey: .goldenChance) ?? 0
        spawnDiscount = try container.decodeIfPresent(Double.self, forKey: .spawnDiscount) ?? 0
        prestigeBonus = try container.decodeIfPresent(Double.self, forKey: .prestigeBonus) ?? 0
    }
}

/// Estado del daily reward (ciclo de 7 días).
public struct DailyRewardState: Codable, Sendable, Equatable {
    /// Día calendario del último claim, "yyyy-MM-dd" en el timezone del device.
    public var lastClaimDay: String?
    /// Posición 1…7 dentro del ciclo (el próximo claim usa este día).
    public var cycleDay: Int

    public init(lastClaimDay: String? = nil, cycleDay: Int = 1) {
        self.lastClaimDay = lastClaimDay
        self.cycleDay = cycleDay
    }
}

/// Lo que MUERE al reencarnar (F7 §6.2). La reencarnación es `run = .fresh(...)`:
/// imposible olvidarse de resetear (o de preservar) un campo.
///
/// Las unidades se guardan POR TIPO (`units`), nunca por posición/piso: la
/// ubicación se reconcilia contra el mapeo `floors[]` vigente en cada carga
/// (`TowerReconciler`), así un remapeo tier→piso entre versiones reacomoda
/// partidas en vez de romperlas (spec §3.1, default ⚠️10).
public struct RunState: Codable, Sendable, Equatable {
    public var coins: Double
    /// typeId → cantidad de instancias vivas. Fuente de verdad canónica.
    public var units: [String: Int]
    public var passiveUnlocked: [String: Bool]
    public var chosenCareerPath: String?
    /// Compras de hire POR PISO (floorId → count): curva de costo del piso.
    /// `Double` y no `Int`: el reintegro del amortiguador los escala por un
    /// factor fraccionario, y `hireCost` ya elevaba con `pow` en `Double`.
    public var hireCounts: [String: Double]
    /// Compras de hire POR TIPO (typeId → count): curva de costo del tipo, la que
    /// usa la pantalla de laburos. Vive en `run` como `hireCounts`: es precio de
    /// esta partida, así que reencarnar la borra.
    public var hireCountsByType: [String: Double]
    /// Tier máximo alcanzado en esta run; gatea events/specials/asado/daily.
    /// Se escribe sólo con `raiseFrontier`.
    public internal(set) var maxTierReached: Int
    /// Mejoras por personaje compradas con plata (typeId → nivel). ×2/nivel.
    public var charUpgradeLevels: [String: Int]
    /// Pisos desbloqueados, por ID de piso (nunca por índice ni tier: un remapeo
    /// futuro no re-bloquea lo ya desbloqueado — spec §3.8).
    public var unlockedFloors: [String]
    /// Modificadores temporales vivos (rewarded/eventos/boosts).
    public var activeModifiers: [ActiveModifier]
    /// Tipos que el jugador vio alguna vez EN ESTA RUN. La lista de mejoras se
    /// arma con esto y no con las unidades vivas: mergear tu último Fisura no
    /// tiene por qué borrarte de la pantalla la mejora que le compraste
    /// (RF-03). `TowerReconciler` los rellena en la carga.
    public var seenTypes: Set<String>
    /// Cuántos cofres dio la torre en ESTA partida. Muere con la run a
    /// propósito: volver a subir la torre vuelve a pagar, que es lo que empuja
    /// a reencarnar.
    public var floorChestsAwarded: Int
    /// Hasta qué tier ya se le mostró su revelación al jugador. Red de seguridad:
    /// si queda por debajo de `maxTierReached`, falta una revelación por encolar.
    /// Un save que no lo trae arranca parejo con la frontera: nunca una lluvia de
    /// revelaciones al actualizar.
    public var revealedTier: Int
    /// El `D` del amortiguador de precios: contratar cuesta `v1 / D`, y 1 es el
    /// precio de la v1. Es de la run: reencarnar lo devuelve a 1.
    public var priceRelief: Double

    public init(
        coins: Double,
        units: [String: Int],
        passiveUnlocked: [String: Bool],
        chosenCareerPath: String?,
        hireCounts: [String: Double],
        hireCountsByType: [String: Double] = [:],
        maxTierReached: Int,
        charUpgradeLevels: [String: Int],
        unlockedFloors: [String],
        activeModifiers: [ActiveModifier],
        seenTypes: Set<String> = [],
        floorChestsAwarded: Int = 0,
        revealedTier: Int? = nil,
        priceRelief: Double = 1
    ) {
        self.coins = coins
        self.units = units
        self.passiveUnlocked = passiveUnlocked
        self.chosenCareerPath = chosenCareerPath
        self.hireCounts = hireCounts
        self.hireCountsByType = hireCountsByType
        self.maxTierReached = maxTierReached
        self.charUpgradeLevels = charUpgradeLevels
        self.unlockedFloors = unlockedFloors
        self.activeModifiers = activeModifiers
        self.seenTypes = seenTypes
        self.floorChestsAwarded = floorChestsAwarded
        self.revealedTier = revealedTier ?? maxTierReached
        self.priceRelief = priceRelief
    }

    /// Decodificador a mano: el sintetizado exige TODA clave que no sea opcional
    /// y se saltea los valores por defecto de las propiedades, así que un save v4
    /// escrito antes de que existiera un campo tira `keyNotFound` y el jugador
    /// pierde la partida. Cada campo agregado después de v4 se lee con
    /// `decodeIfPresent ?? default`; los que todo v4 tiene, con `decode`.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        coins = try container.decode(Double.self, forKey: .coins)
        units = try container.decode([String: Int].self, forKey: .units)
        passiveUnlocked = try container.decode([String: Bool].self, forKey: .passiveUnlocked)
        // Opcional de verdad: el encoder omite la clave mientras no se eligió carrera.
        chosenCareerPath = try container.decodeIfPresent(String.self, forKey: .chosenCareerPath)
        hireCounts = try container.decode([String: Double].self, forKey: .hireCounts)
        hireCountsByType = try container.decodeIfPresent([String: Double].self, forKey: .hireCountsByType) ?? [:]
        maxTierReached = try container.decode(Int.self, forKey: .maxTierReached)
        charUpgradeLevels = try container.decode([String: Int].self, forKey: .charUpgradeLevels)
        unlockedFloors = try container.decode([String].self, forKey: .unlockedFloors)
        activeModifiers = try container.decode([ActiveModifier].self, forKey: .activeModifiers)
        seenTypes = try container.decodeIfPresent(Set<String>.self, forKey: .seenTypes) ?? []
        floorChestsAwarded = try container.decodeIfPresent(Int.self, forKey: .floorChestsAwarded) ?? 0
        revealedTier = try container.decodeIfPresent(Int.self, forKey: .revealedTier) ?? maxTierReached
        priceRelief = try container.decodeIfPresent(Double.self, forKey: .priceRelief) ?? 1
    }

    /// Run recién nacida: una unidad base, piso 1 desbloqueado. Reencarnar es
    /// exactamente esto, así que los vistos arrancan sólo con el tipo base.
    public static func fresh(startTypeId: String, startFloorId: String) -> RunState {
        RunState(
            coins: 0,
            units: [startTypeId: 1],
            passiveUnlocked: [:],
            chosenCareerPath: nil,
            hireCounts: [:],
            hireCountsByType: [:],
            maxTierReached: 1,
            charUpgradeLevels: [:],
            unlockedFloors: [startFloorId],
            activeModifiers: [],
            seenTypes: [startTypeId]
        )
    }

    /// Total de unidades vivas en la torre.
    public var totalUnits: Int { units.values.reduce(0, +) }

    /// Registra un tipo como visto en esta run. Lo llama TODO camino que crea
    /// una unidad: contratar, mergear, los regalos de evento y los fixtures.
    public mutating func markSeen(_ typeId: String) { seenTypes.insert(typeId) }
}

extension RunState {
    /// Único escritor de `maxTierReached`: la frontera sólo sube. Devuelve si
    /// subió, para que el llamador sepa si hay algo que celebrar o reconciliar.
    @discardableResult
    public mutating func raiseFrontier(to tier: Int) -> Bool {
        guard tier > maxTierReached else { return false }
        maxTierReached = tier
        return true
    }

    /// Sube la frontera y, con el amortiguador, guarda el salto del precio en
    /// `priceRelief`. Es la que usan las fusiones del juego y el simulador; la
    /// de un argumento queda para la carga (`TowerReconciler`), los fixtures y
    /// el panel de debug, que no amortiguan.
    @discardableResult
    public mutating func raiseFrontier(to tier: Int, cushion: PriceCushion) -> Bool {
        let before = maxTierReached
        guard raiseFrontier(to: tier) else { return false }
        priceRelief = cushion.relief(priceRelief, raisingFrom: before, to: maxTierReached)
        return true
    }

    /// Único escritor de las curvas de compra (por piso y por tipo). Una compra
    /// que cuenta también descuenta un paso del amortiguador.
    public mutating func registerHire(floorId: String, typeId: String, cushion: PriceCushion) {
        hireCounts[floorId, default: 0] += 1
        hireCountsByType[typeId, default: 0] += 1
        priceRelief = cushion.relief(priceRelief, afterPurchaseAt: maxTierReached)
    }

    /// Fusionar un par devuelve `counts` compras a la curva del tipo fusionado y
    /// a la de su piso (PLAN-v2 E2a, el reintegro). Nunca baja de cero, y un
    /// contador que llega a cero sale del diccionario.
    public mutating func refundMergeCounts(typeId: String, floorId: String, counts: Double) {
        guard counts > 0 else { return }
        hireCountsByType[typeId] = Self.lowered(hireCountsByType[typeId], by: counts)
        hireCounts[floorId] = Self.lowered(hireCounts[floorId], by: counts)
    }

    private static func lowered(_ count: Double?, by amount: Double) -> Double? {
        let left = (count ?? 0) - amount
        return left > 0 ? left : nil
    }
}

/// Estadísticas de cuenta (no afectan gameplay). Monótonas y a prueba de
/// reencarnación: son la materia prima de la pantalla de stats y de los logros.
public struct MetaStats: Codable, Sendable, Equatable {
    /// Ordinal máximo de piso alcanzado en la historia de la cuenta.
    public var maxFloorOrdinalEver: Int
    /// Fusiones hechas en toda la historia de la cuenta.
    public var totalMergesEver: Int
    /// Contrataciones hechas en toda la historia de la cuenta.
    public var totalHiresEver: Int
    /// Toques cobrados en toda la historia de la cuenta.
    public var totalTapsEver: Int
    /// Videos con recompensa mirados en toda la historia de la cuenta.
    public var videosWatchedEver: Int
    /// Boosts activados en toda la historia de la cuenta.
    public var boostsActivatedEver: Int
    /// ORO gastado en toda la historia de la cuenta. Sólo lo mueve `MetaState.spendOro`.
    public var oroSpentEver: Int

    public init(
        maxFloorOrdinalEver: Int = 0,
        totalMergesEver: Int = 0,
        totalHiresEver: Int = 0,
        totalTapsEver: Int = 0,
        videosWatchedEver: Int = 0,
        boostsActivatedEver: Int = 0,
        oroSpentEver: Int = 0
    ) {
        self.maxFloorOrdinalEver = maxFloorOrdinalEver
        self.totalMergesEver = totalMergesEver
        self.totalHiresEver = totalHiresEver
        self.totalTapsEver = totalTapsEver
        self.videosWatchedEver = videosWatchedEver
        self.boostsActivatedEver = boostsActivatedEver
        self.oroSpentEver = oroSpentEver
    }

    /// Decodificador a mano por lo mismo que el de `MetaState`: los saves v4 ya
    /// escritos sólo tienen `maxFloorOrdinalEver` y el sintetizado exigiría el
    /// resto. Un contador que falta es cero, nunca una partida perdida.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        maxFloorOrdinalEver = try container.decodeIfPresent(Int.self, forKey: .maxFloorOrdinalEver) ?? 0
        totalMergesEver = try container.decodeIfPresent(Int.self, forKey: .totalMergesEver) ?? 0
        totalHiresEver = try container.decodeIfPresent(Int.self, forKey: .totalHiresEver) ?? 0
        totalTapsEver = try container.decodeIfPresent(Int.self, forKey: .totalTapsEver) ?? 0
        videosWatchedEver = try container.decodeIfPresent(Int.self, forKey: .videosWatchedEver) ?? 0
        boostsActivatedEver = try container.decodeIfPresent(Int.self, forKey: .boostsActivatedEver) ?? 0
        oroSpentEver = try container.decodeIfPresent(Int.self, forKey: .oroSpentEver) ?? 0
    }
}

/// Lo que SOBREVIVE a la reencarnación (F7 §6.2): ORO, mejoras permanentes,
/// skins, entitlements, daily, stats.
public struct MetaState: Codable, Sendable, Equatable {
    /// Monotonically increasing across the whole account — never reset, not even by
    /// reincarnation. Drives ORO and CloudKit conflict resolution.
    public var lifetimeEarnings: Double
    /// Balance gastable de ORO (moneda de prestigio).
    public var oro: Int
    /// ORO ganado en la historia de la cuenta (monótono). El multiplicador global
    /// se computa sobre ESTO, no sobre el balance: gastar ORO nunca nerfea.
    public var oroEarnedLifetime: Int
    /// Cantidad de reencarnaciones.
    public var prestigeLevel: Int
    /// Niveles comprados por línea de mejora PERMANENTE (upgrades.json, en ORO).
    public var oroUpgradeLevels: [String: Int]
    /// Efectos derivados cacheados (recomputados por UpgradeManager en bootstrap).
    public var derivedEffects: UpgradeState
    /// 1 + oroEarnedLifetime × perOro × (1 + prestigeBonus). Cacheado.
    public var globalMultiplier: Double
    public var ownedSpecials: [String]
    /// Piso (id) al que quedó anclado visualmente cada special. Sin slot (⚠️5).
    public var specialAnchors: [String: String]
    /// Skins de IAP (cache de entitlements — StoreKit la REESCRIBE entera).
    public var ownedSkins: [String]
    /// Skins ganadas por milestone (separadas: StoreKit no debe pisarlas).
    public var milestoneSkins: [String]
    /// Skin activa POR TIPO de personaje (typeId → skinId). Una por tipo (⚠️7).
    public var activeSkinByType: [String: String]
    public var removedAds: Bool
    /// Última activación por boost id (cooldowns; sobreviven la reencarnación
    /// para evitar el exploit de resetear cooldowns reencarnando).
    public var boostActivations: [String: TimeInterval]
    /// Última vez que se cobró cada recompensa por video (RF-11). Vive acá y no
    /// en `run` por lo mismo que `boostActivations`: si muriera al reencarnar,
    /// reencarnar sería la forma de mirar los videos otra vez.
    public var rewardedActivations: [String: TimeInterval]
    /// IDs de transacción de StoreKit ya acreditadas. Un entitlement se
    /// reescribe entero en cada sync y es idempotente por construcción; un
    /// consumible es un DELTA, así que acreditarlo dos veces regala plata. Vive
    /// en el save y no en memoria porque una transacción sin `finish()` se
    /// vuelve a entregar en el arranque siguiente.
    public var creditedPurchases: Set<String>
    public var daily: DailyRewardState
    public var sharesCompleted: Int
    public var lastSeenTimestamp: TimeInterval
    public var stats: MetaStats
    /// Logros ya conseguidos (ids de achievements.json).
    public var unlockedAchievements: Set<String>
    /// Logros cuya recompensa el jugador ya cobró. Separado de los desbloqueados
    /// porque cobrar es un acto aparte: un logro se consigue una vez y se paga
    /// una vez.
    public var claimedAchievements: Set<String>
    /// Cofres ganados y todavía sin abrir. Vive en `meta` y no en `run`: un
    /// cofre ganado en la partida anterior sigue siendo tuyo después de
    /// reencarnar.
    public var chestsPending: Int
    /// Los de la reencarnación, aparte de los comunes porque garantizan
    /// **épica o mejor**. Dos contadores y no una cola de `[Rarity?]`: hay una
    /// sola fuente con piso, así que la cola sería estructura para un caso que
    /// no existe — y encima obligaría a serializar un enum opcional en el save.
    public var prestigeChestsPending: Int
    /// El cofre del tutorial se da UNA vez por save, no una por partida.
    public var welcomeChestGiven: Bool
    /// ORO comprado con plata real, por transacción (id → ORO). Sólo crece: la
    /// única puerta es `recordOroPurchase`, y es un mapa y no un contador para
    /// que dos devices con compras distintas se unan sin contar de más ni de menos.
    public internal(set) var oroPurchases: [String: Int]
    /// Transacciones de ORO reembolsadas. Sólo crece, y excluye del total aun a
    /// una compra que todavía no se anotó (el reembolso puede llegar primero).
    public internal(set) var revokedPurchases: Set<String>
    /// Si ya se reconstruyó `oroPurchases` desde el historial de compras. Un
    /// save que no trae la clave cuenta como ya resuelto. Sólo
    /// `SaveMigrator.migrateV5toV6` lo deja en `false`; reconstruir es
    /// idempotente, así que repetirlo no suma de más.
    public var purchasedOroReconstructed: Bool
    /// Tier máximo de la última run que reencarnó: el piso móvil que exige la
    /// siguiente. 0 = sin requisito.
    public var lastRunMaxTier: Int
    /// Tipo fijado en el atajo de contratación rápida. Se ignora, sin borrarse,
    /// si el tipo deja de ser válido.
    public var quickHirePinnedTypeId: String?
    /// Pestañas ya reveladas por la progresión (ids de pestaña).
    public var unlockedTabs: Set<String>
    /// Lo que suman las épicas de engagement.
    public var engagement: EngagementState
    /// Cuántas veces se reseteó la partida (E9). Sólo sube. Entre dos saves de épocas
    /// distintas gana el más nuevo entero: así un save viejo de otro dispositivo (o de la
    /// nube) no resucita la partida que el jugador borró.
    public var resetEpoch: Int
    /// La partida rankeada (E12). Toda cuenta nacida en la 2.0 arranca elegible; un save sin la
    /// clave es de antes y no compite hasta resetear.
    public var ranking: RankingState

    public init(
        lifetimeEarnings: Double,
        oro: Int,
        oroEarnedLifetime: Int,
        prestigeLevel: Int,
        oroUpgradeLevels: [String: Int],
        derivedEffects: UpgradeState,
        globalMultiplier: Double,
        ownedSpecials: [String],
        specialAnchors: [String: String],
        ownedSkins: [String],
        milestoneSkins: [String],
        activeSkinByType: [String: String],
        removedAds: Bool,
        boostActivations: [String: TimeInterval],
        rewardedActivations: [String: TimeInterval] = [:],
        creditedPurchases: Set<String> = [],
        daily: DailyRewardState,
        sharesCompleted: Int,
        lastSeenTimestamp: TimeInterval,
        stats: MetaStats,
        unlockedAchievements: Set<String> = [],
        claimedAchievements: Set<String> = [],
        chestsPending: Int = 0,
        prestigeChestsPending: Int = 0,
        welcomeChestGiven: Bool = false,
        oroPurchases: [String: Int] = [:],
        revokedPurchases: Set<String> = [],
        purchasedOroReconstructed: Bool = true,
        lastRunMaxTier: Int = 0,
        quickHirePinnedTypeId: String? = nil,
        unlockedTabs: Set<String> = [],
        engagement: EngagementState = .initial,
        resetEpoch: Int = 0,
        ranking: RankingState = .newGame
    ) {
        self.lifetimeEarnings = lifetimeEarnings
        self.oro = oro
        self.oroEarnedLifetime = oroEarnedLifetime
        self.prestigeLevel = prestigeLevel
        self.oroUpgradeLevels = oroUpgradeLevels
        self.derivedEffects = derivedEffects
        self.globalMultiplier = globalMultiplier
        self.ownedSpecials = ownedSpecials
        self.specialAnchors = specialAnchors
        self.ownedSkins = ownedSkins
        self.milestoneSkins = milestoneSkins
        self.activeSkinByType = activeSkinByType
        self.removedAds = removedAds
        self.boostActivations = boostActivations
        self.rewardedActivations = rewardedActivations
        self.creditedPurchases = creditedPurchases
        self.daily = daily
        self.sharesCompleted = sharesCompleted
        self.lastSeenTimestamp = lastSeenTimestamp
        self.stats = stats
        self.unlockedAchievements = unlockedAchievements
        self.claimedAchievements = claimedAchievements
        self.chestsPending = chestsPending
        self.prestigeChestsPending = prestigeChestsPending
        self.welcomeChestGiven = welcomeChestGiven
        self.oroPurchases = oroPurchases
        self.revokedPurchases = revokedPurchases
        self.purchasedOroReconstructed = purchasedOroReconstructed
        self.lastRunMaxTier = lastRunMaxTier
        self.quickHirePinnedTypeId = quickHirePinnedTypeId
        self.unlockedTabs = unlockedTabs
        self.engagement = engagement
        self.resetEpoch = resetEpoch
        self.ranking = ranking
    }

    /// Decodificador a mano por los campos que llegaron después de v4
    /// (`rewardedActivations`, `creditedPurchases`, los logros): no existen en los
    /// saves ya escritos y el decodificador sintetizado exige toda clave que no
    /// sea opcional, así que sin esto el jugador que actualiza pierde la partida.
    /// Es más barato que subir la versión del sobre por un diccionario vacío.
    ///
    /// Los tres del cofre entran por la misma puerta aunque SÍ tengan bump:
    /// `SaveMigrator.migrateV4toV5` los escribe, así que todo v5 los trae, pero
    /// exigirlos haría que un sobre recortado —o uno escrito por otra versión—
    /// costara la partida entera por tres contadores en cero.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        lifetimeEarnings = try container.decode(Double.self, forKey: .lifetimeEarnings)
        oro = try container.decode(Int.self, forKey: .oro)
        oroEarnedLifetime = try container.decode(Int.self, forKey: .oroEarnedLifetime)
        prestigeLevel = try container.decode(Int.self, forKey: .prestigeLevel)
        oroUpgradeLevels = try container.decode([String: Int].self, forKey: .oroUpgradeLevels)
        // ⚠️ `decodeIfPresent` por la misma razón que las siete claves de
        // `UpgradeState`, un nivel más arriba: son **efectos derivados**. La
        // fuente de verdad es `oroUpgradeLevels` —que se decodifica acá al
        // lado— y `UpgradeManager.recomputeDerivedEffects` los reconstruye
        // desde ahí en cuanto el jugador compra algo. Exigir la clave hacía
        // que un sobre sin ella (un v4 escrito por otra versión, un blob
        // recortado) tirara `keyNotFound` y el repositorio cayera a "starting
        // fresh": la partida entera por un diccionario que se recalcula solo.
        //
        // El neutro es EXACTAMENTE el que sale de decodificar `{}` —el caso que
        // ya llegaba por `migrateV3toV4`, que copia `old["upgrades"] ?? [:]`—,
        // así que "sin la clave" y "con la clave vacía" no se separan.
        derivedEffects = try container.decodeIfPresent(UpgradeState.self, forKey: .derivedEffects)
            ?? UpgradeState(offlineEfficiency: 0, tapMultiplier: 1.0, critChance: 0)
        globalMultiplier = try container.decode(Double.self, forKey: .globalMultiplier)
        ownedSpecials = try container.decode([String].self, forKey: .ownedSpecials)
        specialAnchors = try container.decode([String: String].self, forKey: .specialAnchors)
        ownedSkins = try container.decode([String].self, forKey: .ownedSkins)
        milestoneSkins = try container.decode([String].self, forKey: .milestoneSkins)
        activeSkinByType = try container.decode([String: String].self, forKey: .activeSkinByType)
        removedAds = try container.decode(Bool.self, forKey: .removedAds)
        boostActivations = try container.decode([String: TimeInterval].self, forKey: .boostActivations)
        rewardedActivations = try container.decodeIfPresent([String: TimeInterval].self, forKey: .rewardedActivations) ?? [:]
        creditedPurchases = try container.decodeIfPresent(Set<String>.self, forKey: .creditedPurchases) ?? []
        daily = try container.decode(DailyRewardState.self, forKey: .daily)
        sharesCompleted = try container.decode(Int.self, forKey: .sharesCompleted)
        lastSeenTimestamp = try container.decode(TimeInterval.self, forKey: .lastSeenTimestamp)
        stats = try container.decode(MetaStats.self, forKey: .stats)
        unlockedAchievements = try container.decodeIfPresent(Set<String>.self, forKey: .unlockedAchievements) ?? []
        claimedAchievements = try container.decodeIfPresent(Set<String>.self, forKey: .claimedAchievements) ?? []
        chestsPending = try container.decodeIfPresent(Int.self, forKey: .chestsPending) ?? 0
        prestigeChestsPending = try container.decodeIfPresent(Int.self, forKey: .prestigeChestsPending) ?? 0
        welcomeChestGiven = try container.decodeIfPresent(Bool.self, forKey: .welcomeChestGiven) ?? false
        oroPurchases = try container.decodeIfPresent([String: Int].self, forKey: .oroPurchases) ?? [:]
        revokedPurchases = try container.decodeIfPresent(Set<String>.self, forKey: .revokedPurchases) ?? []
        purchasedOroReconstructed = try container.decodeIfPresent(Bool.self, forKey: .purchasedOroReconstructed) ?? true
        // Los builds de desarrollo anteriores guardaban el total como un solo
        // número, sin ids: no hay cómo saber qué transacciones contó. Se ignora y
        // se reabre la reconstrucción, que rehace la cuenta desde StoreKit.
        let legacy = try decoder.container(keyedBy: LegacyKeys.self)
        let legacyTotal = try legacy.decodeIfPresent(Int.self, forKey: .oroPurchasedLifetime) ?? 0
        if oroPurchases.isEmpty, legacyTotal > 0 {
            purchasedOroReconstructed = false
        }
        lastRunMaxTier = try container.decodeIfPresent(Int.self, forKey: .lastRunMaxTier) ?? 0
        quickHirePinnedTypeId = try container.decodeIfPresent(String.self, forKey: .quickHirePinnedTypeId)
        unlockedTabs = try container.decodeIfPresent(Set<String>.self, forKey: .unlockedTabs) ?? []
        engagement = try container.decodeIfPresent(EngagementState.self, forKey: .engagement) ?? .initial
        resetEpoch = try container.decodeIfPresent(Int.self, forKey: .resetEpoch) ?? 0
        // `try?`: un ranking ilegible (escrito por una versión futura) vale `.legacy`, no la partida entera.
        ranking = (try? container.decodeIfPresent(RankingState.self, forKey: .ranking)) ?? .legacy
    }

    private enum LegacyKeys: String, CodingKey {
        case oroPurchasedLifetime
    }

    /// ORO comprado con plata real en la historia de la cuenta: la suma de las
    /// transacciones anotadas y no revocadas, cada id una sola vez. El reset de
    /// E9 conserva lo comprado.
    public var oroPurchasedLifetime: Int {
        oroPurchases.reduce(0) { revokedPurchases.contains($1.key) ? $0 : $0 + $1.value }
    }

    /// La única puerta para acreditar ORO comprado. Anotar de nuevo el mismo id
    /// no suma; si dos builds vieron montos distintos para él, queda el mayor.
    public mutating func recordOroPurchase(transactionID: String, amount: Int) {
        oroPurchases[transactionID] = max(oroPurchases[transactionID] ?? 0, amount)
    }

    /// Un reembolso. La transacción deja de contar aunque todavía no se haya anotado.
    public mutating func revokePurchase(transactionID: String) {
        revokedPurchases.insert(transactionID)
    }

    /// La única salida de ORO. El reset de E9 conserva `min(saldo, comprado)`:
    /// eso equivale a gastar primero el ORO ganado, sin llevar dos saldos.
    @discardableResult
    public mutating func spendOro(_ amount: Int) -> Bool {
        guard amount >= 0, oro >= amount else { return false }
        oro -= amount
        stats.oroSpentEver += amount
        return true
    }

    /// Meta virgen de cuenta nueva.
    public static func fresh(offlineEfficiencyBase: Double, critChanceBase: Double, now: TimeInterval) -> MetaState {
        MetaState(
            lifetimeEarnings: 0,
            oro: 0,
            oroEarnedLifetime: 0,
            prestigeLevel: 0,
            oroUpgradeLevels: [:],
            derivedEffects: UpgradeState(
                offlineEfficiency: offlineEfficiencyBase,
                tapMultiplier: 1.0,
                critChance: critChanceBase
            ),
            globalMultiplier: 1.0,
            ownedSpecials: [],
            specialAnchors: [:],
            ownedSkins: [],
            milestoneSkins: [],
            activeSkinByType: [:],
            removedAds: false,
            boostActivations: [:],
            rewardedActivations: [:],
            daily: DailyRewardState(),
            sharesCompleted: 0,
            lastSeenTimestamp: now,
            stats: MetaStats()
        )
    }

    /// Todas las skins que el jugador posee (IAP ∪ milestones).
    public var allOwnedSkins: Set<String> { Set(ownedSkins).union(milestoneSkins) }
}

/// The complete player save (schema v6): un sobre con dos secciones —`run`
/// muere al reencarnar, `meta` sobrevive—, forma que estrenó F7 "La Torre" en
/// v4. CoreData lo guarda como JSON blob y el snapshot es la misma codificación.
public struct PlayerState: Codable, Sendable, Equatable {
    public var schemaVersion: Int
    public var run: RunState
    public var meta: MetaState

    public static let currentSchemaVersion = 6

    public init(schemaVersion: Int, run: RunState, meta: MetaState) {
        self.schemaVersion = schemaVersion
        self.run = run
        self.meta = meta
    }

    /// A fresh account: one starter unit, everything else at its baseline.
    /// The starter type id comes from data (`TierRepository.baseType`), never from code.
    public static func newGame(
        startTypeId: String,
        startFloorId: String,
        offlineEfficiencyBase: Double,
        critChanceBase: Double,
        now: TimeInterval
    ) -> PlayerState {
        PlayerState(
            schemaVersion: currentSchemaVersion,
            run: .fresh(startTypeId: startTypeId, startFloorId: startFloorId),
            meta: .fresh(offlineEfficiencyBase: offlineEfficiencyBase, critChanceBase: critChanceBase, now: now)
        )
    }
}
