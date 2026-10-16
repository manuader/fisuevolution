import EconomyKit

/// La sección `moments` de la config remota (2.1 E15 F3): `PersonalizationConfig.section` la valida y, si
/// algo sale de los topes del código, la descarta entera.
extension MomentsConfig: PersonalizationSection {}
