# player-value-model — entrenar el valor por jugador (2.1 F6)

Entrena el modelo de árboles (formato C1 `tree-1`) que la app evalúa en el teléfono (`TreeEnsemble` en EconomyKit).
Hoy no hay datos: sólo el andamiaje, probado con datos sintéticos. Entrenar el modelo real es F6-T4 (necesita miles de
jugadores etiquetados, la telemetría prendida y el visto bueno del abogado).

## Qué lee y de dónde
- `export.sql` lo corre **el dueño** con `service_role` (`psql ... --csv > export.csv`) sobre `telemetry_events`.
  Un renglón por instalación **sin `install_id`**: cohorte (día de primera aparición), país, modelo de dispositivo y
  agregados de los **primeros 7 días** (sesiones, duración media, recompensados e importe medio, compra, ofertas,
  prestigios). Etiqueta: ingreso de publicidad de los **días 8–37**; sólo instalaciones con 37 días completos.
- Verificá que la moneda de `micros` sea USD antes de entrenar.

## Qué produce
- `out/model.json` (C1: sólo árboles; no contiene datos de nadie) y un resumen **agregado** por stdout (cantidades y
  error absoluto medio del modelo y de la base por tier de país en la validación temporal).
- **Nunca** sale del script un dato por instalación: no hay logs ni archivos intermedios por renglón. El CSV queda
  local, está en `.gitignore` y se borra al terminar. No se sube a ningún lado.

## Uso
```
python3 -m venv .venv && .venv/bin/pip install -r requirements.txt     # .venv está ignorado por git
.venv/bin/python train.py --csv export.csv --out out/model.json --tables ../../<player_value.json>
python3 -m unittest -v          # tests sintéticos; no necesitan xgboost ni lightgbm
python3 fixture.py check <tree_fixture.json> <tree_fixture_cases.json>   # Python == Swift
```
`--engine auto` usa XGBoost, si no LightGBM, si no el entrenador de referencia en Python puro (sólo para humo/tests).
`--tables` es el `player_value.json` de la app: de ahí salen `country_tier` y `device_tier` (prefijo más largo).

## Criterios
- Etiqueta en `log1p`; el link del modelo es `expm1`. Validación **temporal**: se entrena con las cohortes viejas y se
  valida con el 20 % más nuevo (una cohorte no se parte).
- R8: el modelo sólo pasa a producción si **gana a las reglas** (error medio de ingreso por jugador en la validación
  temporal). Si no gana, `train.py` sale con código 2 y F6 queda en reglas.
- Topes del formato: 500 árboles, profundidad 8, 256 KB; `treeformat.validate` los chequea antes de escribir.
- Semántica de ramas: `x < threshold` va a la izquierda; NaN va por `default_left`. LightGBM (`<=`) se convierte
  corriendo el umbral un ulp.

## Contrato con F6-T2
`train.FEATURES` fija nombres y orden: `country_tier, device_tier, sessions_7d, mean_session_seconds, rewarded_count,
avg_rewarded_micros, has_purchased, offers_seen, prestige_count`. `PlayerValueFeatures` (F6-T2) tiene que producir el
mismo orden y nombres (el modelo exportado los lleva en `features`; si la app no tiene alguno, el modelo es inválido).
