import SwiftUI

/// Los 16 iconos del rediseño, dibujados con formas SwiftUI.
///
/// Son la cara del juego mientras el batch de PNGs no exista: cada uno es una
/// composición de 2-5 formas con relleno plano de paleta y contorno ink, el
/// mismo idioma flat hecho a mano del resto del arte. Se consumen SIEMPRE por
/// `GameIcon(artKey:) { VectorXIcon() }`, así que el día que la clave entre al
/// manifest el PNG los reemplaza sin tocar una línea de código.
///
/// **Espacio de diseño**: todos se dibujan en un cuadrado de 100×100 con medidas
/// literales (mucho más legible que multiplicar cada número por un factor) y
/// `IconCanvas` los escala al tamaño real. Como una `Image.resizable()`, son
/// **flexibles**: no tienen tamaño propio y van siempre dentro de un `.frame` —
/// `GameIcon` y `IconButton` se lo ponen.

// MARK: - Lienzo

/// Constantes del espacio de diseño de los iconos.
enum IconSpec {
    /// Lado del lienzo de diseño.
    static let side: CGFloat = 100
    /// Contorno principal: 6.5/100 ≈ 2 pt en un icono de 30 pt, el grosor del
    /// resto del arte del juego.
    static let stroke: CGFloat = 6.5
    /// Contorno de los detalles chicos (aros, casillas, rejillas).
    static let detail: CGFloat = 4.5
    static let ink = Color("PaletteInk")
}

/// Escala el dibujo de 100×100 al tamaño que proponga el contenedor.
struct IconCanvas<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            content()
                .frame(width: IconSpec.side, height: IconSpec.side)
                .scaleEffect(side / IconSpec.side)
                .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

/// Un `Path` escrito en coordenadas del lienzo (0…100). El lienzo garantiza el
/// rect, así que el dibujo puede usar números absolutos.
struct IconPath: Shape {
    let build: @Sendable (inout Path) -> Void

    init(_ build: @escaping @Sendable (inout Path) -> Void) {
        self.build = build
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        build(&path)
        return path
    }
}

extension Shape {
    /// Relleno plano + contorno ink: el idioma visual del juego en una línea.
    func inked(_ fill: Color, lineWidth: CGFloat = IconSpec.stroke) -> some View {
        self.fill(fill)
            .overlay(
                self.stroke(
                    IconSpec.ink,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                )
            )
    }
}

private extension Path {
    mutating func line(_ points: [CGPoint]) {
        guard let first = points.first else { return }
        move(to: first)
        for point in points.dropFirst() { addLine(to: point) }
    }
}

private func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }

// MARK: - Tab 1 · FisuJobs (ui_tab_jobs)

/// La cara del Fisura. El atlas ya trae `homeless_face`, así que en la práctica
/// se ve el retrato real recortado en círculo; el vectorial es el seguro por si
/// la clave desaparece del manifest.
struct VectorTabJobsIcon: View {
    var body: some View {
        IconCanvas {
            ZStack {
                Circle()
                    .fill(Color("PaletteYellow"))
                    .frame(width: 88, height: 88)
                if let face = UIArt.image("homeless_face") {
                    face
                        .resizable()
                        .scaledToFill()
                        .frame(width: 88, height: 88)
                        .clipShape(Circle())
                } else {
                    // Carita mínima: dos ojos y una sonrisa. A 30 pt se lee
                    // "alguien", que es todo lo que tiene que decir el tab.
                    Group {
                        Circle().fill(IconSpec.ink).frame(width: 12, height: 14)
                            .position(x: 38, y: 44)
                        Circle().fill(IconSpec.ink).frame(width: 12, height: 14)
                            .position(x: 62, y: 44)
                        IconPath { path in
                            path.move(to: p(34, 62))
                            path.addQuadCurve(to: p(66, 62), control: p(50, 78))
                        }
                        .stroke(IconSpec.ink, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    }
                    .frame(width: 100, height: 100)
                }
                Circle()
                    .strokeBorder(IconSpec.ink, lineWidth: IconSpec.stroke)
                    .frame(width: 88, height: 88)
            }
        }
    }
}

// MARK: - Tab 2 · Upgrades (ui_tab_upgrades)

/// Flecha gruesa hacia arriba sobre su base: "subir de nivel" en dos formas.
struct VectorTabUpgradesIcon: View {
    var body: some View {
        IconCanvas {
            ZStack {
                IconPath { path in
                    path.line([
                        p(50, 8), p(86, 46), p(65, 46), p(65, 74),
                        p(35, 74), p(35, 46), p(14, 46)
                    ])
                    path.closeSubpath()
                }
                .inked(Color("PaletteGreen"))

                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .inked(Color("PaletteGreen"))
                    .frame(width: 52, height: 14)
                    .position(x: 50, y: 88)
            }
        }
    }
}

// MARK: - Tab 3 · Customization (ui_tab_skins)

/// Gorra con visera arriba + pincel abajo, separados: apilarlos los volvía una
/// mancha (la corona alta leía como campana y el pincel como un puntito).
struct VectorTabSkinsIcon: View {
    var body: some View {
        IconCanvas {
            ZStack {
                // Gorra en un solo trazo: cúpula + visera. Las dos horizontales
                // rectas (arriba y abajo de la visera) son lo que la hace leer
                // "gorra"; con la visera curva de punta a punta leía "campana".
                IconPath { path in
                    path.move(to: p(20, 52))
                    path.addQuadCurve(to: p(70, 52), control: p(45, 6))
                    path.addLine(to: p(92, 52))
                    path.addQuadCurve(to: p(88, 66), control: p(98, 63))
                    path.addLine(to: p(12, 66))
                    path.closeSubpath()
                }
                .inked(Color("PaletteBlue"))

                // Costura de la corona: una línea, no el botoncito de arriba
                // —que a 30 pt le daba perfil de pico de pájaro—.
                IconPath { path in
                    path.move(to: p(45, 30))
                    path.addQuadCurve(to: p(45, 52), control: p(41, 41))
                }
                .stroke(IconSpec.ink.opacity(0.55), style: StrokeStyle(lineWidth: 4, lineCap: .round))

                // Pincel abajo a la izquierda, con la punta hacia la gorra:
                // mango fino, virola y punta trapezoidal, que es lo que lo
                // distingue de una cuchara.
                ZStack {
                    // El lienzo del pincel también es 100×100 (lo fija el path),
                    // así que se dibuja alrededor de su centro y después se
                    // rota y se posiciona entero.
                    IconPath { path in
                        path.line([p(40, 22), p(60, 22), p(58, 43), p(42, 43)])
                        path.closeSubpath()
                    }
                    .inked(Color("PalettePink"), lineWidth: IconSpec.detail)
                    .frame(width: 100, height: 100)

                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .inked(Color("PaletteCream"), lineWidth: IconSpec.detail)
                        .frame(width: 21, height: 9)
                        .offset(y: -3)

                    Capsule()
                        .inked(Color("PaletteOrange"), lineWidth: IconSpec.detail)
                        .frame(width: 12, height: 28)
                        .offset(y: 14)
                }
                .rotationEffect(.degrees(-28))
                .position(x: 30, y: 76)
            }
        }
    }
}

// MARK: - Tab 4 · Regalos (ui_tab_gifts)

/// Caja con moño: cuerpo, tapa, cinta y dos lazos.
struct VectorTabGiftsIcon: View {
    var body: some View {
        IconCanvas {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .inked(Color("PalettePink"))
                    .frame(width: 68, height: 50)
                    .position(x: 50, y: 68)

                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .inked(Color("PalettePink"))
                    .frame(width: 82, height: 20)
                    .position(x: 50, y: 40)

                Rectangle()
                    .inked(Color("PaletteYellow"), lineWidth: IconSpec.detail)
                    .frame(width: 15, height: 62)
                    .position(x: 50, y: 62)

                Group {
                    Ellipse()
                        .inked(Color("PaletteYellow"), lineWidth: IconSpec.detail)
                        .frame(width: 26, height: 19)
                        .rotationEffect(.degrees(-18))
                        .position(x: 36, y: 20)
                    Ellipse()
                        .inked(Color("PaletteYellow"), lineWidth: IconSpec.detail)
                        .frame(width: 26, height: 19)
                        .rotationEffect(.degrees(18))
                        .position(x: 64, y: 20)
                }
                .frame(width: 100, height: 100)
            }
        }
    }
}

// MARK: - Tab 5 · Tienda (ui_tab_shop)

/// Bolsa de compras: cuerpo trapezoidal, asa y la banda del doblez.
struct VectorTabShopIcon: View {
    var body: some View {
        IconCanvas {
            ZStack {
                IconPath { path in
                    path.addArc(center: p(50, 40), radius: 19,
                                startAngle: .degrees(180), endAngle: .degrees(0),
                                clockwise: false)
                }
                .stroke(IconSpec.ink, style: StrokeStyle(lineWidth: 7, lineCap: .round))

                IconPath { path in
                    path.line([p(21, 38), p(79, 38), p(88, 92), p(12, 92)])
                    path.closeSubpath()
                }
                .inked(Color("PaletteOrange"))

                IconPath { path in
                    path.line([p(21, 38), p(79, 38), p(80, 52), p(20, 52)])
                    path.closeSubpath()
                }
                .inked(Color("PaletteYellow"), lineWidth: IconSpec.detail)
            }
        }
    }
}

// MARK: - Tab 6 · Menú (ui_tab_menu)

/// Cuaderno anillado: hoja, lomo, tres aros y dos renglones.
struct VectorTabMenuIcon: View {
    var body: some View {
        IconCanvas {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .inked(Color("PaletteCream"))
                    .frame(width: 64, height: 80)
                    .position(x: 56, y: 52)

                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .inked(Color("PaletteBlue"))
                    .frame(width: 20, height: 80)
                    .position(x: 30, y: 52)

                Group {
                    ForEach([28, 52, 76], id: \.self) { y in
                        Capsule()
                            .inked(Color("PaletteCream"), lineWidth: IconSpec.detail)
                            .frame(width: 24, height: 11)
                            .position(x: 30, y: CGFloat(y))
                    }
                    ForEach([42, 62], id: \.self) { y in
                        Capsule()
                            .fill(IconSpec.ink.opacity(0.7))
                            .frame(width: 34, height: 5)
                            .position(x: 62, y: CGFloat(y))
                    }
                }
                .frame(width: 100, height: 100)
            }
        }
    }
}

// MARK: - HUD · moneda + (ui_coin_plus)

/// La moneda del juego con un badge rosa de "+": el atajo a la tienda.
struct VectorCoinPlusIcon: View {
    var body: some View {
        IconCanvas {
            ZStack {
                CoinIcon(size: 74)
                    .position(x: 42, y: 58)

                ZStack {
                    Circle()
                        .inked(Color("PalettePink"), lineWidth: IconSpec.detail)
                        .frame(width: 40, height: 40)
                    Capsule().fill(.white).frame(width: 20, height: 6)
                    Capsule().fill(.white).frame(width: 6, height: 20)
                }
                .position(x: 76, y: 26)
            }
        }
    }
}

// MARK: - HUD · ascensor (ui_elevator)

/// Cabina con puertas y display de piso + los dos botones de llamada. El display
/// amarillo es lo que lo despega de "una puerta cualquiera".
struct VectorElevatorIcon: View {
    var body: some View {
        IconCanvas {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .inked(Color("PaletteCream"))
                    .frame(width: 54, height: 82)
                    .position(x: 35, y: 50)

                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .inked(Color("PaletteYellow"), lineWidth: IconSpec.detail)
                    .frame(width: 32, height: 13)
                    .position(x: 35, y: 24)

                Capsule()
                    .fill(IconSpec.ink)
                    .frame(width: 4, height: 44)
                    .position(x: 35, y: 60)

                IconPath { path in
                    path.line([p(70, 42), p(84, 20), p(98, 42)])
                    path.closeSubpath()
                }
                .inked(Color("PaletteGreen"), lineWidth: IconSpec.detail)

                IconPath { path in
                    path.line([p(70, 58), p(84, 80), p(98, 58)])
                    path.closeSubpath()
                }
                .inked(Color("PaletteBlue"), lineWidth: IconSpec.detail)
            }
        }
    }
}

// MARK: - Menú · organigrama (ui_menu_orgchart)

/// Árbol de nodos: un jefe arriba, dos abajo y las conexiones.
struct VectorOrgchartIcon: View {
    var body: some View {
        IconCanvas {
            ZStack {
                IconPath { path in
                    path.move(to: p(50, 36))
                    path.addLine(to: p(50, 52))
                    path.move(to: p(22, 52))
                    path.addLine(to: p(78, 52))
                    path.move(to: p(22, 52))
                    path.addLine(to: p(22, 66))
                    path.move(to: p(78, 52))
                    path.addLine(to: p(78, 66))
                }
                .stroke(IconSpec.ink, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))

                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .inked(Color("PaletteYellow"), lineWidth: IconSpec.detail)
                    .frame(width: 38, height: 26)
                    .position(x: 50, y: 22)

                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .inked(Color("PaletteBlue"), lineWidth: IconSpec.detail)
                    .frame(width: 32, height: 26)
                    .position(x: 22, y: 80)

                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .inked(Color("PaletteBlue"), lineWidth: IconSpec.detail)
                    .frame(width: 32, height: 26)
                    .position(x: 78, y: 80)
            }
        }
    }
}

// MARK: - Menú · estadísticas (ui_menu_stats)

/// Gráfico de barras ascendente sobre su eje.
struct VectorStatsIcon: View {
    var body: some View {
        IconCanvas {
            ZStack {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .inked(Color("PaletteBlue"), lineWidth: IconSpec.detail)
                    .frame(width: 21, height: 32)
                    .position(x: 22, y: 72)

                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .inked(Color("PaletteGreen"), lineWidth: IconSpec.detail)
                    .frame(width: 21, height: 50)
                    .position(x: 50, y: 63)

                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .inked(Color("PaletteYellow"), lineWidth: IconSpec.detail)
                    .frame(width: 21, height: 68)
                    .position(x: 78, y: 54)

                Capsule()
                    .fill(IconSpec.ink)
                    .frame(width: 84, height: 6)
                    .position(x: 50, y: 91)
            }
        }
    }
}

// MARK: - Logros · trofeo (ui_menu_trophy, ui_trophy_bronze/silver/gold)

/// La misma copa en tres metales. `bronze` y `gold` salen de la paleta;
/// `silver` es el único color fuera de ella —un gris claro— porque la paleta no
/// tiene ninguno neutro y un trofeo crema no se distinguiría del fondo.
struct VectorTrophyIcon: View {
    enum Tier: String, CaseIterable {
        case bronze
        case silver
        case gold

        var metal: Color {
            switch self {
            case .bronze: Color("PaletteOrange")
            case .silver: Color(white: 0.82)
            case .gold: Color("PaletteYellow")
            }
        }

        /// La clave del atlas de este metal (`ui_trophy_bronze/silver/gold`),
        /// la misma que encoló la T19. Vive en el enum porque los DOS
        /// call-sites del trofeo —la fila de Logros y el toast— tienen que
        /// resolver la misma clave: duplicada en cada vista, un batch que
        /// aterriza en una y no en la otra mostraría dos trofeos distintos.
        var artKey: String { "ui_trophy_\(rawValue)" }
    }

    let tier: Tier

    var body: some View {
        IconCanvas {
            ZStack {
                // Asas: dos curvas simétricas, dibujadas antes que la copa para
                // que nazcan de adentro del cuenco.
                IconPath { path in
                    path.move(to: p(27, 22))
                    path.addQuadCurve(to: p(31, 50), control: p(3, 34))
                    path.move(to: p(73, 22))
                    path.addQuadCurve(to: p(69, 50), control: p(97, 34))
                }
                .stroke(IconSpec.ink, style: StrokeStyle(lineWidth: 7, lineCap: .round))

                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .inked(tier.metal, lineWidth: IconSpec.detail)
                    .frame(width: 16, height: 22)
                    .position(x: 50, y: 68)

                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .inked(tier.metal, lineWidth: IconSpec.detail)
                    .frame(width: 46, height: 13)
                    .position(x: 50, y: 86)

                IconPath { path in
                    path.move(to: p(24, 16))
                    path.addLine(to: p(76, 16))
                    path.addLine(to: p(72, 44))
                    path.addQuadCurve(to: p(50, 64), control: p(67, 61))
                    path.addQuadCurve(to: p(28, 44), control: p(33, 61))
                    path.closeSubpath()
                }
                .inked(tier.metal)

                Capsule()
                    .fill(.white.opacity(0.55))
                    .frame(width: 8, height: 22)
                    .rotationEffect(.degrees(12))
                    .position(x: 38, y: 34)
            }
        }
    }
}

// MARK: - Menú · ajustes (ui_menu_settings)

/// Llave inglesa. La silueta se arma con operaciones booleanas de `Path`
/// (`union`/`subtracting`), así el mango y la cabeza quedan bajo UN solo
/// contorno en vez de dos formas superpuestas con la costura a la vista.
struct VectorSettingsIcon: View {
    var body: some View {
        IconCanvas {
            IconPath { path in
                let head = Path(ellipseIn: CGRect(x: 25, y: 6, width: 50, height: 50))
                let handle = Path(roundedRect: CGRect(x: 40, y: 44, width: 20, height: 52),
                                  cornerRadius: 10)
                let hole = Path(ellipseIn: CGRect(x: 37, y: 18, width: 26, height: 26))
                let mouth = Path(CGRect(x: 40, y: -4, width: 20, height: 26))
                let wrench = head.union(handle).subtracting(hole).subtracting(mouth)
                let rotation = CGAffineTransform(translationX: -50, y: -50)
                    .concatenating(CGAffineTransform(rotationAngle: -.pi / 6))
                    .concatenating(CGAffineTransform(translationX: 50, y: 50))
                path.addPath(wrench.applying(rotation))
            }
            .inked(Color("PaletteBlue"))
        }
    }
}

// MARK: - Regalos · calendario (ui_daily_calendar)

/// Hoja de calendario con casillas y el tilde del día reclamado.
struct VectorCalendarIcon: View {
    var body: some View {
        IconCanvas {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(Color("PaletteCream"))
                    .frame(width: 78, height: 70)
                    .position(x: 50, y: 58)

                UnevenRoundedRectangle(topLeadingRadius: 11, topTrailingRadius: 11, style: .continuous)
                    .fill(Color("PalettePink"))
                    .frame(width: 78, height: 20)
                    .position(x: 50, y: 33)

                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(IconSpec.ink, lineWidth: IconSpec.stroke)
                    .frame(width: 78, height: 70)
                    .position(x: 50, y: 58)

                Group {
                    Capsule()
                        .inked(Color("PaletteCream"), lineWidth: IconSpec.detail)
                        .frame(width: 10, height: 20)
                        .position(x: 34, y: 20)
                    Capsule()
                        .inked(Color("PaletteCream"), lineWidth: IconSpec.detail)
                        .frame(width: 10, height: 20)
                        .position(x: 66, y: 20)
                }
                .frame(width: 100, height: 100)

                Group {
                    ForEach([28, 47], id: \.self) { x in
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(IconSpec.ink.opacity(0.22))
                            .frame(width: 13, height: 13)
                            .position(x: CGFloat(x), y: 58)
                    }
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(IconSpec.ink.opacity(0.22))
                        .frame(width: 13, height: 13)
                        .position(x: 28, y: 77)
                }
                .frame(width: 100, height: 100)

                // Tilde con "contorno": el mismo trazo dos veces, ink grueso
                // debajo y verde encima.
                Group {
                    checkmark.stroke(IconSpec.ink, style: StrokeStyle(lineWidth: 15, lineCap: .round, lineJoin: .round))
                    checkmark.stroke(Color("PaletteGreen"), style: StrokeStyle(lineWidth: 9, lineCap: .round, lineJoin: .round))
                }
            }
        }
    }

    private var checkmark: IconPath {
        IconPath { path in
            path.line([p(52, 72), p(64, 84), p(88, 54)])
        }
    }
}

// MARK: - La mano del tutorial

