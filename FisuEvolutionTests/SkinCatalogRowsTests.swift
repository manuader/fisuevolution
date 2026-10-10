import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// La proyección del Customization Shop (spec §7): qué skins se ofrecen por
/// personaje y en qué estado.
///
/// Lo que estos tests protegen no es el orden de una grilla: es **qué se puede
/// tocar y qué dice cada tarjeta**. Tres cosas concretas, y las tres se rompen
/// en silencio:
///
/// 1. **Los textos de condición llegan RESUELTOS.** `LocalizedStringKey` no
///    resuelve claves armadas por interpolación (trampa 5 del HANDOFF), así que
///    la condición se arma acá con `String(localized:)`. Si alguien la vuelve a
///    mudar a la vista, en pantalla queda "skins.unlock.floor" crudo — y eso no
///    lo detecta ningún compilador.
/// 2. **El producto de una skin paga es el DEDICADO, no el combo.** `mundialista`
///    la venden DOS productos (`skin_mundialista` y el `starter_pack`, que la
///    trae adentro): ofrecer el combo cuando el jugador quiere la skin le cobra
///    de más.
/// 3. **Tener una skin no es tenerla puesta.** Son dos estados distintos y sólo
///    uno de los dos muestra el botón de equipar.
@Suite("Customization: el catálogo de skins por personaje", .serialized)
@MainActor
struct SkinCatalogRowsTests {
    private func rows(_ gameState: GameState, _ typeID: String) -> [SkinCatalogRow] {
        gameState.skinCatalogRows(forCharacterType: typeID)
    }

    private func row(_ gameState: GameState, _ typeID: String, _ skinID: String) throws -> SkinCatalogRow {
        try #require(
            rows(gameState, typeID).first { $0.id == skinID },
            "no hay fila \(skinID) para \(typeID)"
        )
    }

    // MARK: La forma de la grilla

    @Test("la apariencia base es la primera fila y arranca puesta")
    func baseComesFirstAndStartsEquipped() async throws {
        let gameState = await makeGameState()

        let rows = rows(gameState, "homeless")

        // El Fisura tiene siete skins en el catálogo: una de reencarnación, una
        // paga, las dos de material (oro y diamante) y las tres familias dibujadas,
        // que existen para los 43. La base va delante de todas y no se persiste como id.
        #expect(rows.map(\.id) == [
            "base", "second_life", "mundialista", "oro", "diamante", "pijama", "gaucho", "dinosaurio",
        ])
        let base = try #require(rows.first)
        #expect(base.state == .equipped, "sin skin activa, la que está puesta es la base")
        #expect(base.textureKey == nil, "la base no tiene textura: es el arte del personaje")
        #expect(!base.displayName.isEmpty)
        #expect(!base.displayName.contains("skins."), "quedó la clave cruda en el nombre")
    }

    @Test("un tipo que no existe no tiene nada que personalizar")
    func unknownTypeHasNoRows() async throws {
        let gameState = await makeGameState()

        #expect(rows(gameState, "no_existe").isEmpty)
        // `junior` es el nodo de elección de carrera, no un personaje.
        #expect(rows(gameState, "junior").isEmpty)
    }

    @Test("cada fila trae el nombre y la textura ya resueltos")
    func rowsCarryResolvedNameAndTexture() async throws {
        let gameState = await makeGameState()

        let skin = try row(gameState, "homeless", "second_life")
        #expect(skin.textureKey == "homeless_idle__second_life")
        #expect(!skin.displayName.isEmpty)
        #expect(!skin.displayName.contains("skin.name"), "el nombre llegó como clave, no como texto")
    }

    // MARK: El Diamante es un pack

    @Test("el Diamante sin comprar sabe de cuántos personajes es el pack; la pinta suelta, no")
    func diamondIsAPackOfAllTheEntriesSharingIt() async throws {
        let gameState = await makeGameState()
        let content = try #require(gameState.content)
        let packSize = content.skins.skins.filter { $0.id == "diamante" }.count

        #expect(packSize > 1)
        #expect(try row(gameState, "homeless", "diamante").packSize == packSize)
        #expect(try row(gameState, "homeless", "mundialista").packSize == nil)
        #expect(try row(gameState, "homeless", "base").packSize == nil)
    }

    // MARK: Los cuatro estados

    /// ⚠️ Acá se pineaba que la pinta del Cartonero decía "llegá a la Ciudad".
    /// Las 41 pintas de piso pasaron a la bolsa del cofre, y un cofre no es una
    /// condición que el jugador pueda leer y perseguir: la fila cae al bloqueo
    /// genérico que `skinState` ya reservaba para "catalogada y todavía sin vía
    /// de obtención". Que la condición llegue RESUELTA lo sigue pineando la de
    /// reencarnación, acá abajo.
    @Test("una pinta de cofre que no tenés sale bloqueada y sin condición que perseguir")
    func chestSkinHasNoMilestoneCondition() async throws {
        let gameState = await makeGameState()

        let skin = try row(gameState, "cartonero", "urban_trailblazer")

        guard case .milestoneLocked(let text) = skin.state else {
            Issue.record("una pinta que todavía no tenés sale bloqueada, y salió \(skin.state)")
            return
        }
        // Exacto y no por descarte: con "no dice el piso" alcanzaba para pasar
        // con CUALQUIER otra condición resuelta, así que si a `urban_trailblazer`
        // le cayera un `upgradesMaxed` de casualidad la tarjeta diría otra cosa y
        // el test seguiría verde. ⚠️ Lo que la igualdad NO cubre es la clave sin
        // resolver: los dos lados llaman `String(localized:)` contra el mismo
        // bundle, así que una clave faltante devuelve lo mismo de los dos lados.
        #expect(
            text == String(localized: "skins.locked.generic"),
            "la tarjeta tiene que decir el bloqueo genérico y nada más; dice \"\(text)\""
        )
    }

    @Test("una skin de reencarnación dice cuántas vidas faltan")
    func prestigeSkinResolvesItsCondition() async throws {
        let gameState = await makeGameState()

        let skin = try row(gameState, "homeless", "second_life")

        guard case .milestoneLocked(let text) = skin.state else {
            Issue.record("con prestigio 0 la skin de reencarnación tiene que estar bloqueada, y salió \(skin.state)")
            return
        }
        #expect(!text.contains("skins.unlock"), "quedó la clave cruda en pantalla")
        #expect(text.contains("1"), "la condición tiene que decir el número; dice \"\(text)\"")
    }

    @Test("una skin paga se ofrece con SU producto, no con el combo que la trae adentro")
    func purchasableSkinPointsAtItsOwnProduct() async throws {
        let gameState = await makeGameState()

        let skin = try row(gameState, "homeless", "mundialista")

        #expect(skin.state == .purchasable(productID: "com.fisuevolution.iap.skin_mundialista"))
        // El starter pack también entrega `mundialista`. Si la fila apuntara al
        // combo, el jugador que quiere la camiseta pagaría el pack entero.
        if case .purchasable(let productID) = skin.state {
            #expect(productID != "com.fisuevolution.iap.starter_pack")
        }
    }

    @Test("una skin ganada queda 'la tenés' hasta que te la ponés")
    func grantedSkinBecomesOwnedThenEquipped() async throws {
        let gameState = await makeGameState()

        gameState.grantMilestoneSkinsForTests(["second_life"])

        #expect(try row(gameState, "homeless", "second_life").state == .owned)
        #expect(try row(gameState, "homeless", "base").state == .equipped)

        gameState.equipSkin(id: "second_life", forCharacterType: "homeless")

        #expect(try row(gameState, "homeless", "second_life").state == .equipped)
        #expect(try row(gameState, "homeless", "base").state == .owned,
                "la base no desaparece al equipar otra: es cómo se vuelve atrás")
    }

    @Test("una skin comprada deja de estar a la venta")
    func purchasedSkinIsNoLongerForSale() async throws {
        let gameState = await makeGameState()

        // Es el camino real: StoreKit es la fuente de verdad y el save cachea.
        gameState.applyStoreEntitlements(removedAds: false, ownedSkins: ["mundialista"])

        #expect(try row(gameState, "homeless", "mundialista").state == .owned)
    }

    @Test("equipar en un personaje no le mueve el estado a otro")
    func equippingIsPerCharacter() async throws {
        let gameState = await makeGameState()
        gameState.grantMilestoneSkinsForTests(["second_life", "parrillero"])

        gameState.equipSkin(id: "second_life", forCharacterType: "homeless")

        #expect(try row(gameState, "homeless", "second_life").state == .equipped)
        #expect(try row(gameState, "god", "parrillero").state == .owned)
        #expect(try row(gameState, "god", "base").state == .equipped)
    }
}

// MARK: - Qué se enseña y qué se esconde (2026-08-19)

/// La regla comercial del bundle: en la ficha, todo lo que no tenés va en
/// silueta —también lo que está a la venta— para que el arte sea la razón de
/// comprar y no un regalo. La tienda es el único lugar donde se ve a color.
@Suite("Silueta de lo no adquirido")
@MainActor
struct SkinSilhouetteTests {
    /// Espeja `SkinCard.isSilhouette`: la vista no es testeable desde acá, pero
    /// la REGLA sí, y es la que no se puede perder en el próximo rediseño.
    private func enSilueta(_ state: SkinCatalogRow.State) -> Bool {
        switch state {
        case .equipped, .owned: false
        case .milestoneLocked, .purchasable: true
        }
    }

    @Test("lo que tenés se ve a color")
    func loAdquiridoSeVe() {
        #expect(!enSilueta(.equipped))
        #expect(!enSilueta(.owned))
    }

    @Test("lo que está a la venta también se esconde: es lo que se quiere vender")
    func loPagoSeEsconde() {
        #expect(enSilueta(.purchasable(productID: "com.fisuevolution.iap.skins_diamante")))
        #expect(enSilueta(.milestoneLocked(conditionText: "Maxeá todas las mejoras")))
    }
}

// MARK: - A quién se puede vestir (2026-08-27)

/// **Pintas y Mejoras dejan de compartir lista.**
///
/// Hasta los cofres, una pinta sólo se ganaba llegando al piso de su personaje,
/// así que "los que viste en esta run" y "los que podés vestir" eran la misma
/// gente por accidente. El sorteo rompió esa coincidencia: la pinta de la Deidad
/// puede caer a los veinte minutos de partida, y `run.seenTypes` además **muere
/// al reencarnar**. Con el filtro de Mejoras, la pinta quedaba ganada y sin
/// forma de ponérsela.
///
/// Lo que estos tests pinean son las tres mitades del criterio nuevo, y las tres
/// se rompen en silencio:
///
/// 1. **Tener la pinta alcanza**, aunque nunca hayas visto al personaje.
/// 2. **Lo visto sigue estando**, tengas pintas suyas o no: es una unión, no un
///    reemplazo.
/// 3. **Una pinta que visten TODOS no trae a nadie.** `oro` y `diamante` están
///    en el catálogo una vez por personaje con el mismo id, así que un solo
///    paquete de diamante desplegaría los 43 y espoilearía la cadena entera
///    (RF-03) — que es justo lo que Pintas venía cuidando.
///
/// Y la cuarta, que no es del carrusel sino de la pantalla de al lado: **Mejoras
/// no se contagia**. Ahí se compra, y ofrecer mejorar a alguien que nunca viste
/// es otra cosa distinta.
@Suite("Pintas: a quién se puede vestir", .serialized)
@MainActor
struct SkinnableTypesTests {
    /// La pinta legendaria de la Deidad (tier 36): el personaje de tier más alto
    /// que reparten los cofres, o sea el más lejos posible de una partida nueva.
    private static let unseenSkin = "oraculo"
    private static let unseenType = "deidad"

    /// Deja la partida como recién reencarnada: el Fisura y nadie más.
    private func reencarnado(_ gameState: GameState) throws {
        var player = try #require(gameState.player)
        player.run.seenTypes = ["homeless"]
        gameState.player = player
    }

    @Test("un personaje que no viste en esta partida aparece igual si tenés una pinta suya")
    func laPintaTraeAlPersonajeQueNoViste() async throws {
        let gameState = await makeGameState()
        try reencarnado(gameState)

        #expect(
            !gameState.skinnableTypes.contains { $0.id == Self.unseenType },
            "sin la pinta no hay nada que vestirle: la Deidad no tiene por qué estar"
        )

        gameState.grantMilestoneSkinsForTests([Self.unseenSkin])

        #expect(
            gameState.skinnableTypes.contains { $0.id == Self.unseenType },
            "la pinta es de la Deidad y es tuya; sin su cara en el carrusel no hay forma de ponérsela"
        )
    }

    @Test("la pinta sobrevive a la reencarnación y el carrusel también")
    func laPintaSobreviveALaReencarnacion() async throws {
        let gameState = await makeGameState()
        gameState.grantMilestoneSkinsForTests([Self.unseenSkin])
        gameState.debugMarkTypesSeen(throughTier: 8)
        #expect(gameState.skinnableTypes.contains { $0.id == Self.unseenType })

        // El camino real: `applyReincarnation` hace `run = .fresh(...)` y se
        // lleva `seenTypes` puesto. La colección vive en `meta` y se queda.
        gameState.giveEarningsForPrestigeTesting()
        gameState.confirmPrestige()

        let player = try #require(gameState.player)
        #expect(player.meta.prestigeLevel == 1, "el fixture tenía que alcanzar para reencarnar")
        #expect(player.run.seenTypes.count == 1, "la run nueva arranca viendo sólo al Fisura")
        #expect(
            gameState.skinnableTypes.contains { $0.id == Self.unseenType },
            "reencarnar no te saca la pinta: tampoco puede sacarte la ficha donde ponértela"
        )
    }

    @Test("lo visto sigue en la lista aunque no tengas ninguna pinta suya")
    func loVistoSigueEstando() async throws {
        let gameState = await makeGameState()
        gameState.debugMarkTypesSeen(throughTier: 8)

        // Sin pintas de nadie, las dos pantallas listan exactamente lo mismo:
        // la única razón por la que Pintas se separa de Mejoras son las pintas.
        #expect(gameState.skinnableTypes.map(\.id) == gameState.characterUpgradeTypes.map(\.id))
        #expect(gameState.skinnableTypes.count > 1, "el fixture tenía que marcar varios tipos vistos")
    }

    @Test("la pinta que visten los 43 no despliega la cadena entera")
    func laPintaDeMaterialNoEspoilea() async throws {
        let gameState = await makeGameState()
        try reencarnado(gameState)

        // El paquete de diamante es una compra real y acredita UN id, que el
        // catálogo declara para los 43 personajes.
        gameState.applyStoreEntitlements(removedAds: false, ownedSkins: ["diamante"])
        #expect(gameState.ownsSkin("diamante"), "el entitlement tenía que quedar acreditado")

        #expect(
            gameState.skinnableTypes.map(\.id) == ["homeless"],
            """
            comprar el paquete de material no te presenta a nadie: la pinta la visten \
            los 43 y desplegarlos espoilea la cadena de evolución (RF-03). \
            Quedaron \(gameState.skinnableTypes.count) caras.
            """
        )

        // ⚠️ Y la contracara, en el MISMO test y por el MISMO camino: una pinta
        // paga que es de UNO SOLO sí tiene que traerlo. `parrillero` es IAP
        // (`com.fisuevolution.iap.skin_parrillero`) y exclusiva del Dios, así
        // que vive en `ownedSkins` y no en `milestoneSkins`.
        //
        // Sin esta mitad, leer `meta.milestoneSkins` en vez de
        // `meta.allOwnedSkins` deja los ocho tests verdes —todos los demás
        // acreditan por `grantMilestoneSkinsForTests`, que escribe en
        // `milestoneSkins`— y en el juego real quien compre esa pinta no ve al
        // Dios en el carrusel.
        gameState.applyStoreEntitlements(removedAds: false, ownedSkins: ["diamante", "parrillero"])

        #expect(
            gameState.skinnableTypes.map(\.id) == ["god", "homeless"],
            """
            la pinta paga del Dios es de él y de nadie más: comprarla tiene que \
            traerlo al carrusel. Quedó \(gameState.skinnableTypes.map(\.id)).
            """
        )
    }

    /// El filo de arriba, medido donde SÍ se distingue.
    ///
    /// ⚠️ En el carrusel, la versión ingenua del criterio —"me quedo con el
    /// PRIMER personaje que declara esta pinta"— es indistinguible de la buena:
    /// el catálogo declara `oro` y `diamante` empezando por el Fisura, y al
    /// Fisura se lo ve siempre. El test de arriba pasaría con esa versión
    /// puesta, así que la pregunta hay que hacérsela al catálogo, que es quien
    /// sabe que una pinta repetida no es de nadie en particular.
    @Test("el catálogo no le inventa dueño a la pinta que visten todos")
    func elCatalogoNoLeDaDuenoALaDeMaterial() async throws {
        let gameState = await makeGameState()
        let skins = try #require(gameState.content?.skins)
        let dueño = skins.exclusiveCharacterTypeBySkinID

        for material in ["oro", "diamante"] {
            #expect(
                dueño[material] == nil,
                """
                \(material) está declarada para los 43 personajes: no puede tener dueño, \
                y quedó en \(dueño[material] ?? "nil")
                """
            )
        }
        // Y la contracara: las que sí son de uno solo tienen que resolverse, o
        // el criterio entero no traería a nadie nunca.
        #expect(dueño[Self.unseenSkin] == Self.unseenType)
        #expect(dueño["second_life"] == "homeless", "la de reencarnación es del Fisura y de nadie más")
    }

    @Test("la lista abre en el más nuevo, igual que la de Mejoras")
    func elOrdenEsElDeSiempre() async throws {
        let gameState = await makeGameState()
        try reencarnado(gameState)
        gameState.grantMilestoneSkinsForTests([Self.unseenSkin])

        let tiers = gameState.skinnableTypes.map(\.tier)
        #expect(tiers == tiers.sorted(by: >), "la lista quedó de más viejo a más nuevo: \(tiers)")
        // La LISTA sigue encabezada por el tier más alto, venga de donde venga.
        // Dónde ABRE la pantalla es otra cosa y la decide el test de abajo: son
        // dos criterios distintos desde que la unión existe.
        #expect(gameState.skinnableTypes.first?.id == Self.unseenType)
    }

    /// **Dónde abre la pantalla, que dejó de ser lo mismo que quién encabeza la
    /// lista.**
    ///
    /// `genesis` es la pinta del Dios y se cobra en la tercera reencarnación: a
    /// partir de ahí el Dios (tier 37, el más alto del catálogo) está en
    /// `skinnableTypes` PARA SIEMPRE. Con el aterrizaje colgado de
    /// `skinnable.first`, Pintas abría siempre en un personaje que el jugador
    /// nunca vio —y con la cara fuera del cuadro, celda 43 de 43—. No es un caso
    /// raro: es el estado por defecto de toda la segunda mitad del juego.
    ///
    /// La regla del dueño (2026-08-17) es que la pantalla abre en *lo último que
    /// hiciste*. Una pinta de cofre no es alguien que hiciste.
    @Test("la pantalla abre en el más nuevo que VISTE, no en el más nuevo de la lista")
    func elAterrizajeEsElMasNuevoVisto() async throws {
        let gameState = await makeGameState()
        try reencarnado(gameState)
        gameState.grantMilestoneSkinsForTests([Self.unseenSkin])

        var skinnable = gameState.skinnableTypes
        #expect(skinnable.first?.id == Self.unseenType, "el fixture tenía que dejar a la Deidad encabezando")
        #expect(
            gameState.defaultSkinnableType(among: skinnable)?.id == "homeless",
            "recién reencarnado, lo último que hiciste es el Fisura: ahí abre"
        )

        // Y en una partida a mitad de camino: abre en el más nuevo VISTO, que no
        // es ni el primero de la lista ni el primero del catálogo.
        gameState.debugMarkTypesSeen(throughTier: 8)
        skinnable = gameState.skinnableTypes
        let aterrizaje = try #require(gameState.defaultSkinnableType(among: skinnable))
        #expect(aterrizaje.tier == 8, "abrió en el tier \(aterrizaje.tier) y el más alto visto es 8")
        #expect(aterrizaje.id != Self.unseenType, "la Deidad sigue sin ser alguien que el jugador vio")
        #expect(skinnable.first?.id == Self.unseenType, "y la lista sigue encabezada por ella")
    }

    @Test("Mejoras no se contagia: ahí se compra, y sólo se ofrece lo visto")
    func mejorasSigueMostrandoSoloLoVisto() async throws {
        let gameState = await makeGameState()
        try reencarnado(gameState)
        gameState.grantMilestoneSkinsForTests([Self.unseenSkin])

        #expect(
            gameState.characterUpgradeTypes.map(\.id) == ["homeless"],
            "tener la pinta de la Deidad no es haberla visto: su mejora no se puede ofrecer (RF-03)"
        )
        #expect(gameState.skinnableTypes.count == 2, "y Pintas sí la lista: son dos criterios distintos")
    }
}
