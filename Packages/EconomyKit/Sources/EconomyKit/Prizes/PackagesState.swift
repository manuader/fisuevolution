import Foundation

/// Una caja del Paquete de la Aduana (E14b B18): a quién trae y en qué piso cayó se decide
/// cuando aparece (`PackageRoller.rollBox`), y ahí se queda hasta que se abre.
///
/// Una caja «sin asignar» (`typeId == nil`) es la de un save anterior a B18, o la que cayó sin
/// nadie a quien traer: se sortea apenas haya lugar (`PackageRoller.assignPending`).
public struct PackageBox: Codable, Sendable, Hashable {
    /// El ordinal del piso de `typeId` (`FloorTable.ordinal(forTier:)`).
    public var floor: Int?
    public var typeId: String?
    /// Dónde está parada sobre la superficie de su piso (`PickupLayout`), de 0 a 1: `x` de la
    /// columna izquierda a la derecha y `y` (E14b B22) del frente al horizonte. No depende de la
    /// pantalla, así que viaja igual entre dispositivos.
    public var x: Double?
    /// Una caja de B18 trae `x` y no `y`: su lugar se vuelve a sortear (`PackagePlacer.placeMissing`).
    public var y: Double?

    public init(floor: Int? = nil, typeId: String? = nil, x: Double? = nil, y: Double? = nil) {
        self.floor = floor
        self.typeId = typeId
        self.x = x
        self.y = y
    }

    public static let unassigned = PackageBox()

    public var isAssigned: Bool { floor != nil && typeId != nil }

    /// Su lugar, si ya tiene los dos ejes.
    public var spot: PackageSpot? {
        guard let x, let y else { return nil }
        return PackageSpot(x: x, y: y)
    }
}

/// Un lugar de la superficie de un piso, de 0 a 1 en cada eje (`PackageBox.x`, `PackageBox.y`).
public struct PackageSpot: Sendable, Hashable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

/// Lo que una caja tiene que respetar al caer en un piso (E14b B22), en las mismas unidades
/// de 0 a 1 que `PackageSpot`. La geometría real la pone la app (`PickupLayout.packageArea`).
public struct PackageFloorArea: Sendable, Equatable {
    /// Un rectángulo donde no cae ninguna caja (el colchón, la zona de caminata del visitante).
    public struct Zone: Sendable, Equatable {
        public var x: ClosedRange<Double>
        public var y: ClosedRange<Double>

        public init(x: ClosedRange<Double>, y: ClosedRange<Double>) {
            self.x = x
            self.y = y
        }

        public func contains(_ spot: PackageSpot) -> Bool {
            x.contains(spot.x) && y.contains(spot.y)
        }
    }

    /// La separación mínima entre los centros de dos cajas, de costado y de fondo: dos cajas se
    /// pisan si una cae dentro de la elipse de esos semiejes alrededor de la otra.
    public var gapX: Double
    public var gapY: Double
    public var keepOut: [Zone]

    public init(gapX: Double, gapY: Double, keepOut: [Zone] = []) {
        self.gapX = gapX
        self.gapY = gapY
        self.keepOut = keepOut
    }

    /// Sin reglas: cualquier lugar vale.
    public static let open = PackageFloorArea(gapX: 0, gapY: 0)
}

/// El buzón del Paquete de la Aduana (vive en `meta.engagement`). El reloj es
/// de JUEGO ACTIVO: el background no lo mueve.
public struct PackagesState: Codable, Sendable, Equatable {
    /// Segundos de juego hasta el próximo. `nil` = nunca se programó (partida
    /// nueva o save anterior a E5): el reloj arranca en `firstPackageAfterSeconds`.
    public var secondsUntilNext: Double?
    /// Las cajas que esperan que el jugador las abra, la más vieja primero (E14b B18).
    public var boxes: [PackageBox]

    /// Cuántas esperan. Sumar agrega cajas sin asignar (se sortean al asentarse); restar saca
    /// las más nuevas.
    public var waiting: Int {
        get { boxes.count }
        set {
            let target = max(0, newValue)
            if target > boxes.count {
                boxes.append(contentsOf: Array(repeating: .unassigned, count: target - boxes.count))
            } else {
                boxes.removeLast(boxes.count - target)
            }
        }
    }

    public static let initial = PackagesState()

    public init(secondsUntilNext: Double? = nil, waiting: Int = 0) {
        self.secondsUntilNext = secondsUntilNext
        self.boxes = Array(repeating: .unassigned, count: max(0, waiting))
    }

    public init(secondsUntilNext: Double? = nil, boxes: [PackageBox]) {
        self.secondsUntilNext = secondsUntilNext
        self.boxes = boxes
    }

    /// Las del piso `ordinal`, la más vieja primero.
    public func boxes(onFloor ordinal: Int) -> [PackageBox] {
        boxes.filter { $0.floor == ordinal }
    }

    /// Saca una caja igual a `box` (la más vieja de las iguales). `false` si no estaba.
    @discardableResult
    public mutating func remove(_ box: PackageBox) -> Bool {
        guard let index = boxes.firstIndex(of: box) else { return false }
        boxes.remove(at: index)
        return true
    }

    private enum CodingKeys: String, CodingKey {
        case secondsUntilNext, waiting, boxes
    }

    /// Un save anterior a B18 trae sólo `waiting = N`: N cajas sin asignar, que se sortean al
    /// cargar con la regla nueva. Las cajas de B18 vienen sin `y` y se decodifican con `nil`.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        secondsUntilNext = try container.decodeIfPresent(Double.self, forKey: .secondsUntilNext)
        if let boxes = try container.decodeIfPresent([PackageBox].self, forKey: .boxes) {
            self.boxes = boxes
        } else {
            let legacy = try container.decodeIfPresent(Int.self, forKey: .waiting) ?? 0
            boxes = Array(repeating: .unassigned, count: max(0, legacy))
        }
    }

    /// Se sigue escribiendo `waiting`: una versión anterior de la app que lea este save ve
    /// cuántas cajas hay.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(secondsUntilNext, forKey: .secondsUntilNext)
        try container.encode(boxes.count, forKey: .waiting)
        try container.encode(boxes, forKey: .boxes)
    }
}
