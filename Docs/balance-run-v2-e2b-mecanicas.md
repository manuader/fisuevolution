# E2b T12 — las mecánicas de la 2.0 medidas una por una, contra el contrato de 45 h

Datos: `Docs/balance-run-v2-e2b-mecanicas.csv` (una fila por corrida, 75 corridas). Simulador: `Tools/pacing-sim`, `swift build -c release` (nada del juego cambió). Base `f1077147`.

## Cómo se reproduce

Con `R=FisuEvolution/Resources` y `P=Tools/pacing-sim/.build/release/pacing-sim`, cada corrida es:

```
$P --economy $R/Data/economy.json --tiers $R/Data/tiers.json --upgrades $R/Config/upgrades.json --sources $R/Config <flags> --max-days <N> --csv build/e2b/<nombre>.csv
```

La columna `flags` del CSV trae los flags exactos de cada corrida; `--max-days` es 90 en r00/r01 y 400 en el resto. Tres cadenas acumulativas, una por par del gate: **A** = (g 1,12 · r 1) + K 24; **B** = (1,08 · 0,5) + K 24; **C** = (1,12 · 2) + K 24. Los renglones 0–2 son comunes. Los pasos de la cadena (flags que se suman): 3 `--growth g --merge-refund r` · 4 `--price-relief 24` · 5 `--inherit` · 6 `--capacity 15 --staffed 0.05` · 7 `--wall` · 8 `--prestige-discount` · 9 `--profile free` · 10 `--bands "8:1.45,13:1.6,25:1.7" --growth-step 0.01@luxury` · 11 `--profile ads` / `--profile max` en lugar de free · 12 `--no-reincarnation` · 13 `--seed-fraction 0.1` y `0.9`. Las corridas `s01…s35` son la lectura de palancas (abajo).

Base: sin flags nuevos, `--max-days 90` da **Dios 31,34 h · 13 reenc.** (la vigente del `completo`; el 30,73 del plan es anterior). r01 (perillas en v1) es idéntica a r00. r02 (`--prestige-threshold 4`) da 22,34 h · 6, igual al HANDOFF. La base reproduce; no hubo que parar.

## 1. Tabla delta (Dios en h activas · reenc.; Δ = contra el renglón anterior)

| # | Renglón | A (1,12·1) | Δ A | B (1,08·0,5) | C (1,12·2) |
|---|---|---|---|---|---|
| 0 | base | 31,34 · 13 | | = | = |
| 1 | perillas en v1 | 31,34 · 13 | 0 | = | = |
| 2 | umbral ×5 | 22,34 · 6 | −9,00 | = | = |
| 3 | g + reintegro | 18,72 · 6 | −3,62 | 21,03 · 6 | **416,43 · 5** |
| 4 | amortiguador K 24 | 18,71 · 6 | −0,01 | 21,03 · 6 | 415,77 · 5 |
| 5 | herencia | 18,43 · 6 | −0,28 | 21,02 · 6 | 525,45 · 6 |
| 6 | cap. 15 + en marcha 0,05 | 18,68 · 6 | +0,25 | 20,38 · 6 | 10,74 · 6 |
| 7 | piso móvil | 18,68 · 6 | 0 | 20,38 · 6 | 10,74 · 6 |
| 8 | descuento de prestigio | 18,11 · 6 | −0,57 | 18,77 · 6 | 9,10 · 5 |
| 9 | perfil free (fuentes) | 13,05 · 6 | −5,06 | 13,38 · 6 | 8,35 · 6 |
| 10 | bandas + paso por piso | **12,71 · 6** | −0,34 | 15,67 · 7 | 6,69 · 5 |
| 11 | ads / max | 11,40 / 11,79 | | 11,30 / 14,57 | 8,65 / 9,32 |
| 12 | 10 sin reencarnar | 39,10 · 0 | | 51,50 · 0 | 33,27 · 0 |
| 13 | 10 con semilla 0,1 / 0,9 | 12,72 / 13,44 | | 15,67 / 13,67 | 6,69 / 6,69 |

Lectura: lo que acorta es el umbral ×5 (−9,0), el reintegro con g 1,12 (−3,6) y sobre todo **las fuentes gratis (−5,1, casi 28 %)**. El amortiguador K, la herencia, el piso móvil y las bandas de v1 son casi neutros para Dios (K sí adelanta la 1ª reencarnación: ver abajo). **La cadena C (r = 2) es degenerada**: el reintegro de 2 compras convierte los precios en un muro (pared en T13–T14 las 5 runs, Dios 416 h) hasta que el renglón 6 lo desarma; no es una curva candidata. La 1ª reencarnación queda en 0,55–1,0 h en A/B (contrato nuevo: 1–2 h).

## 2. El techo del prestigio (contrato 6, duda 1)

El techo por run (el mejor pago posible con los precios de esa configuración) en las corridas pedidas:

| Corrida | Techo por run | ¿≥ 0,65? |
|---|---|---|
| 9A (free) | 55 % · 59 % · 57 % | **No: las tres** |
| 9B | 61 % · 56 % · 58 % | **No** |
| 10A (bandas) | 65 % · 55 % | la 2ª run está en 55 %: **No** |
| 10B | 66 % · 58 % | **No** (la 2ª) |
| 9C / 10C | sin dato (la cadena C no genera runs con pared) | — |

**El contrato 6 es inalcanzable con knobs de precio en esta forma en 9A, 9B, 10A y 10B** (techo mínimo 55 %). Y empeora cuando el juego se alarga: en la configuración de 45 h de abajo el techo cae a 43–61 %. El pago real medido (`reencarnar_paga`) es 33–47 % en 9A y 52–54 % en 10A, y en s29 va de 24 a 49 %. Es lo primero que el controlador le lleva al dueño: el contrato 6 (≥ 65 %) no sale de bandas ni de g/r/K; hace falta otra palanca (la fórmula del ORO, `--oro-divisor/--oro-exponent`, o relajar el 6).

## 3. La ley de diseño

R ≈ ln(ORO_dios/ORO₁)/ln 5, con `oro_al_llegar_a_dios` y la 1ª reencarnación (ORO₁ = 1): da **5,96 (9A) · 6,04 (10A) · 6,37 (10B) · 6,63 (s29)** contra 6, 6, 7 y 7 reencarnaciones medidas. La ley se sostiene dentro de ±0,4: R es el entero ≈ redondeo de la fórmula (6,0 → 6 reenc.; 6,4–6,6 → 7). Consecuencia: para quedar en 5–6 reencarnaciones el ORO a Dios tiene que ser ≲ 5⁶·ORO₁ ≈ 15.600 (con ORO₁ = 1); la config de 45 h acumula 43.075 y por eso da 7. El ORO al llegar a Dios (guarda 5.000–12.000) está fuera en todas las corridas con perfil free (14.673 a 57.074).

## 4. Qué cumple ya la corrida 10 (A), contra el contrato de 45 h

| # | Contrato | 10A | Distancia |
|---|---|---|---|
| 1 | Dios 2.600–2.800 min | 763 min (12,71 h) | falta ×3,5: −1.837 min |
| 2 | 5 o 6 reenc. | 6 | cumple |
| 3 | 7 al tope antes del 80 % y no antes de la 5ª | 71 %, 5ª | cumple |
| 4 | 1ª reenc. 1–2 h | 0,55 h | −0,45 h (el amortiguador K 24 y el pasivo 0,05 la adelantan) |
| 5 | cada run un tier más lejos y antes | más lejos, 11 tiers no llegaron antes | no |
| 6 | pago ≥ 65 % | 52 % · 54 % (techo 65/55 %) | no |
| 7 | luxury 45–80 · island 270–410 · moon 710–930 · mars 1.230–1.500 · solar 1.840–2.110 · galaxy 2.250–2.520 | 30 · 181 · 261 · 420 · 526 · 640 | todos por debajo; urban (0,5) y corporate (8,6 ≤ 12) sí |
| 8 | sin reenc. no se llega a Dios | llega a Dios sin reencarnar a las 39,1 h activas (r12A) | no cumple: el contrato pide que no se llegue |
| 9 | ads ≥ 65 %, max ≥ 55 % de free | ads 89,7 %, max 92,8 % de 12,71 | cumplen con holgura (las guardas son de piso, no de techo) |
| — | ORO 5.000–12.000 | 16.736 | +4.736 |

## 5. Lectura: qué palancas llevan Dios de ~31 a ~45 h

Todas sobre la 10A (free, ×5, g 1,12 · r 1 · K 24); las corridas son `s01…s35`.

| Palanca | Variación | Dios (h) | Notas |
|---|---|---|---|
| g | 1,14 / 1,16 | 13,67 / 14,73 | palanca débil (+1 a +2 h) |
| K | 0 / 12 / 36 | 12,36 / 12,36 / 12,05 | no alarga; K 36 adelanta la 1ª reenc. a 0,33 h, K 0–12 la atrasa a 9 h de pared |
| paso por piso | 0,02 / 0,03 @luxury | 13,67 / 14,34 | +1 a +1,6 h; sin paso: 12,11 |
| reintegro r | 0,5 / 0 | 20,68 / 38,90 | **fuerte**, pero retrasa luxury (63 y 80 min) y empuja el arranque |
| pasivos en marcha | 0 | 16,72 | alarga +4 h; la 1ª reenc. pasa a 1,00 h (entra en 1–2 h) |
| bandas | `8:1.6,13:1.9,25:2.2` | 29,57 | **la palanca grande** |
| bandas | `8:1.8,13:2.2,25:2.6` | 65,54 | |
| bandas | `8:1.7,13:2.05,25:2.4` (s20) | 42,68 | |
| bandas sólo tardías | `13:1.9,25:2.6` / `8:1.45,13:2.0,25:2.6` | 19,67 / 34,67 | alargan menos por hora que tocar desde el 8 |
| s20 + paso 0,03 | | **45,97 · 7 reenc.** (s29) | dentro de 43,3–46,7 h |

**La combinación s29** (`--bands "8:1.7,13:2.05,25:2.4" --growth-step 0.03@luxury`, resto = 10A) da **Dios 45,97 h**, y con semillas 0,1 / 0,9: 47,00 / 46,00 (la semilla no mueve el contrato). Con ella: luxury 63 min (45–80 ✓), island 280 (270–410 ✓), moon 620 (710–930 ✗ −90), mars 980 (1.230–1.500 ✗ −250), solar 1.400 (1.840–2.110 ✗ −440), galaxy 1.980 (2.250–2.520 ✗ −270), Dios 2.758 min (✓). Las guardas: `.ads` 30,81 h = 67,0 % de free y `.max` 30,89 h = 67,2 % ✓ (≥ 65 / 55 %). Lo que **no** cumple: 7 reencarnaciones (5–6; la ley de arriba dice que el ORO a Dios, 43.075, es el culpable), 1ª reencarnación 0,67 h (1–2 h), sin reencarnar llega en 116 h (r12: contrato 8 ✗), pago 24–49 % (contrato 6 ✗, ver el techo), ORO 43.075 (guarda ✗).

Conclusiones para T13:

1. **El largo sale de las bandas (escalón de la escalada desde los tiers 8/13/25).** Pasar de (1,45 · 1,6 · 1,7) a (1,7 · 2,05 · 2,4) lleva Dios de 12,7 a 42,7 h sin tocar el arranque (urban/corporate no cambian; luxury sube de 30 a 63 min, dentro de 45–80). Es la preferencia de diseño del dueño: pisos finales más duros.
2. El **paso por piso (0,03@luxury)** y **g** suman unas pocas horas de ajuste fino; K no alarga Dios (sólo mueve el arranque); el reintegro r < 1 alarga mucho pero frena luxury, o sea el arranque.
3. El perfil `.free` (fuentes) es el −5 h que hay que compensar: la versión sin fuentes (renglón 8) ya estaba en 18,1 h.
4. Los pisos medios (moon, mars, solar, galaxy) quedan 90–440 min cortos con la forma s29: las bandas suben parejo y hace falta empujar el tramo 13–25 más que el 8 para que moon–galaxy suban sin mover Dios.
5. Siguen abiertos y no los cierra ningún knob de precio medido acá: 7 reenc., pago ≥ 65 %, contrato 8 y la guarda del ORO; los dos últimos son del lado del ORO (`--oro-divisor` / `--oro-exponent`), que no se barrió.
