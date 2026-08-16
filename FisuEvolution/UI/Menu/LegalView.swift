import SwiftUI

// MARK: - El documento

/// Un documento legal del juego: el `.md` que se publica en `Distribution/site/`
/// y que viaja **copiado** en el bundle (`Resources/Legal/`) para poder leerse
/// sin conexión y sin sacar al jugador de la app.
///
/// ⚠️ **Por qué hay un parser propio y no un `AttributedString(markdown:)` del
/// archivo entero.** Dos razones, las dos medidas contra estos `.md`:
///
/// 1. Con la interpretación **completa**, el markdown de bloque (títulos,
///    viñetas, párrafos) se traduce a atributos `presentationIntent` que
///    `Text` **ignora**: en pantalla queda todo el documento pegado en un solo
///    chorizo, sin un solo salto de línea. Es correcto para una frase; para
///    trece secciones es ilegible.
/// 2. Con `.inlineOnlyPreservingWhitespace` sobre el archivo entero sí quedan
///    los saltos, pero **los del archivo**: estos documentos están cortados a
///    mano a ~78 columnas para leerse en un editor, así que cada párrafo
///    llegaría partido en renglones que en un iPhone no coinciden con el ancho
///    de nada.
///
/// La salida son **bloques**: los renglones se vuelven a unir en párrafos y cada
/// bloque se dibuja con la tipografía del juego. El markdown de línea
/// (`**negrita**`, `_cursiva_`) sí se interpreta, bloque por bloque, que es
/// exactamente donde `.inlineOnlyPreservingWhitespace` hace lo correcto.
struct LegalDocument {
    /// Cuál de los dos. El `rawValue` es el nombre del archivo **y** el sufijo
    /// del identifier de su fila en Ajustes, así que no hay dos listas que
    /// mantener sincronizadas.
    enum Kind: String, CaseIterable, Hashable, Identifiable {
        case privacy
        case terms

        var id: String { rawValue }
        var resourceName: String { rawValue }
        /// El identifier de la fila que abre este documento (spec §10.4).
        var identifier: String { "settings.\(rawValue)" }
        var titleKey: LocalizedStringKey { LocalizedStringKey(identifier) }
    }

    /// Un bloque del documento, ya re-armado.
    enum Block: Equatable {
        /// `# H1`. En estos documentos hay exactamente dos: la versión en
        /// español y la inglesa.
        case title(String)
        /// `## H2`: cada cláusula numerada.
        case heading(String)
        case bullet(String)
        case paragraph(String)
    }

    /// Parte un markdown en bloques, uniendo los renglones que pertenecen al
    /// mismo párrafo o a la misma viñeta.
    static func blocks(from markdown: String) -> [Block] {
        var blocks: [Block] = []
        /// El párrafo o la viñeta que se está acumulando.
        var pending: Block?

        func flush() {
            if let pending { blocks.append(pending) }
            pending = nil
        }

        for rawLine in markdown.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)

            // Línea en blanco: se cierra lo que venía.
            if line.isEmpty {
                flush()
                continue
            }
            // Regla horizontal (`---`): separa en el archivo, no dice nada en
            // pantalla. Sin este caso se dibujaría un párrafo con tres guiones.
            if line.allSatisfy({ $0 == "-" }) && line.count >= 3 {
                flush()
                continue
            }
            if line.hasPrefix("## ") {
                flush()
                blocks.append(.heading(String(line.dropFirst(3))))
                continue
            }
            if line.hasPrefix("# ") {
                flush()
                blocks.append(.title(String(line.dropFirst(2))))
                continue
            }
            if line.hasPrefix("- ") {
                flush()
                pending = .bullet(String(line.dropFirst(2)))
                continue
            }
            // Continuación: el renglón siguiente del párrafo o de la viñeta.
            switch pending {
            case .bullet(let text): pending = .bullet("\(text) \(line)")
            case .paragraph(let text): pending = .paragraph("\(text) \(line)")
            default: pending = .paragraph(line)
            }
        }
        flush()
        return blocks
    }

    /// Los bloques del documento, o `nil` si el `.md` no está en el bundle —que
    /// es un error de empaquetado, no algo que el jugador pueda arreglar, y por
    /// eso la vista lo nombra en vez de mostrar una pantalla vacía.
    static func load(_ kind: Kind, from bundle: Bundle = .main) -> [Block]? {
        guard let url = bundle.url(forResource: kind.resourceName, withExtension: "md"),
              let markdown = try? String(contentsOf: url, encoding: .utf8)
        else {
            Log.lifecycle.error("legal document missing from bundle: \(kind.resourceName).md")
            return nil
        }
        return blocks(from: markdown)
    }

    // MARK: Los dos idiomas

    /// Parte un documento bilingüe en sus mitades: **cada `# H1` abre una**. Lo
    /// que venga antes del primer título (no hay nada hoy) queda en la primera,
    /// para no perderlo.
    static func languageHalves(of blocks: [Block]) -> [[Block]] {
        var halves: [[Block]] = []
        for block in blocks {
            if case .title = block { halves.append([]) }
            if halves.isEmpty { halves.append([]) }
            halves[halves.count - 1].append(block)
        }
        return halves
    }

    /// La mitad que le toca al idioma con el que la app está corriendo.
    ///
    /// ⚠️ **Los `.md` traen los dos idiomas concatenados, español arriba e
    /// inglés abajo** —así se publican en `Distribution/site/`, y así viajan al
    /// bundle, byte a byte (hay un test que lo pinea)—. La pantalla los mostraba
    /// **enteros**: un jugador con el iPhone en inglés abría "Terms of Service"
    /// y se encontraba con 150 líneas en español antes de llegar a su versión.
    ///
    /// La mitad inglesa se reconoce por el sufijo `(English)` de su título, que
    /// es la convención de los dos documentos y ya estaba pineada por
    /// `LegalDocumentTests`. Si el documento tuviera una sola mitad —o ninguna
    /// reconocible— devuelve todo: quedarse sin términos es peor que mostrarlos
    /// de más.
    static func half(of blocks: [Block], forLanguage code: String) -> [Block] {
        let halves = languageHalves(of: blocks)
        guard halves.count > 1 else { return blocks }
        let englishIndex = halves.firstIndex { half in
            if case .title(let text)? = half.first { return text.hasSuffix("(English)") }
            return false
        }
        if code.hasPrefix("en") {
            return halves[englishIndex ?? halves.count - 1]
        }
        // Español es el idioma base y la primera mitad. Cualquier otro idioma
        // cae acá también, que es donde ya cae la UI entera: el juego se
        // traduce a dos y `es` es el que resuelve por defecto.
        return halves[englishIndex == 0 ? 1 : 0]
    }
}

// MARK: - La pantalla

/// **Legales** — la política de privacidad y los términos, adentro del juego
/// (spec §10.4).
///
/// Es una sub-vista **empujada** del `NavigationStack` del menú, igual que
/// Estadísticas y Logros: mismo panel, misma cabecera crema opaca, mismo
/// `ArtCloseButton` que cierra la hoja entera (acá `dismiss` desapilaría — ver
/// el docstring de `MenuView`).
///
/// El documento se agrupa por cláusula: la cinta naranja marca el **idioma**
/// (los dos `# H1`) y cada `## sección` es una `GameCard`, que es la misma
/// gramática que usa Estadísticas para sus cuatro grupos. Un documento legal es
/// una lista de cláusulas; dibujarlo como una lista de tarjetas es lo que lo
/// hace hojeable en un teléfono.
///
/// Cuando exista URL pública, estas dos filas pasan a ser `Link` y esta vista se
/// retira (spec §10.4).
struct LegalView: View {
    let document: LegalDocument.Kind
    /// Cierra la HOJA entera.
    let close: () -> Void

    var body: some View {
        ScrollView {
            // `VStack` y no `LazyVStack`: el documento más largo son ~120
            // bloques de texto, no hay controles adentro y la columna perezosa
            // le rompe el árbol de accesibilidad a las pantallas de este menú
            // (medido en la T11).
            VStack(alignment: .leading, spacing: Tokens.s12) {
                if let sections = Self.sections(of: document) {
                    ForEach(sections) { section in
                        switch section.kind {
                        case .language(let title):
                            SectionHeader(verbatim: title)
                                .frame(maxWidth: .infinity)
                                .padding(.top, Tokens.s4)
                        case .clause(let heading):
                            GameCard(style: .normal) {
                                VStack(alignment: .leading, spacing: Tokens.s8) {
                                    if let heading {
                                        Text(verbatim: heading)
                                            .font(Tokens.title)
                                            .foregroundStyle(Color("PaletteInk"))
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    ForEach(Array(section.blocks.enumerated()), id: \.offset) { _, block in
                                        Self.line(block)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                } else {
                    unavailableCard
                }
            }
            .padding(.horizontal, MenuView.panelInset)
            .padding(.top, Tokens.s4)
            .padding(.bottom, Tokens.s24)
        }
        .background { PanelBackground(art: "panel_config") }
        .safeAreaInset(edge: .top) { header }
        .navigationTitle(Text(verbatim: ""))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color("PaletteCream"), for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { ArtCloseButton(action: close) }
        }
    }

    // MARK: Cabecera

    /// Fondo crema OPACO: sin él el texto desfila por detrás del título.
    private var header: some View {
        PanelTitleBanner(titleKey: document.titleKey)
            .accessibilityIdentifier("legal.\(document.rawValue)")
            .padding(.top, 6)
            .padding(.bottom, Tokens.s8)
            .frame(maxWidth: .infinity)
            .background {
                Color("PaletteCream")
                    .shadow(color: .black.opacity(0.14), radius: 5, y: 3)
            }
    }

    /// El `.md` no está en el bundle. No es un estado que el jugador pueda
    /// arreglar, pero dejarlo en blanco haría que parezca que el juego no tiene
    /// términos —y sí los tiene, publicados—.
    private var unavailableCard: some View {
        GameCard(style: .normal) {
            VStack(spacing: Tokens.s8) {
                Image(systemName: "doc.questionmark")
                    .font(.system(size: 30, weight: .black))
                    .foregroundStyle(Color("PaletteOrange"))
                    .accessibilityHidden(true)
                Text("legal.unavailable")
                    .font(Tokens.body)
                    .foregroundStyle(Color("PaletteInk"))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: Texto

    /// Un bloque de cuerpo. El markdown de línea se interpreta acá —y sólo
    /// acá— con `.inlineOnlyPreservingWhitespace`: el bloque ya viene armado, así
    /// que lo único que queda por resolver son las negritas y las cursivas.
    @ViewBuilder private static func line(_ block: LegalDocument.Block) -> some View {
        switch block {
        case .bullet(let text):
            HStack(alignment: .firstTextBaseline, spacing: Tokens.s8) {
                Text(verbatim: "•")
                    .font(Tokens.body)
                    .foregroundStyle(Color("PaletteOrange"))
                    .accessibilityHidden(true)
                Text(attributed(text))
                    .font(Tokens.prose)
                    .foregroundStyle(Color("PaletteInk").opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
        case .paragraph(let text):
            Text(attributed(text))
                .font(Tokens.prose)
                .foregroundStyle(Color("PaletteInk").opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        // Los títulos ya los consumió `sections`: no llegan acá.
        case .title(let text), .heading(let text):
            Text(verbatim: text)
                .font(Tokens.title)
                .foregroundStyle(Color("PaletteInk"))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// ⚠️ El texto llega **del archivo**, no del catálogo: es un `String` ya
    /// resuelto y por eso va por `AttributedString`/`verbatim` y nunca por
    /// `LocalizedStringKey` (trampa 5 del HANDOFF). El documento trae su propia
    /// traducción adentro: español arriba, inglés abajo.
    private static func attributed(_ text: String) -> AttributedString {
        (try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(text)
    }

    // MARK: Agrupado

    /// Un grupo de la pantalla: o la cinta que anuncia el idioma, o una cláusula
    /// con su título y su cuerpo.
    private struct Section: Identifiable {
        enum Kind {
            case language(String)
            /// El encabezado es opcional: lo que va **antes** de la primera
            /// cláusula (el resumen honesto y la fecha) es cuerpo sin título.
            case clause(String?)
        }

        let id: Int
        let kind: Kind
        var blocks: [LegalDocument.Block] = []

        /// Las cintas no llevan cuerpo: el texto que sigue abre su propia
        /// tarjeta.
        var acceptsBody: Bool {
            if case .clause = kind { return true }
            return false
        }
    }

    /// Reparte los bloques del documento en grupos dibujables.
    ///
    /// Se queda con **la mitad del idioma en el que la app está corriendo**: el
    /// `.md` trae español e inglés concatenados y mostrar los dos hacía que un
    /// jugador en inglés tuviera que hojear el documento entero en español para
    /// llegar al suyo. El idioma sale de `preferredLocalizations`, que es contra
    /// lo que resuelve el resto de la UI —incluida la preferencia propia de
    /// Ajustes, que escribe `AppleLanguages`—, así que la pantalla no puede
    /// discrepar con el idioma de su propio título.
    private static func sections(of document: LegalDocument.Kind) -> [Section]? {
        guard let all = LegalDocument.load(document) else { return nil }
        let blocks = LegalDocument.half(
            of: all,
            forLanguage: Bundle.main.preferredLocalizations.first ?? "es"
        )
        var sections: [Section] = []

        func open(_ kind: Section.Kind) {
            sections.append(Section(id: sections.count, kind: kind))
        }

        for block in blocks {
            switch block {
            case .title(let text):
                open(.language(text))
            case .heading(let text):
                open(.clause(text))
            case .paragraph, .bullet:
                // Cuerpo antes de la primera cláusula (o después de una cinta):
                // abre una tarjeta sin título en vez de perderse.
                if sections.isEmpty || !sections[sections.count - 1].acceptsBody {
                    open(.clause(nil))
                }
                sections[sections.count - 1].blocks.append(block)
            }
        }
        // Una cinta de idioma seguida de otra cinta dejaría una tarjeta vacía.
        return sections.filter { section in
            if case .clause = section.kind { return !section.blocks.isEmpty }
            return true
        }
    }
}
