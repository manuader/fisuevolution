# E2b T13 — la búsqueda del contrato de 45 h y la configuración candidata

Datos: `Docs/balance-run-v2-e2b-candidata.csv` (208 corridas, una fila por configuración; la elegida es `CANDIDATA`, columna `elegida`). Simulador: `Tools/pacing-sim`, `swift build -c release`, sin cambios. Base `42c5a9b9` (T12 adentro). Ningún dato del juego cambió: todo lo que la candidata mueve fuera de los flags del CLI vive en copias de `build/e2b/` (no versionado).

Contrato: `tasks.md` §7 «2026-10-12». Perfil `.free`, política ×5 (`--prestige-threshold 4`), 400 días, líneas a 348 desde el principio.

## Cómo se reproduce

Preparación (una vez, desde la raíz del worktree):

```
python3 -c "import json;d=json.load(open('FisuEvolution/Resources/Config/upgrades.json'))
for u in d['upgrades']: u['baseCost']=2
json.dump(d,open('build/e2b/upgrades-348.json','w'),indent=2)"
cp -R FisuEvolution/Resources/Config build/e2b/cfg_u7
python3 -c "import json;p='build/e2b/cfg_u7/treasures.json';t=json.load(open(p));t['spawnIntervalSeconds']=720
[x.update(weight=5) for x in t['prizes'] if x['id']=='oro'];json.dump(t,open(p,'w'),indent=1)"
```

La candidata (`R=FisuEvolution/Resources`, `P=Tools/pacing-sim/.build/release/pacing-sim`):

```
$P --economy $R/Data/economy.json --tiers $R/Data/tiers.json --upgrades build/e2b/upgrades-348.json \
   --sources build/e2b/cfg_u7 --merge-refund 1 --price-relief 12 --staffed 0.05 --prestige-threshold 4 \
   --inherit --capacity 15 --wall --prestige-discount --profile free --growth 1.11 \
   --bands 8:1.7,13:2.0,17:2.2,21:1.9,25:1.6,29:1.3,33:1.0 --growth-step 0.03@luxury \
   --oro-divisor 8e11 --max-days 400
```

- Punto 8: lo mismo con `--no-reincarnation`. Punto 9: lo mismo con `--profile ads` y `--profile max`.
- Semillas: agregar `--seed-fraction 0.1` y `0.9` (y repetir 8 y 9 con cada una).
- Cualquier otra fila: el prefijo `--economy … --tiers … --upgrades build/e2b/upgrades-348.json --sources $R/Config` + la columna `flags_completos` (las filas con `--economy build/e2b/economy-mX.json` son `economy.json` con `oro.globalMultiplierPerOro = X`; las `--sources build/e2b/cfg_*` son copias de `Config/` con lo que dice la sección «La guarda de perfiles»).
- El CLI imprime el contrato viejo (31–35 h): el semáforo de 45 h de este reporte sale de esas salidas con los rangos de §7; no se tocó `main.swift` (T14).

## 1. Las perillas finales (lo que T14 declara)

| Archivo | Clave | Hoy en el árbol | Candidata | Cómo se eligió |
|---|---|---|---|---|
| `Data/economy.json` | `oro.divisor` | 1e10 | **8e11** | atrasa la 1ª reencarnación a 1,33–1,67 h y deja el ORO a Dios en la guarda |
| `Data/economy.json` | `oro.exponent` | 0,25 | **0,25** (sin cambio) | bajarlo sólo alarga Dios; el ORO por reencarnación lo fija la política (1·4·20·100·500) |
| `Data/economy.json` | `oro.globalMultiplierPerOro` | 0,18 | **0,18** (sin cambio) | 0,22–0,25 comprime el final, pero con divisor 8e11 no hace falta |
| `Data/economy.json` | `hire.escalationBands` | ausente | **`[{"fromTier":8,"factor":1.7},{"fromTier":13,"factor":2.0},{"fromTier":17,"factor":2.2},{"fromTier":21,"factor":1.9},{"fromTier":25,"factor":1.6},{"fromTier":29,"factor":1.3},{"fromTier":33,"factor":1.0}]`** | el largo: pisos medios duros (13–24), final suave para que galaxy y Dios caigan juntos |
| `Data/economy.json` | `hire.costGrowthStepPerFloor` / `costGrowthStepFromFloorId` | ausente | **0,03 / `"luxury"`** | de T12 (s29) |
| `Data/economy.json` | `hire.defaultCostGrowth` (g) | 1,06 | **1,11** | el par del playtest, delegado; 1,12 pone la 1ª en 2,0 h y 1,10 baja moon |
| `Data/economy.json` | `hire.mergeRefundCounts` (r) | ausente | **1** | r < 1 frena luxury y el arranque; r 2 es el muro (descartado) |
| `Data/economy.json` | `hire.priceReliefPurchases` (K) | ausente | **12** | K 24 deja luxury en 36–41 min (< 45); K 12 lo lleva a 60 |
| `Data/economy.json` | `staffedFloorBonus` | ausente | **0,05** | sin cambio contra el punto de partida |
| `Data/economy.json` | `oro.inheritsPassiveUnlocks` · `oro.requiresLastRunWall` | ausente | **true · true** | decisiones del dueño / punto de partida |
| `Data/economy.json` | `floors[].capacity` | 10 | **15** | punto de partida |
| `Config/upgrades.json` | `upgrades[].baseCost` | 1 | **2** | las líneas a 348 (el árbol tiene 6 líneas de ORO: 313,8 ORO en continuo) |
| `Config/prestige_unlocks.json` | (se cobra el descuento) | — | **sí** (`--prestige-discount`) | sin cambio de valores |
| `Config/treasures.json` | `spawnIntervalSeconds` | 480 | **720** | la guarda `.ads` (sección 4) |
| `Config/treasures.json` | `prizes[id=oro].weight` | 15 | **5** | la guarda `.ads` (sección 4) |

Política del simulador (no es dato del juego): `.whenOroMultiplies(4)`, perfil `.free`.

## 2. El semáforo del contrato de 45 h

| # | Contrato (§7 «2026-10-12») | Candidata (semilla 0,5) | Semilla 0,1 | Semilla 0,9 |
|---|---|---|---|---|
| 1 | Dios 2.600–2.800 min | ✅ 2.724 | ✅ 2.724 | ✅ 2.720 |
| 2 | 5 o 6 reencarnaciones | ✅ 6 | ✅ 6 | ✅ 6 |
| 3 | líneas al tope < 80 % de Dios y no antes de la 5ª | ✅ 2.080 min (76 %), 5ª | ✅ 2.080 (76 %), 5ª | ✅ 2.080 (76 %), 5ª |
| 4 | 1ª reencarnación 1–2 h | ✅ 1,67 h | ✅ 1,67 h | ✅ 1,33 h |
| 5 | cada run más lejos **y** antes en lo ya visto | ❌ más lejos ✅, 11 tiers no llegan antes | ❌ más lejos ✅, 14 | ❌ más lejos ✅, 9 |
| 6 | reencarnar paga ≥ 65 % | ❌ 23 · 18 · 36 · 37 · 38 · 24 % | ❌ 23 · 2 · 42 · 48 · 38 · 24 % | ❌ 19 · 41 · 49 · 29 · 37 % |
| 7 | urban ≤ 1,5 · corp 6–12 · lux 45–80 · isla 270–410 · moon 710–930 · mars 1.230–1.500 · solar 1.840–2.110 · galaxy 2.250–2.520 · Dios 2.600–2.800 | ❌ sólo isla: 0,5 · 10,2 · 60 · **241** · 720 · 1.380 · 1.980 · 2.401 · 2.724 | ❌ sólo isla: 0,5 · 10,3 · 60 · **241** · 721 · 1.380 · 1.980 · 2.401 · 2.724 | ❌ isla y moon: 0,5 · 10,2 · 52 · **220** · **686** · 1.340 · 1.941 · 2.381 · 2.720 |
| 8 | sin reencarnar no se llega a Dios | ❌ llega a 6.510 min | ❌ 6.560 | ❌ 6.460 |
| 9 | `.ads` ≥ 65 % · `.max` ≥ 55 % de `.free` | ✅ 66,9 % · 65,5 % | ✅ 66,3 % · 66,2 % | ✅ 67,0 % · 63,4 % |
| G | ORO al llegar a Dios 5.000–12.000 | ✅ 5.996 | ✅ 5.979 | ✅ 7.781 |

**Lo que el dueño pidió explícitamente está verde en las tres semillas**: Dios 43,3–46,7 h, 6 reencarnaciones, 1ª 1–2 h, cada run más lejos, las líneas al tope en su ventana, las dos guardas de perfil (y la guarda del ORO). Quedan rojos el 5 en su mitad «antes», el 6, la isla del 7 y el 8 (sección 6).

La ley de diseño: R ≈ ln(ORO_dios/ORO₁)/ln 5 = ln 5.996 / ln 5 = 5,40 (semilla 0,9: 5,57) contra 6 medidas; ORO por reencarnación 1 · 4 · 20 · 102 · 541 · 3.066.

## 3. La serie de la pared y el techo (candidata)

| Run | 1 | 2 | 3 | 4 | 5 | 6 | 7 |
|---|---|---|---|---|---|---|---|
| fin de la run (h activas) | 1,7 | 6,1 | 15,3 | 26,3 | 34,7 | 41,3 | Dios 45,4 |
| tier máximo | T14 | T19 | T23 | T27 | T31 | T35 | T37 |
| pared | T11 | T15 | T15 | T18 | T22 | T24 | T28 |
| reencarnar paga (desde la run 2) | | 23 % | 18 % | 36 % | 37 % | 38 % | 24 % |
| techo | | 46 % | 61 % | 52 % | 47 % | 48 % | 40 % |

La pared corre +4 · 0 · +3 · +4 · +2 · +4 tiers. Cada run abre un piso nuevo (isla en la 2, moon en la 3, mars en la 4, solar en la 5, galaxy en la 6, Dios en la 7) y lo abre cerca de su final: por eso la forma de los pisos se mueve run por run y no tier por tier.

## 4. La guarda de perfiles: qué la movió

Con las fuentes reales la misma curva da `.ads` 61,2 % (semillas 60,3 / 60,9) y `.max` 61,0 %: el 9 falla. Lo que acelera a `.ads` es el **ORO de los premios** (el colchón da 2 ORO con peso 15, la ruleta 1 y 3): con ORO₁ = 1 y ~6.000 ORO a Dios, los ~200 ORO de videos pesan en las primeras runs. Medido sobre la curva c02/c03 (filas `d_*`, `c03_u*`):

| Cambio en una copia de `Config/` | `.ads` / `.free` |
|---|---|
| ninguno | 60,1 % |
| `rewarded_ads.json` adBreak 240 s · `wheel.json` 3 giros · cooldowns de la columna ×2 | 59–62 % (no mueven) |
| sin premios de ORO (ruleta y colchón) | 68,4 % |
| colchón cada 960 s | 65,5 % |
| colchón sin premio de ORO | 64,9 % |
| **colchón cada 720 s + ORO peso 5 (u7, la elegida)** | 66,3–68,0 % en las tres semillas |
| colchón cada 960 s + sin ORO (u3, la alternativa con más margen) | 66,1–68,4 % |

Se eligió u7 por ser el cambio más chico que deja margen en las tres semillas (≥ 66,3 %); el ratio tiene ~±2 puntos de ruido por la cuantización de las sesiones. La curva también mueve la guarda: `--staffed 0` la sube a 72,9 %, pero apaga los pisos en marcha (descartado).

## 5. El camino (lo que se probó y lo que se descartó)

1. **Línea de base** (`b00_base`, s29 de T12 con líneas a 348): 3/11 — Dios 2.880, 7 reenc, 1ª 0,67 h, ORO 43.991.
2. **El ORO primero** (`q_e*`, `q_e22_d*`, `g1_*`, `g4_*`): el ORO por reencarnación es siempre 1·4·20·100·500 (la política ×5); el exponente sólo alarga Dios. El divisor atrasa la 1ª reencarnación (cuantizada: 0,67 → 1,00 → 1,33 → 1,67 → 2,00 h). `g4_e0.25_d1e12` dejó por primera vez Dios 2.700 · 6 reenc · 1ª 1,33 · ORO 8.736 (`c01`, 6/11).
3. **La forma de los pisos** (`f*`, `l*`): todos los pisos llegaban temprano y Dios tarde. Bandas por tramo: duras en 13–24, suaves desde 25 (`29:1.3`, `33:1.0`). El tramo galaxy→Dios queda en ~320–460 min casi sin importar la banda 33. K 12 lleva luxury de 36–41 a 58–60.
4. **El multiplicador del ORO** (`m_*`, `k*`, `c03`–`c07`): 0,25 comprime el final (Dios −217, galaxy −180, moon −20). Con divisor 1e12 hacía falta; con 8e11 no (`c10_m18_*`, `CANDIDATA`).
5. **La guarda** (sección 4).

Descartados, con su número: (1,12 · 2) (muro, T12); exponente < 0,25 (Dios 3.286–5.340); `--staffed 0` (apaga una mecánica); adBreak/giros/columna como palanca de la guarda (no mueven); r 0,75–0,9 (Dios 3.202–4.481); bandas tardías altas para el punto 8 (ver abajo).

## 6. Los puntos para el dueño

1. **Punto 6 — reencarnar paga ≥ 65 %: inalcanzable con estas perillas.** Mejor valor: la candidata paga 18–38 %; en las 208 corridas, la mejor paga mínima por corrida es 34 % y el mejor techo mínimo 54 % (la mejor run suelta llega a 66 %). Confirma el techo de T12 (≤ 55–65 %). Pregunta: relajar el 6 o pedir otra palanca (que la reencarnación regale más que ORO).
2. **Punto 8 — sin reencarnar no se llega a Dios: inalcanzable con precios.** La candidata sin reencarnar llega a Dios en 6.510 min activos (semillas 6.560 / 6.460); las 62 corridas `.never` llegan todas, entre 5.576 y 11.638 min (la de 11.638 es la de paquetes cada 240 s, que además alarga Dios a 3.541). Ni con `33:5.0` ni con `35:10` (filas `p8_*`): 6.640–6.808 min. En 400 días de reloj el offline alcanza aunque los precios suban. Pregunta: relajar el 8 (p. ej. «no antes de 2,4× el tiempo de Dios»: hoy 6.510/2.724 = 2,39×) o acortar el horizonte.
3. **Punto 7, la isla (270–410) choca con el punto 4 (1ª reencarnación ≤ 2 h).** En las 81 corridas con Dios en 2.600–2.800 ninguna tiene isla ≥ 270: la mejor es 260 y sólo con la 1ª en 1,90–2,00 h; con la isla en 281–300 la 1ª pasa a 2,10–2,33 h. La isla llega en la run 2 y la empuja el fin de la run 1. Candidata: isla 241 (semilla 0,9: 220, y moon 686 contra 710). Pregunta: bajar el piso de la isla a ~220–240 o dejar la 1ª reencarnación en 2–2,5 h.
4. **Punto 5, la mitad «antes»**: cada run llega más lejos en las 208 corridas, pero siempre hay 5–22 tiers que una run alcanza más tarde que la anterior (candidata: 11; semillas 14 y 9). El CLI no imprime cuáles; T14 puede sumar el detalle a la salida.
5. **La guarda `.ads` se paga con el colchón**: `treasures.json` cada 720 s (no 480) y el premio de ORO con peso 5 (no 15). Sin eso la curva de 45 h deja `.ads` en 60–61 %. Es contenido de E5a (dudas 4–5): el dueño debería verlo.
6. **Las líneas son 6, no 7**: `upgrades.json` del árbol tiene seis líneas de ORO; con `baseCost` 2 suman 313,8 en continuo, no 348. El punto 3 se midió con esas seis.
