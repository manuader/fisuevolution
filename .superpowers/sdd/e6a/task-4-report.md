# E6a T4 — oro_shop.json (informe)
Estado: DONE. Rama v2i/e6a-t4, base 2c8c86f.
- oro_shop.json: 13 ítems de la tabla aprobada; cargado y validado en GameContentLoader (`GameContent.oroShop`).
- Validación extra en `GameContentLoader.validate(oroShop:floorIDs:packages:)`: isFinite en crecimiento y valores de nivel; nivel de "mejor proveedor" fuera de la tabla `r` de packages.json se rechaza.
- OroShopCopy.swift; DynamicFamily.oroShop; OroShopContentTests (7).
- Claves: Tools/v2/claves-pendientes/e6a-t4.json (20). Catálogo NO tocado; verificado aplicándolo en el worktree y revirtiéndolo.
- Oráculo `tarea`: OroShopContentTests + LocalizationCompletenessTests + GameContentValidationTests VERDE con el snapshot aplicado (46); luego OroShopContentTests VERDE (7). Sin el snapshot, LocalizationCompletenessTests y copyInBothLanguages quedan rojos hasta que el controlador lo aplique.
- Carries: T6 bloquea el segundo ×3 antes de cobrar; T12 reusa LootBoxGate y no ofrece Bienvenida en BE/AU. La forma del JSON lo permite (isChance, dailyLimit).
- No se pudo validar isFinite de packages/treasures/wheel (no son de esta tarea).
