import EconomyKit

// Las tablas de EconomyKit que llegan como secciones de la config de personalización. Su
// `validate()` (todo o nada) vive en EconomyKit; acá sólo se declara la conformidad.

/// Sección `player_value` (F1, contrato C2).
extension PlayerValueTables: PersonalizationSection {}

/// Sección `segments` (F2).
extension SegmentLevers: PersonalizationSection {}
