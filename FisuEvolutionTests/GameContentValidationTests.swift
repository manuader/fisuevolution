import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// Validates the real bundled content (the JSON that ships in the app).
@Suite("Bundled game content")
struct GameContentValidationTests {
    let content: GameContent

    init() throws {
        content = try GameContentLoader.load(from: .main)
    }

    @Test func tierTableHasExpectedShape() {
        // Remapeo a 10 pisos: 44 entradas = 43 concretas + el nodo de elección
        // `junior`. Las 43 concretas son las 36 de antes menos `kiosco` más los
        // 8 personajes nuevos, y son exactamente las 43 caras del arte.
        #expect(content.tiers.types.count == 44)
        #expect(content.tiers.concreteTypes.count == 43)
        #expect(content.tiers.maxTier == 37)
        #expect(content.tiers.baseType.id == "homeless")
        #expect(content.tiers.terminalType.id == "god")
    }

    @Test func careerChoiceNodeIsWellFormed() throws {
        let junior = try #require(content.tiers.type(id: "junior"))
        #expect(junior.isChoiceNode)
        #expect(junior.choiceOptions?.count == 4)
        for option in junior.choiceOptions ?? [] {
            let resolved = try #require(content.tiers.type(id: option))
            #expect(resolved.tier == 11)
            #expect(resolved.isChoiceNode == false)
        }
    }

    /// RF-10: el playtest pidió "al menos 4 personajes por piso, menos el último
    /// que sólo tiene a Dios". Con 4 exactos por piso el reparto queda forzado,
    /// así que este test es la aritmética entera del remapeo en una sola pieza.
    @Test("la torre cubre 1…37 sin huecos y ningún piso no-Dios tiene menos de 4 tiers")
    func towerCoverageAfterRemap() {
        let floors = content.floorTable.floors
        #expect(floors.count == 10)
        for floor in floors where floor.id != "god_realm" {
            #expect(floor.lastTier - floor.firstTier + 1 == 4, "\(floor.id) no tiene 4 tiers")
        }
        #expect(floors.first?.firstTier == 1)
        #expect(floors.last?.lastTier == 37)
        for (lower, upper) in zip(floors, floors.dropFirst()) {
            #expect(lower.lastTier + 1 == upper.firstTier, "hueco o solape entre \(lower.id) y \(upper.id)")
        }
    }

    /// `kiosco` (Personal de Kiosco) se eliminó de la cadena y El Mantero ocupó
    /// su lugar. Se va de los tres lados a la vez: si sobrevive en uno queda
    /// arte huérfano o —peor— una skin que no se le puede aplicar a nadie.
    @Test("kiosco ya no existe en ningún lado")
    func kioscoIsGone() {
        #expect(content.tiers.types.allSatisfy { $0.id != "kiosco" })
        #expect(content.skins.skins.allSatisfy { $0.characterType != "kiosco" })
        #expect(content.manifest.characters.keys.allSatisfy { !$0.hasPrefix("kiosco") })
    }

    /// El fondo `bg_cosmic` se retiró (decisión estética del dueño). Sin entrada
    /// en el manifest el código cae a un placeholder programático SIN romperse,
    /// así que un fondo huérfano no falla ningún otro test: por eso se asserta acá.
    @Test("el fondo cosmic se retiró del manifest y ningún piso lo pide")
    func cosmicBackgroundIsGone() {
        #expect(content.manifest.backgrounds["cosmic"] == nil)
        #expect(content.floorTable.floors.allSatisfy { $0.background != "cosmic" })
        #expect(content.manifest.backgrounds.count == 10)
    }

    /// El corte `earth`/`cosmic` tiene que caer en un BORDE de piso, no partir
    /// uno al medio: es lo que elige la música y el tema del tablero. Después
    /// del remapeo cae entre T24 (Dueño de la Luna, último de `moon`) y T25
    /// (Dueño de Marte, primero de `mars`).
    @Test("la fase cambia justo en el borde moon→mars")
    func phaseCutFallsOnAFloorBoundary() throws {
        for type in content.tiers.types {
            let expected: GamePhase = type.tier <= 24 ? .earth : .cosmic
            #expect(type.phase == expected, "\(type.id) (T\(type.tier)) está en la fase equivocada")
        }
        let moon = try #require(content.floorTable.floors.first { $0.id == "moon" })
        #expect(moon.lastTier == 24, "el corte de fase dejó de coincidir con el borde de piso")
    }

    /// Anti-drift: every number in tiers.json must equal the F7 formulas applied to
    /// economy.json. Hand-edited numbers break this on purpose.
    @Test func tierNumbersDeriveFromEconomyFormulas() {
        let economy = StandardEconomy(config: content.economy)
        for type in content.tiers.types {
            expectRelativelyEqual(type.tapYield, economy.tapYield(forTier: type.tier), context: "\(type.id).tapYield")
            expectRelativelyEqual(type.passiveYieldPerInstance, economy.passiveYield(forTier: type.tier), context: "\(type.id).passiveYield")
            expectRelativelyEqual(type.passiveUnlockCost, economy.passiveUnlockCost(forTier: type.tier), context: "\(type.id).unlockCost")
        }
    }

    @Test func economyConfigMatchesTunedValues() {
        // Pins de la calibración FINAL de economy.json v2 (F7 "La Torre").
        // Si tuneás la economía, actualizá estos pins A PROPÓSITO — el drift
        // silencioso del JSON es exactamente el bug que este test caza.
        let economy = content.economy
        #expect(economy.schemaVersion == 2)
        #expect(economy.baseTapYieldTier1 == 1)
        #expect(economy.yieldGrowthPerTier == 2.8)
        #expect(economy.passiveRatio == 0.5)
        #expect(economy.passiveUnlockCostMultiplier == 60)
        // Rebalance de pacing §4.3: el TAP dejó de cobrar el `incomeMultiplier`
        // del piso (1 → 620) y el pasivo lo sigue cobrando entero. Es lo que
        // separa las dos curvas, que hasta acá eran la misma con un factor. En
        // el callejón el multiplicador es 1, así que el early game —el tutorial
        // y la primera contratación— no se mueve ni un peso.
        #expect(economy.tapFloorMultiplierExponent == 0)
        // Regla de precios del dueño (2026-08-04): contratar el tier base de un
        // piso cuesta 600× lo que rinde un click de ese personaje ahí, y cada
        // compra sube el precio 20%. El callejón es la excepción barata.
        // Era 300 y el dueño lo duplicó el mismo día; ver Docs/balance-log.md.
        #expect(economy.hire.defaultCostMultiplier == 600)
        // El 20% por compra bajó a 6% en el rebalance de pacing, y NO es un
        // ajuste fino: es el arreglo de la divergencia costos-vs-ingresos.
        // El 20% compone sobre el contador de compras del MISMO tipo, y el bot
        // llega a acumular cientos: medido, 70 compras al abrir corporativo y
        // 870 al final de la partida. Con 1,2 la compra 70 ya cuesta 384 s de
        // income y la run se traba en el tier 11 — el bot NUNCA maxea las siete
        // ni llega a Dios. Con 1,06 la compra 144 cuesta 4,9 s y la partida
        // entera se puede jugar. (1,2^256 = 1,86e20 contra 1,06^256 = 3,0e6, si
        // se quiere el orden de magnitud del compounding.)
        // ⚠️ Toca la regla de precios del dueño (2026-08-04): confirmar.
        #expect(economy.hire.defaultCostGrowth == 1.06)
        // Recargo por tier no-base (rediseño §5.2): 2,8 (yieldGrowthPerTier) ×
        // 1,8 ≈ 5× por tier, o sea que comprar el tier alto directo nunca gana
        // contra comprar dos del de abajo y mergear. Bajarlo de 2,0 abriría ese
        // atajo; subirlo vuelve inalcanzables los tiers de arriba de cada piso.
        #expect(economy.hire.tierPremium == 1.8)
        #expect(economy.charUpgrades.baseCostMultiplier == 50)
        #expect(economy.charUpgrades.costGrowth == 4.0)
        #expect(economy.charUpgrades.effectFactorPerLevel == 2.0)
        // Tope de niveles por personaje (dueño, 2026-08-19): máximo = base ×
        // 2^20. Sin techo, el exponencial terminaba en overflow y el juego se
        // caía. Cambiarlo es una decisión de balance, no un ajuste.
        #expect(economy.charUpgrades.maxLevel == 20)
        // Rebalance de pacing: el ORO se volvió ESCASO y CHUNKY. Con el divisor
        // en 3e6 y el exponente en 0,45 la primera reencarnación caía a los 6
        // minutos y valía 6e-9 % de la condición de victoria; ahora cae a las
        // 2,0 h ACTIVAS y vale 0,5 % (un nivel entero de income). Medido: 8
        // reencarnaciones para maxear las siete, con la cadencia 2,0 · 6,9 ·
        // 12,0 · 16,7 · 20,0 · 22,7 · 24,0 · 25,3 h activas.
        #expect(economy.oro.divisor == 300_000_000_000)
        // RF-07 (Ola 3) lo había bajado de 0.5 a 0.45; el rebalance lo baja a
        // 0.25 porque con 0,45 hacen falta ×4,65 de ganancias por duplicar el
        // ORO y las 8 entregas entraban en 1,3 h activas. Con 0,25 hacen falta
        // ×16 y las 8 se reparten en 25 h. Ver Docs/balance-log.md.
        #expect(economy.oro.exponent == 0.25)
        #expect(economy.oro.globalMultiplierPerOro == 0.18)
        #expect(economy.critChanceBase == 0.0)
        #expect(economy.critMultiplier == 5.0)
        #expect(economy.offlineEfficiencyBase == 0.35)
        #expect(economy.offlineCapHours == 10)
    }

    /// El catálogo de las siete líneas nunca puede pasarse de su `EffectCaps`.
    ///
    /// No es cosmético: `UpgradeManager.recomputeDerivedEffects` (app) CLAMPEA
    /// con esos topes y `PermanentUpgrades.recomputeDerivedEffects` (EconomyKit,
    /// que es lo que corre el simulador) NO. Mientras ninguna línea llegue a su
    /// tope los dos coinciden; en cuanto una lo pase, el simulador mide un
    /// efecto que el juego recorta y la calibración entera queda mintiendo —en
    /// silencio, que es lo peor. Este test es el que hace ruido.
    @Test func upgradeLinesNeverReachTheirEffectCaps() {
        let economy = content.economy
        for line in content.upgradesConfig.upgrades {
            let total = Double(line.maxLevel) * line.magnitudePerLevel
            switch line.effectType {
            case .critChance:
                #expect(economy.critChanceBase + total <= EffectCaps.crit, "\(line.id): \(total)")
            case .offlineEfficiency:
                #expect(economy.offlineEfficiencyBase + total <= EffectCaps.offline, "\(line.id): \(total)")
            case .goldenTouchChance:
                #expect(total <= EffectCaps.golden, "\(line.id): \(total)")
            case .spawnCostDiscount:
                #expect(total <= EffectCaps.spawnDiscount, "\(line.id): \(total)")
            case .incomeMultiplier, .tapMultiplier, .prestigeBonusPerSoulPoint:
                #expect(total > 0, "\(line.id) no aporta nada")
            }
        }
    }

    /// Pin del catálogo de las siete líneas. `economy.json` tiene el suyo desde
    /// F7 y `upgrades.json` no tenía ninguno — y sobre estos 193 ORO descansa
    /// toda la calibración del rebalance, incluido el techo de 8
    /// reencarnaciones: el bot reencarna al DUPLICAR su ORO histórico, así que
    /// las reencarnaciones para maxear son log₂(costo total), y log₂(193) = 7,6.
    /// Un catálogo por encima de ~450 ORO totales rompe ese techo en silencio.
    @Test func upgradeCatalogMatchesTunedValues() {
        let esperado: [String: (levels: Int, magnitude: Double, base: Double, growth: Double)] = [
            "income": (10, 0.2, 1, 1.10), "tap": (10, 0.5, 1, 1.10),
            "offline": (10, 0.05, 1, 1.15), "spawn": (10, 0.03, 1, 1.15),
            "crit": (10, 0.025, 1, 1.20), "golden": (10, 0.005, 1, 1.20),
            "prestige": (10, 0.005, 1, 1.25),
        ]
        let lineas = content.upgradesConfig.upgrades
        #expect(lineas.count == esperado.count)
        var total = 0
        for line in lineas {
            guard let pin = esperado[line.id] else {
                Issue.record("línea inesperada en upgrades.json: \(line.id)")
                continue
            }
            #expect(line.maxLevel == pin.levels, "\(line.id).maxLevel")
            #expect(abs(line.magnitudePerLevel - pin.magnitude) < 1e-12, "\(line.id).magnitudePerLevel")
            #expect(abs(line.baseCost - pin.base) < 1e-12, "\(line.id).baseCost")
            #expect(abs(line.costGrowth - pin.growth) < 1e-12, "\(line.id).costGrowth")
            #expect(line.currency == .oro, "\(line.id) tiene que pagarse con ORO")
            // El precio de cada nivel se redondea para arriba a entero
            // (`UpgradeManager.purchase`), así que el total se suma así.
            total += (0..<line.maxLevel).reduce(0) { $0 + Int(UpgradeManager.cost(of: line, level: $1).rounded(.up)) }
        }
        #expect(total == 193, "maxear las siete cuesta \(total) ORO")
        // Y ninguna línea puede volver a ser el 99,99% del costo de ganar, que
        // es lo que `crit` era antes del rebalance (1,776e10 de 1,778e10).
        let porLinea = lineas.map { line in
            (0..<line.maxLevel).reduce(0) { $0 + Int(UpgradeManager.cost(of: line, level: $1).rounded(.up)) }
        }
        let masCara = porLinea.max() ?? 0
        let masBarata = porLinea.min() ?? 1
        #expect(Double(masCara) / Double(masBarata) < 2.0, "\(masCara) vs \(masBarata)")
    }

    @Test func floorHireOverridesMatchTunedValues() {
        // La regla de precios es ÚNICA para toda la torre, así que el único
        // override legítimo es el del alley: baja el multiplicador a 25 para
        // anclar el primer Fisura en 25 monedas (era 50; el dueño lo bajó a la
        // mitad para acortar el tutorial). Cualquier otro override
        // rompería la regla y es drift, no tuning.
        for floor in content.floorTable.floors {
            if floor.id == "alley" {
                #expect(floor.hireCostMultiplierOverride == 25)
            } else {
                #expect(floor.hireCostMultiplierOverride == nil, "override de hire inesperado en \(floor.id)")
            }
            #expect(floor.hireCostGrowthOverride == nil, "el 6% por compra es global: \(floor.id) no debe overridearlo")
            // v2 no overridea unlockTier: todo piso se desbloquea con su firstTier.
            #expect(floor.unlockTierOverride == nil, "unlockTier inesperado en \(floor.id)")
            // El encuadre del fondo nunca puede pasar el sobrante del aspect-fill
            // (1.18 → 18%): más que eso despegaría el fondo del techo del piso.
            #expect(
                floor.backgroundOffset >= 0 && floor.backgroundOffset <= 0.18,
                "backgroundOffset fuera del sobrante en \(floor.id): \(floor.backgroundOffset)"
            )
        }
    }

    /// La regla en números concretos, contra el contenido real.
    ///
    /// ⚠️ **La regla del dueño se enunció como "el tier base de un piso superior
    /// cuesta 600 veces lo que rinde un click suyo ahí" y desde el rebalance de
    /// pacing eso YA NO ES CIERTO**, porque el precio y el click dejaron de
    /// compartir el multiplicador de piso: `hireCost` lleva
    /// `floor.incomeMultiplier` entero y el tap lleva
    /// `tapFloorMultiplier(for:)`, que con el exponente en 0 vale 1.
    ///
    /// Este test pinea las DOS cosas por separado —lo que el precio lleva y
    /// cuántos clicks es de verdad— justamente para que la diferencia esté a la
    /// vista y no escondida detrás de una fórmula vieja replicada en el test.
    /// **Es una decisión pendiente del dueño** (ver `.superpowers/t5-report.md`,
    /// CRITICAL 2): o el precio deja de llevar el multiplicador de piso, o la
    /// regla se re-enuncia con el número real.
    @Test func hirePricesFollowTheOwnersRule() throws {
        let economy = StandardEconomy(config: content.economy)
        let alley = content.floorTable[0]
        // El primer Fisura sigue costando 25 (decisión cerrada del dueño): la
        // curva sólo cambia de PENDIENTE, no de arranque. El segundo pasa de 30
        // a 26,5 porque el 20% por compra bajó a 6% — 25 × 1,06.
        #expect(content.economy.hireCost(floor: alley, tier: 1, purchases: 0) == 25)
        let segundo = content.economy.hireCost(floor: alley, tier: 1, purchases: 1)
        #expect(abs(segundo - 26.5) < 1e-9)

        for ordinal in 1..<content.floorTable.count {
            let floor = content.floorTable[ordinal]
            let precio = content.economy.hireCost(floor: floor, tier: floor.firstTier, purchases: 0)

            // 1) Lo que el PRECIO lleva: 600 × tapYield × incomeMultiplier del
            //    piso. Esta parte de la regla no se movió.
            let anclaDelPrecio = economy.tapYield(forTier: floor.firstTier) * floor.incomeMultiplier
            #expect(abs(precio - 600 * anclaDelPrecio) < precio * 1e-12, "\(floor.id): \(precio) ≠ 600× \(anclaDelPrecio)")

            // 2) Lo que RINDE un click ahí — el mismo factor que usa
            //    `GameActions.applyTap`, no una copia de la fórmula vieja. En
            //    clicks, el precio es 600 × incomeMultiplier, no 600.
            let click = economy.tapYield(forTier: floor.firstTier)
                * content.economy.tapFloorMultiplier(for: floor)
            let clicks = precio / click
            #expect(
                abs(clicks - 600 * floor.incomeMultiplier) < clicks * 1e-9,
                "\(floor.id): contratarlo son \(clicks) clicks"
            )
        }

        // El número que hay que mirarle a la cara antes de decidir: en el reino
        // divino (incomeMultiplier 620) contratar el tier base son 372.000
        // clicks, no 600. Es la consecuencia de `tapFloorMultiplierExponent: 0`
        // y está pineada acá para que ningún cambio futuro la mueva sin ruido.
        let god = content.floorTable[content.floorTable.count - 1]
        let clicksEnDios = content.economy.hireCost(floor: god, tier: god.firstTier, purchases: 0)
            / (economy.tapYield(forTier: god.firstTier) * content.economy.tapFloorMultiplier(for: god))
        #expect(abs(clicksEnDios - 372_000) < 1e-6, "clicks en \(god.id): \(clicksEnDios)")
    }

    @Test func towerFloorsMatchCalibratedLayout() throws {
        // Layout FINAL de La Torre: 10 pisos data-driven, del callejón al reino
        // divino, capacity 10 en todos e income estrictamente creciente.
        // El `incomeMultiplier` es una progresión geométrica interpolada, no
        // inventada: va de 1,0 a 620,0 en 9 saltos, o sea razón 620^(1/9) =
        // 2,0431 redondeada al estilo de la tabla vieja.
        let expected: [(id: String, tiers: ClosedRange<Int>, income: Double)] = [
            ("alley", 1...4, 1.0),
            ("urban", 5...8, 2.0),
            ("corporate", 9...12, 4.2),
            ("luxury", 13...16, 8.5),
            ("island", 17...20, 17.0),
            ("moon", 21...24, 35.0),
            ("mars", 25...28, 72.0),
            ("solar", 29...32, 150.0),
            ("galaxy", 33...36, 305.0),
            ("god_realm", 37...37, 620.0),
        ]
        let table = content.floorTable
        try #require(table.count == expected.count)
        for (floor, pin) in zip(table.floors, expected) {
            #expect(floor.id == pin.id)
            #expect(floor.firstTier == pin.tiers.lowerBound, "\(pin.id).firstTier")
            #expect(floor.lastTier == pin.tiers.upperBound, "\(pin.id).lastTier")
            #expect(floor.capacity == 10, "\(pin.id).capacity")
            expectRelativelyEqual(floor.incomeMultiplier, pin.income, context: "\(pin.id).incomeMultiplier")
        }
        // Estrictamente creciente: un piso más alto SIEMPRE rinde más.
        for (lower, upper) in zip(table.floors, table.floors.dropFirst()) {
            #expect(lower.incomeMultiplier < upper.incomeMultiplier, "income no crece de \(lower.id) a \(upper.id)")
        }
        // Cobertura exacta 1...maxTier, sin huecos ni solapes. FloorTable ya lo
        // valida en su init; esto es anti-regresión por si esa validación se relaja.
        #expect(table.floors.first?.firstTier == 1)
        for (lower, upper) in zip(table.floors, table.floors.dropFirst()) {
            #expect(upper.firstTier == lower.lastTier + 1, "hueco o solape entre \(lower.id) y \(upper.id)")
        }
        #expect(table.floors.last?.lastTier == content.tiers.maxTier)
    }

    /// Todo fondo referenciado por un piso tiene que tener arte en el manifest
    /// (el loader ya lo exige al arrancar; acá queda documentado como contrato).
    @Test func floorBackgroundsExistInManifest() {
        for floor in content.floorTable.floors {
            #expect(
                content.manifest.backgrounds[floor.background] != nil,
                "piso \(floor.id): fondo \(floor.background) sin entrada en manifest.backgrounds"
            )
        }
    }

    @Test func featureFlagsShipDisabled() {
        #expect(content.flags.gameCenterEnabled == false)
        #expect(content.flags.cloudKitEnabled == false)
        #expect(content.flags.useRealAds == false)
        #expect(content.flags.buildVariant == "dev")
    }

    /// El arte entra por tandas: cada entrada del manifest debe apuntar a un
    /// tipo real; los tipos sin entrada renderizan placeholder (regla de oro).
    @Test func manifestEntriesReferenceRealTypes() {
        // Una entrada de personaje debe apuntar a un tier real O a un special
        // real (los specials tienen arte propio en specials.atlas, no son tiers).
        let specialIds = Set(content.specials.specials.map(\.id))
        for (typeId, asset) in content.manifest.characters {
            let isReal = content.tiers.type(id: typeId) != nil || specialIds.contains(typeId)
            #expect(isReal, "manifest huérfano: \(typeId)")
            #expect(!asset.key.isEmpty)
            #expect(!asset.atlas.isEmpty)
        }
    }

    @Test func skinCatalogReferencesBundledTypesAndFloors() {
        #expect(content.skins.schemaVersion == 1)
        #expect(content.skins.skins.count >= 5)
        for skin in content.skins.skins {
            #expect(
                skin.characterType == "*" || content.tiers.type(id: skin.characterType) != nil,
                "skin \(skin.id): tipo desconocido \(skin.characterType)"
            )
            if let floor = skin.floorReached {
                #expect(content.floorTable.floors.contains { $0.id == floor }, "skin \(skin.id): piso desconocido \(floor)")
            }
        }
    }

    /// Cada personaje concreto tiene su skin alternativa catalogada, y todas
    /// declaran nombre visible: una skin sin `displayNameKey` se vería en la
    /// ficha como su id crudo.
    @Test func everyCharacterHasACataloguedSkinWithAName() throws {
        let textureSkins = content.skins.skins.filter { $0.treatment == .texture }
        let covered = Set(textureSkins.map(\.characterType))
        for type in content.tiers.concreteTypes {
            #expect(covered.contains(type.id), "el personaje \(type.id) no tiene skin catalogada")
        }
        for skin in content.skins.skins {
            let key = try #require(skin.displayNameKey, "skin \(skin.id): sin displayNameKey")
            #expect(key == "skin.name.\(skin.id)")
        }
    }

    /// La convención de textura es `<baseKey>__<skinId>` (spec §5): el arte de
    /// una skin vive en el atlas de SU personaje, con el `__` DESPUÉS de `_idle`.
    /// Romperla no falla en runtime —hay fallback a la base— pero deja la skin
    /// invisible para siempre, que es peor: por eso se asserta acá.
    @Test func textureSkinKeysFollowTheNamingConvention() throws {
        for skin in content.skins.skins where skin.treatment == .texture {
            let key = try #require(skin.textureKey, "skin \(skin.id): texture sin textureKey")
            let asset = try #require(
                content.manifest.characters[skin.characterType],
                "skin \(skin.id): su personaje no tiene arte base en el manifest"
            )
            #expect(key == "\(asset.key)__\(skin.id)", "skin \(skin.id): textureKey fuera de convención (\(key))")
        }
    }

    /// El contrato que permite shippear catálogo y arte por separado: una skin
    /// cuyo PNG todavía no existe DEBE caer a la textura base, nunca a un
    /// placeholder roto. Vale antes y después de que entre el arte.
    @MainActor
    @Test func missingSkinArtFallsBackToTheBaseTexture() throws {
        let renderer = PlaceholderRenderer()
        for skin in content.skins.skins where skin.treatment == .texture {
            guard let type = content.tiers.type(id: skin.characterType) else { continue }
            let texture = try #require(
                renderer.texture(for: type, manifest: content.manifest, skinTextureKey: skin.textureKey),
                "skin \(skin.id): el renderer no devolvió textura"
            )
            // Sirve el arte de la skin si existe y la base si todavía no: en
            // ningún caso una textura inválida (0x0) que se vería como un hueco.
            #expect(texture.size().width > 1, "skin \(skin.id): textura inválida servida")
            #expect(texture.size().height > 1, "skin \(skin.id): textura inválida servida")
        }
    }

    @Test @MainActor func skinResolverIsDataDrivenAndScopedToCharacterType() {
        let config = SkinsConfig(
            schemaVersion: 1,
            skins: [
                .init(id: "golden", characterType: "*", treatment: .tint, tintHex: "#FFD93D", textureKey: nil, floorReached: nil, reincarnations: nil),
                .init(id: "urban", characterType: "cartonero", treatment: .texture, tintHex: nil, textureKey: "cartonero_idle__urban", floorReached: "urban", reincarnations: nil),
            ]
        )

        #expect(SkinResolver.treatment(for: nil, characterType: "homeless", config: config) == .base)
        #expect(SkinResolver.treatment(for: "golden", characterType: "homeless", config: config) == .tint(hex: "#FFD93D"))
        #expect(SkinResolver.treatment(for: "urban", characterType: "cartonero", config: config) == .texture(key: "cartonero_idle__urban"))
        // Un ID válido pero ajeno a la ficha vuelve a la base, sin filtrarse a
        // otro personaje ni mostrar una textura inválida.
        #expect(SkinResolver.treatment(for: "urban", characterType: "homeless", config: config) == .base)
    }

    /// El drill de remapeo contra el contenido REAL: un save escrito con el
    /// mapeo de 11 pisos tiene unidades de `kiosco`, que ya no existe. Tiene que
    /// cargar, descartar sólo esas y reacomodar el resto contra el mapeo
    /// vigente. `TowerReconciler` se construyó exactamente para esto, así que
    /// pasa de una: se deja igual porque es la red del PRÓXIMO remapeo.
    @Test("un save con el mapeo de 11 pisos carga y reacomoda sus unidades")
    func oldSaveSurvivesTheRemap() throws {
        var state = PlayerState.newGame(
            startTypeId: "homeless",
            startFloorId: "alley",
            offlineEfficiencyBase: content.economy.offlineEfficiencyBase,
            critChanceBase: content.economy.critChanceBase,
            now: 1_700_000_000
        )
        // Un tipo que sigue existiendo y otro que se eliminó en este remapeo.
        state.run.units = ["homeless": 3, "kiosco": 2]

        let outcome = TowerReconciler.reconcile(
            run: &state.run,
            floorTable: content.floorTable,
            tiers: content.tiers
        )

        #expect(outcome.discarded == ["kiosco": 2], "las unidades de un tipo eliminado se descartan, no rompen la carga")
        #expect(state.run.units == ["homeless": 3], "kiosco tiene que salir de units, no quedar de zombi")
        #expect(outcome.tower.unitCounts == state.run.units)
        // Y el Fisura queda parado en el callejón, que es donde lo pone el
        // mapeo NUEVO (T1 sigue en `alley`, ahora 1…4 en vez de 1…2).
        #expect(content.floorTable.ordinal(forTier: 1) == 0)
    }

    private func expectRelativelyEqual(_ actual: Double, _ expected: Double, context: String) {
        let tolerance = max(abs(expected), 1) * 1e-9
        #expect(abs(actual - expected) <= tolerance, "\(context): \(actual) != \(expected)")
    }
}
