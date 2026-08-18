# Sesión 2026-08-18 — El recorte deja de comerse lo blanco del personaje

## Qué se pidió

Los assets —«particularmente las skins»— tenían partes transparentes adentro del
dibujo: al sacarles el fondo se borraba **todo lo blanco**, así que cualquier
detalle blanco del personaje terminaba calado. Revisar skins, close-ups y el
resto, y volver a procesar con algo que **solamente saque el fondo**.

## La causa

`process_dropbox.py` recortaba con `rembg` (modelo `isnet-general-use`). `rembg`
es un modelo de **saliencia**: mira la imagen entera y decide "qué es el sujeto".
Con arte cartoon sobre fondo blanco, un guardapolvo blanco le parece fondo — y lo
borra. No es un umbral mal calibrado: es el criterio equivocado para este arte.

El caso testigo es `senior_doctor`: el guardapolvo entero quedó transparente y en
el juego se veía el fondo del tablero a través del médico.

## Lo que se midió (no estimado)

Dos medidas independientes sobre los 219 assets integrados:

1. **Contra el original** (`dropbox/procesadas/`, que está en git): qué porcentaje
   del dibujo que el original tiene opaco quedó transparente en el atlas.
2. **Sin el original**: qué porcentaje de la silueta del PNG integrado son huecos
   transparentes **encerrados** por el propio dibujo.

| grupo | total | rotos (≥2% comido) | sanos |
|---|---:|---:|---:|
| personajes | 41 | 13 | 28 |
| skins | 45 | 21 | 24 |
| close-ups (`*_face`) | 43 | 25 | 18 |
| specials | 10 | 4 | 6 |
| fx | 5 | 3 | 2 |
| UI | 73 | 36 | 37 |
| **total** | **217** | **102** | **115** |

Por la segunda medida, **73 de 219** tenían más del 5% de la silueta calada. Los
peores: `panel_dialog` 91%, `panel_config` 87%, `ui_speech_bubble` 85%,
`ui_toggle_off` 72%, `ser_ascendido_face` 67%. Los paneles habían quedado en
marco pelado, sin el pergamino de adentro.

## Lo que se construyó

### `scripts/whitebg_cutout.py` — recorte por conectividad

El criterio deja de ser semántico y pasa a ser **topológico**: *fondo es lo blanco
que se toca con el borde del lienzo*. Una camisa blanca está rodeada por la línea
negra del dibujo, no se conecta con el borde, y por lo tanto no se puede recortar.
No hay modelo ni umbral sobre "qué es un personaje": hay componentes conexas.

Tres detalles que importan:

- **Las semillas se toman solo de los píxeles de borde que además son blancos.**
  Los close-ups apoyan los hombros contra el marco; sembrar todo el borde los
  desangraba.
- **El filo lleva alpha fraccional por matting**: `alpha = d / d_del_color_pleno`,
  y el color de referencia sale del píxel **de adentro** más cercano. Definirlo
  por tono (un umbral de "ya es color pleno") deja opaco un filo que es 80%
  blanco, que es justo el halo claro que se quiere evitar.
- **Al semitransparente se le descuenta el blanco que trae mezclado**, así el
  sprite no queda con halo cuando se dibuja sobre el fondo del juego.

### La ambigüedad que no se puede resolver sola

Una isla blanca encerrada por el dibujo puede ser un guardapolvo o puede ser el
aire entre dos anillos. Medido sobre los 219 originales: de **1183 islas
encerradas**, la enorme mayoría es dibujo (camisas, ojos, papeles, el toldo del
mantero). El color no las distingue —un guardapolvo blanco puro mide igual que el
fondo—, así que el default es tratarlas como personaje y la excepción se declara
a mano en `HUECOS_CALADOS`: `fx_tap` y las tres copas. Se verificó mirando.

### Los dos que no tienen fondo blanco

`estanciero_estelar` y `senior_doctor__cirujano` volvieron de Gemini como escena
entera (campo estrellado, quirófano). Ahí el recorte por conectividad no aplica.
El recorte que ya estaba en el juego los separaba bien de su escena, así que a
esos dos se les respeta la silueta y solo se les **tapan los huecos de adentro**,
que es la parte del bug que sí los tocó.

## Lo que quedó afuera

- **`junior_programmer`**: no tiene original en `procesadas/`. Se verificó que su
  PNG está sano (0,01% de hueco), así que no hacía falta tocarlo.
- **`panel_menu`**: tiene 31% de la silueta calada, pero es de otra sesión (sin
  seguimiento en git, sin original y sin entrada en `prompts.json`). Se reporta,
  no se toca.

## Cómo se corre

```bash
cd Tools/asset-pipeline
.venv/bin/python scripts/recut_assets.py --dry-run   # listar
.venv/bin/python scripts/recut_assets.py             # rehacer los 218
.venv/bin/python -m unittest tests.test_whitebg_cutout tests.test_assets_integrados
```

`process_dropbox.py` ya usa el recorte nuevo, así que el arte que entre de acá en
adelante no vuelve a pasar por `rembg`. El pipeline ya no necesita `rembg` ni
`onnxruntime`: alcanza con PIL, numpy y scipy.

## Cómo quedó

- **218 assets rehechos** desde su original; los 219 integrados verificados.
- **0 assets con más del 1% de la silueta calada** fuera de los cuatro declarados
  en `HUECOS_CALADOS` (`fx_tap` 32%, las tres copas 6-8%, que es su hueco de
  diseño). Antes eran 73 con más del 5%.
- **0 assets transparentes enteros.**
- 8 pruebas nuevas en verde (6 del recorte + 2 de barrido sobre el atlas).
- Los atlas crecen de 49 MB a 56 MB en disco: hay más píxeles opacos que antes.
  Las dimensiones no cambian, así que el empaquetado y la memoria de textura en
  runtime quedan igual.

> Las dos pruebas de `test_gemini_selenium_runner` que fallan son de antes y no
> tienen que ver: al venv le faltan los paquetes `selenium` y `onnxruntime`
> (quedaron solo los `dist-info`). Las otras 43 de ese módulo pasan.
