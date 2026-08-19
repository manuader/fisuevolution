import SwiftUI

/// El mapa de la torre (RF-08), restyleado como **panel de ascensor** (spec §4):
/// una columna de botones de piso —Dios arriba, el callejón abajo— para poder ir
/// del piso 1 al 10 de un toque en vez de subir de a uno.
///
/// La vista no sabe cuántos pisos hay ni cómo se llaman los fondos: todo llega
/// resuelto en `gameState.floorMap`, que sale de `floors[]`.
///
/// El restyle **no le tocó una línea a la lógica**: la misma proyección, la misma
/// re-evaluación contra `boardVersion`, el mismo `jumpToFloor(ordinal:)`, el
/// mismo caché de miniaturas y los mismos identifiers `map.floor.<id>`. Lo que
/// cambió es el idioma visual —`GameCard`, `Tokens`, el botón redondo con el
/// número de piso y el riel que los une— y que el título dejó de ser "La torre"
/// para ser "Ascensor".
struct FloorMapView: View {
    @Environment(GameState.self) private var gameState
    @Environment(\.dismiss) private var dismiss

    /// Margen lateral de la columna: el del marco vectorial, publicado por el
    /// componente. Un solo número para las nueve hojas — el marco es el
    /// contenedor y las tarjetas viven ADENTRO (pedido del dueño, 2026-08-18;
    /// antes eran cuatro insets medidos PNG por PNG contra el arte 9-slice,
    /// que además se deformaba al estirarse).
    private static let panelInset: CGFloat = WoodPanelBackground.columnInset

    /// Diámetro del botón redondo de piso. El riel se alinea a su centro, así que
    /// las dos medidas salen de acá y no de dos literales que se desincronizan.
    private static let buttonSide: CGFloat = 40
    private static let shaftWidth: CGFloat = 7
    /// Centro del botón = padding interno de `GameCard` + radio. Menos medio riel
    /// para que quede centrado y no pegado.
    private static var shaftLeading: CGFloat { Tokens.s12 + buttonSide / 2 - shaftWidth / 2 }

    /// Los tres tonos de fila.
    ///
    /// ⚠️ Existe porque `GameCard.Style` está **anidado en un tipo genérico**:
    /// `GameCard<A>.Style` y `GameCard<B>.Style` son tipos distintos, así que el
    /// estilo no se puede guardar en una propiedad sin nombrar el contenido —y el
    /// contenido de la fila es un `some View` que no tiene nombre—. Se elige el
    /// tono acá y el `switch` se hace donde el contenido ya está fijado (mismo
    /// patrón que `FisuJobsView.Tone`).
    private enum Tone {
        case plain
        case current
        case locked
    }

    var body: some View {
        // `boardVersion` es lo único que puede cambiar una ocupación mientras el
        // mapa está abierto; leerlo acá alcanza para que la lista no se quede
        // vieja sin observar `PlayerState`, que es lo que la UI nunca hace.
        let _ = gameState.boardVersion
        let floors = gameState.floorMap

        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: Tokens.s12) {
                        ForEach(floors) { entry in
                            floorButton(entry).id(entry.id)
                        }
                    }
                    // El riel del hueco del ascensor, alineado al centro de los
                    // botones. Va DETRÁS de la columna, así que las tarjetas
                    // —crema opaco— lo tapan y sólo asoma en los espacios entre
                    // piso y piso: se lee como el cable que une los botones, que
                    // es lo que convierte una lista en un panel de ascensor.
                    .background(alignment: .leading) { shaft }
                    .padding(.horizontal, Self.panelInset)
                    .padding(.top, Tokens.s12)
                    .padding(.bottom, Tokens.s24)
                }
                .onAppear {
                    // Se abre mostrando dónde estás parado, no la punta de la
                    // torre: el mapa es para moverse desde acá.
                    guard let here = floors.first(where: \.isVisible) else { return }
                    proxy.scrollTo(here.id, anchor: .center)
                }
            }
            .panelSheet(material: .metal) { header }
            .navigationTitle(Text(verbatim: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { ArtCloseButton { dismiss() } }
            }
        }
    }


    /// El value de una fila: ocupación o candado, con el "estás acá" adelante
    /// cuando la fila es el piso visible. Con la píldora del HUD retirada
    /// (decisión del dueño 2026-08-18: el piso se cambia scrolleando o por
    /// acá), este value es el único lugar donde VoiceOver —y los tests de
    /// UI— pueden saber en qué piso está parado el jugador.
    private func visibleAwareValue(for entry: FloorMapEntry) -> Text {
        let base: Text = entry.isUnlocked
            ? Text(verbatim: "\(entry.occupied)/\(entry.capacity)")
            : Text("map.locked")
        guard entry.isVisible else { return base }
        return Text("map.here") + Text(verbatim: ", ") + base
    }

    // MARK: Cabecera

    /// El cartel del ascensor, ADENTRO del panel metálico. Sin banda opaca: el
    /// `panelSheet` recorta la columna por debajo de la cabecera, y la banda
    /// tapaba el marco (2026-08-18).
    private var header: some View {
        VStack(spacing: Tokens.s4) {
            // La cabina con su display: el mismo glifo que el botón del HUD que
            // abre esta hoja, ADENTRO de la cápsula del título (composición de
            // las referencias). El banner ya lo tapa de VoiceOver.
            PanelTitleBanner(
                titleKey: "elevator.title",
                icon: AnyView(GameIcon(artKey: "ui_elevator", size: 26) { VectorElevatorIcon() })
            )
            // La bajada, con el mismo formato que la de FisuJobs y la de la
            // tienda: `Tokens.caption` en ink al 75%, centrada y a dos renglones.
            // Era la única de las seis hojas que tenía título pelado, y de las
            // seis es la que más lo necesita: el título dice CÓMO se llama la
            // pantalla, no qué se hace en ella.
            Text("elevator.subtitle")
                .font(Tokens.caption)
                .foregroundStyle(Color("PaletteInk").opacity(0.75))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, Tokens.s24)
        }
    }

    /// El hueco del ascensor. Cápsula fina en tinta translúcida que corre por
    /// detrás de toda la columna.
    private var shaft: some View {
        Capsule()
            .fill(Color("PaletteInk").opacity(0.28))
            .frame(width: Self.shaftWidth)
            .padding(.leading, Self.shaftLeading)
    }

    // MARK: La fila = un botón de piso

    /// Un botón del panel. La lógica es la de siempre: salta y cierra.
    ///
    /// ⚠️ El trío `children: .ignore` + label + value va **sobre el botón**, y no
    /// en una capa aparte como en `FisuJobsView`: acá la fila **no contiene otro
    /// control** —no hay cápsula de compra que un elemento contenedor pudiera
    /// borrar del árbol (trampa 9a)—, así que colapsarla es exactamente lo que se
    /// quiere: una parada de VoiceOver por piso, que dice cuál es y cómo está.
    /// Es la estructura que ya tenía la vista y la que hace que
    /// `FloorMapUITests` encuentre `map.floor.<id>` como `buttons[...]`.
    ///
    /// ⚠️⚠️ **Y por eso el contenido NO va `accessibilityHidden`**, aunque el
    /// volcado de XCUITest liste los cinco textos de adentro. Se probó: taparlos
    /// no los saca del volcado —XCUITest recorre la jerarquía de vistas, no la de
    /// VoiceOver— y encima le borra al `Button` su etiqueta derivada, que queda
    /// como control con identifier y MUDO. Medido el 2026-08-15 volcando el árbol
    /// con y sin el modificador. El árbol resultante es idéntico —elemento por
    /// elemento— al de antes del restyle, que es lo que había que conservar.
    private func floorButton(_ entry: FloorMapEntry) -> some View {
        let tone: Tone = entry.isUnlocked ? (entry.isVisible ? .current : .plain) : .locked
        return Button {
            gameState.jumpToFloor(ordinal: entry.ordinal)
            dismiss()
        } label: {
            Group {
                switch tone {
                case .plain: GameCard(style: .normal) { row(entry, tone: tone) }
                // El piso donde estás parado: marco y halo amarillos, el mismo
                // acento que el botón encendido del panel.
                case .current: GameCard(style: .highlighted(Color("PaletteYellow"))) { row(entry, tone: tone) }
                case .locked: GameCard(style: .locked) { row(entry, tone: tone) }
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: CardMaterials.cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        // Un piso cerrado no es un destino: el preview es premio de las flechas
        // del HUD, no de una lista. `FloorMapUITests` asserta justamente que el
        // botón está deshabilitado.
        .disabled(!entry.isUnlocked)
        .accessibilityIdentifier("map.floor.\(entry.id)")
        .accessibilityElement(children: .ignore)
        // El número va PRIMERO y el nombre después, como se anuncia un piso en un
        // ascensor. Es lo que dice el botón redondo de la izquierda, que quedó
        // fuera del árbol al colapsar la fila.
        .accessibilityLabel(
            Text("map.floor.ordinal \(String(entry.ordinal + 1))")
                + Text(verbatim: ", ")
                + Text(TowerNaming.floorNameKey(for: entry.id))
        )
        .accessibilityValue(visibleAwareValue(for: entry))
    }

    /// Anatomía de la fila: botón numerado, miniatura del fondo real y los datos.
    private func row(_ entry: FloorMapEntry, tone: Tone) -> some View {
        HStack(spacing: Tokens.s12) {
            numberButton(entry, tone: tone)
            thumbnail(entry)
            VStack(alignment: .leading, spacing: Tokens.s4) {
                Text(TowerNaming.floorNameKey(for: entry.id))
                    .font(Tokens.title)
                    .foregroundStyle(Color("PaletteInk"))
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                    .fixedSize(horizontal: false, vertical: true)
                status(entry)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// El botón redondo con el número de piso: lo que hace que la columna se lea
    /// como una botonera y no como una lista.
    ///
    /// Encendido (amarillo) en el piso donde estás; apagado (crema con su aro) en
    /// los demás. El número se dibuja SIEMPRE, también en los cerrados: en una
    /// botonera los números son la referencia y taparlos con un candado dejaría la
    /// columna sin escala. El candado va en el renglón de estado.
    ///
    /// ⚠️ El número se interpola `verbatim`: es un dígito, no una frase, y meterlo
    /// en un `LocalizedStringKey` armaría la clave `%lld` (trampa 5).
    ///
    /// ⚠️ **`Tokens.title` y no `.system(size: 17)`**: un tamaño fijo es el único
    /// texto de la pantalla que se queda quieto cuando el jugador agranda la letra
    /// del sistema, y en una botonera el número es justo lo que hay que poder leer.
    ///
    /// **El canje, escrito entero**: se ganan 3 pt (17 → 20 en el cuerpo por
    /// defecto) y se pierde **un escalón de peso**, del `.black` de antes al
    /// `.heavy` del token. El único token que conserva el `.black` es
    /// `Tokens.display`, y perdió por tamaño: mide 28 pt —+11 sobre el original—,
    /// que en un círculo de 40 con el "10" del Reino divino ya no es un número
    /// grande sino un número apretado. Entre un escalón de peso y once puntos de
    /// más gana el peso perdido: a 20 pt el dígito se lee más que a 17, y el
    /// `minimumScaleFactor` sigue siendo la red en los cuerpos grandes. Verificado
    /// sobre la captura de `FloorMapUITests`.
    private func numberButton(_ entry: FloorMapEntry, tone: Tone) -> some View {
        Text(verbatim: "\(entry.ordinal + 1)")
            .font(Tokens.title)
            .monospacedDigit()
            .foregroundStyle(Color("PaletteInk"))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(width: Self.buttonSide, height: Self.buttonSide)
            .background {
                Circle()
                    .fill(tone == .current ? Color("PaletteYellow") : Color("PaletteCream"))
                    .overlay(Circle().strokeBorder(Color("PaletteBrown").opacity(0.7), lineWidth: 2.5))
                    .shadow(color: .black.opacity(0.16), radius: 3, y: 1)
            }
    }

    /// El renglón de abajo del nombre: cuánta gente entra, o por qué no se puede
    /// ir. Los dos estados comparten el ritmo icono + texto para que la columna no
    /// baile entre filas.
    @ViewBuilder
    private func status(_ entry: FloorMapEntry) -> some View {
        if entry.isUnlocked {
            HStack(spacing: Tokens.s8) {
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text(verbatim: "\(entry.occupied)/\(entry.capacity)")
                        .font(Tokens.body)
                        .monospacedDigit()
                }
                .foregroundStyle(Color("PaletteInk").opacity(0.75))
                if entry.isVisible { herePill }
            }
        } else {
            HStack(spacing: 5) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 14, weight: .black))
                Text("map.locked")
                    .font(Tokens.body)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            // Sin apagar, a diferencia de la ocupación: `GameCard(style: .locked)`
            // ya le baja la opacidad a la tarjeta ENTERA, y con el 0,75 encima el
            // candado —que es la razón de ser de la fila cerrada— salía más
            // apagado que el nombre del piso. Medido sobre la captura.
            .foregroundStyle(Color("PaletteInk"))
        }
    }

    /// "Estás acá" en cápsula amarilla. Junto con el marco y el botón encendido
    /// son las tres marcas del piso actual: la que se ve de lejos (el marco), la
    /// de la botonera (el botón) y la que lo dice con todas las letras.
    ///
    /// ⚠️ **`Tokens.caption` y no `.system(size: 10)`**, por lo mismo que el
    /// número: era el texto más chico de la pantalla y encima el único que no
    /// crecía. La cápsula crece con él porque no tiene ancho fijo: es una marca,
    /// no una columna.
    ///
    /// **El canje acá es más caro y va dicho**: +2 pt (10 → 12) y **tres escalones
    /// de peso**, del `.black` de antes al `.semibold` del token. Se acepta a
    /// propósito: `Tokens.caption` es con lo que el juego escribe casi todas sus
    /// cápsulas chiquitas —el `floorTag` de FisuJobs, que es literalmente la misma
    /// cápsula amarilla con borde ink, y el `StateBadge` compartido; el chip de
    /// `ActiveBonusBar` no, que va con `.system(15/13)` fijo—, así que la marca
    /// deja de ser una de las pocas del juego con un peso propio. Un
    /// `.weight(.black)` encima del token la devolvería, pero sería el primer
    /// override de peso SOBRE UN TOKEN y la próxima pantalla copiaría el atajo:
    /// la gramática vale más que dos escalones en una etiqueta de 12 pt en tinta
    /// sobre amarillo pleno, que da **10:1** —holgado sobre el 4,5:1 de AA, aunque
    /// no sea el par más alto de la paleta: tinta sobre crema da 13,2:1—. Si el
    /// dueño la escucha apagada, el arreglo es subir el peso del TOKEN —y con él
    /// las tres cápsulas—, no parchar esta.
    private var herePill: some View {
        Text("map.here")
            .font(Tokens.caption)
            .foregroundStyle(Color("PaletteInk"))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.horizontal, Tokens.s8)
            .padding(.vertical, 3)
            .background {
                Capsule()
                    .fill(Color("PaletteYellow"))
                    .overlay(Capsule().strokeBorder(Color("PaletteBrown").opacity(0.7), lineWidth: 2))
            }
    }

    /// Miniatura del fondo REAL del piso. El puente código→arte sigue siendo el
    /// manifest: sin entrada ahí, un rectángulo neutro (igual que en la escena).
    ///
    /// El apagado de los pisos cerrados ya no se hace acá: `GameCard(style:
    /// .locked)` desatura y baja la opacidad de la tarjeta ENTERA, así que
    /// repetirlo en la miniatura la dejaba dos veces más muerta que su propia
    /// fila.
    @ViewBuilder
    private func thumbnail(_ entry: FloorMapEntry) -> some View {
        let asset = gameState.content?.manifest.backgrounds[entry.backgroundKey]
        ZStack {
            if let asset, let image = FloorThumbnail.image(named: asset) {
                image
                    .resizable()
                    .scaledToFill()
            } else {
                Color("PaletteInk").opacity(0.18)
            }
        }
        .frame(width: 86, height: 54)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color("PaletteBrown").opacity(0.7), lineWidth: 2)
        )
    }
}

/// Miniaturas de los fondos, cacheadas ya achicadas.
///
/// Los fondos son PNG de 1024×1024: once filas dibujando la imagen completa son
/// ~44 MB de bitmaps vivos cada vez que se abre el mapa. `preparingThumbnail`
/// deja en memoria sólo la versión chica y suelta la grande.
@MainActor
private enum FloorThumbnail {
    private static var cache: [String: Image] = [:]
    private static let side = CGSize(width: 240, height: 240)

    static func image(named assetName: String) -> Image? {
        if let cached = cache[assetName] { return cached }
        guard let full = UIImage(named: assetName),
              let small = full.preparingThumbnail(of: side) else { return nil }
        let image = Image(uiImage: small)
        cache[assetName] = image
        return image
    }
}
