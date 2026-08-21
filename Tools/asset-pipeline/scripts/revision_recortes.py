#!/usr/bin/env python3
"""Arma la pagina para revisar a ojo TODAS las skins integradas, con las dos
versiones del recorte lado a lado.

Cada asset del juego se puede recortar de dos maneras y ninguna gana siempre: la
conectividad (`whitebg_cutout`) conserva el blanco encerrado por el dibujo —una
camisa, pero tambien la sombra del piso— y la saliencia (`rembg`) se lo come —la
sombra, pero tambien la camisa—. La pagina genera las dos para cada skin y deja
alternar con una tecla, que es la unica forma de elegir: mirando.

Cual de las dos esta hoy en el juego NO se deduce de la regla del pipeline, se
mide: hay skins de diamante que la regla da por saliencia y que en realidad
entraron por conectividad al regenerarse el arte despues. Se compara el alfa del
atlas contra las dos versiones y gana la que matchea.

    .venv/bin/python scripts/revision_recortes.py
    .venv/bin/python scripts/revision_recortes.py --salida ~/Desktop/skins-review

Las versiones de rembg que falten se guardan tambien en `state/rembg/`, que es de
donde `elegir_recorte.py` las toma para pasarlas al juego.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))

from process_dropbox import PIPELINE, RESOURCES, export_size  # noqa: E402
from whitebg_cutout import cutout  # noqa: E402

ORIGINALES = PIPELINE / "dropbox" / "procesadas"
REMBG = PIPELINE / "state" / "rembg"
DATOS = RESOURCES / "Data" / "tiers.json"
TEXTOS = RESOURCES / "Localizable.xcstrings"
ATLASES = ("earth.atlas", "cosmic.atlas")

# `homeless` es El Fisura: su original nunca paso por el dropbox, es la referencia
# de estilo aprobada a mano con la que se genero todo lo demas.
ORIGINALES_APARTE = {"homeless": PIPELINE / "heroes" / "approved" / "fisura.png"}

# Debajo de esto las dos herramientas dan lo mismo y el asset no necesita ojo.
DIFERENCIA_VISIBLE = 1.0


def asset_key(sprite: str) -> str:
    """`administrativo_idle__oro` → `administrativo__oro`."""
    if "_idle__" in sprite:
        return sprite.replace("_idle__", "__", 1)
    return sprite[: -len("_idle")] if sprite.endswith("_idle") else sprite


def variante(key: str) -> str:
    if key.endswith("__oro"):
        return "oro"
    if key.endswith("__diamante"):
        return "diamante"
    return "unica" if "__" in key else "base"


def nombres_de_personaje() -> dict[str, str]:
    return {t["id"]: t["displayName"] for t in json.loads(DATOS.read_text())["types"]}


def nombres_de_skin() -> dict[str, str]:
    textos = json.loads(TEXTOS.read_text())["strings"]
    nombres = {}
    for clave, valor in textos.items():
        if not clave.startswith("skin.name."):
            continue
        unidad = valor.get("localizations", {}).get("es", {}).get("stringUnit", {})
        if unidad.get("value"):
            nombres[clave[len("skin.name."):]] = unidad["value"]
    return nombres


def mascara(imagen: Image.Image) -> np.ndarray:
    return np.array(imagen.convert("RGBA"))[..., 3] > 8


def iou(a: np.ndarray, b: np.ndarray) -> float:
    return float((a & b).sum()) / max(int((a | b).sum()), 1) * 100


def original_de(key: str) -> Path:
    return ORIGINALES_APARTE.get(key, ORIGINALES / f"{key}.png")


def por_saliencia(sesion, imagen: Image.Image) -> Image.Image:
    from rembg import remove

    return remove(imagen, session=sesion)


def sprites_integrados() -> list[tuple[str, str]]:
    """(atlas, sprite) de cada idle que hoy esta en el juego."""
    encontrados = []
    for atlas in ATLASES:
        for png in sorted((RESOURCES / atlas).glob("*_idle*@3x.png")):
            encontrados.append((atlas, png.name[: -len("@3x.png")]))
    return encontrados


PLANTILLA = """<meta charset="utf-8">
<title>Revisión de skins — qué recorte queda en el juego</title>
<style>
  :root {
    --papel: #e9e3d7; --tinta: #23201b; --suave: #6f6858;
    --linea: #cdc4b2; --panel: #f3efe6; --rojo: #a02622; --verde: #2e6b46;
  }
  * { box-sizing: border-box; }
  body { margin: 0; font: 15px/1.45 -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
         background: var(--papel); color: var(--tinta); }
  #marco { display: grid; grid-template-columns: 1fr 320px; grid-template-rows: auto 1fr;
           height: 100vh; }
  header { grid-column: 1 / -1; display: flex; align-items: center; gap: 14px; padding: 10px 16px;
           background: var(--panel); border-bottom: 1px solid var(--linea); }
  h1 { font-size: 17px; margin: 0; }
  #cuenta { color: var(--suave); }
  #tablero { display: flex; gap: 12px; font-size: 13px; }
  #tablero b { font-weight: 600; }
  .crece { flex: 1; }
  select, button { font: inherit; padding: 6px 12px; border: 1px solid var(--linea);
                   border-radius: 8px; background: #fff; color: inherit; cursor: pointer; }
  button:hover { border-color: var(--suave); }
  #recorte { display: flex; border: 1px solid var(--linea); border-radius: 8px; overflow: hidden;
             background: #fff; }
  #recorte button { border: 0; border-radius: 0; padding: 6px 14px; }
  #recorte button + button { border-left: 1px solid var(--linea); }
  #recorte button[aria-pressed="true"] { background: var(--tinta); color: #fff; }
  #recorte button:disabled { opacity: .35; cursor: not-allowed; }
  main { display: flex; flex-direction: column; align-items: center; justify-content: center;
         gap: 12px; padding: 16px; overflow: auto; }
  #lienzo { width: 500px; height: 500px; max-width: 58vw; max-height: 56vh; display: grid;
            place-items: center; border-radius: 14px; border: 3px solid transparent; }
  #lienzo.damero { background-image:
      linear-gradient(45deg, #bdb6a8 25%, transparent 25%, transparent 75%, #bdb6a8 75%),
      linear-gradient(45deg, #bdb6a8 25%, transparent 25%, transparent 75%, #bdb6a8 75%);
      background-size: 28px 28px; background-position: 0 0, 14px 14px; background-color: #fff; }
  #lienzo.elegida { border-color: var(--verde); }
  #lienzo.regenerar { border-color: var(--rojo); }
  #lienzo img { max-width: 100%; max-height: 100%; }
  #nombre { font-size: 22px; font-weight: 700; }
  #etiquetas { display: flex; gap: 6px; flex-wrap: wrap; justify-content: center;
               align-items: center; color: var(--suave); font-size: 13px; }
  .chip { background: #fff; border: 1px solid var(--linea); border-radius: 999px; padding: 2px 10px; }
  .chip.buena { border-color: var(--verde); color: var(--verde); font-weight: 600; }
  .chip.aviso { border-color: var(--rojo); color: var(--rojo); }
  code { font: 13px/1 ui-monospace, SFMono-Regular, Menlo, monospace; color: var(--suave); }
  #controles { display: flex; gap: 10px; align-items: center; flex-wrap: wrap;
               justify-content: center; }
  #elegir { padding: 10px 22px; font-weight: 600; }
  #elegir.puesta { background: var(--verde); border-color: var(--verde); color: #fff; }
  #marcar.activa { background: var(--rojo); border-color: var(--rojo); color: #fff; }
  #ayuda { color: var(--suave); font-size: 13px; text-align: center; }
  #lista { border-left: 1px solid var(--linea); overflow-y: auto; background: var(--panel); }
  #lista div { display: flex; gap: 8px; align-items: center; padding: 7px 12px; cursor: pointer;
               border-bottom: 1px solid rgba(0,0,0,.04); font-size: 14px; }
  #lista div:hover { background: rgba(0,0,0,.04); }
  #lista div.actual { background: var(--tinta); color: #fff; }
  #lista .punto { width: 7px; height: 7px; border-radius: 50%; flex: none; background: transparent; }
  #lista div.decidida .punto { background: var(--verde); }
  #lista div.pendiente .punto { background: var(--rojo); }
  #lista .quien { flex: 1; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  #lista .cual { font-size: 12px; opacity: .65; }
  dialog { border: 1px solid var(--linea); border-radius: 14px; padding: 22px; max-width: 700px;
           background: var(--panel); color: inherit; }
  dialog::backdrop { background: rgba(0,0,0,.45); }
  dialog h2 { margin: 0 0 4px; font-size: 18px; }
  dialog h3 { margin: 18px 0 6px; font-size: 14px; }
  #resumen { color: var(--suave); font-size: 13px; margin: 0; }
  textarea { width: 100%; height: 150px; font: 13px/1.5 ui-monospace, Menlo, monospace;
             padding: 10px; border: 1px solid var(--linea); border-radius: 10px; resize: vertical;
             background: #fff; color: inherit; }
  pre { background: #fff; border: 1px solid var(--linea); border-radius: 10px; padding: 10px;
        font: 12px/1.5 ui-monospace, Menlo, monospace; overflow-x: auto; margin: 0; }
  .pie { display: flex; gap: 10px; margin-top: 16px; align-items: center; }
  #bajar { background: var(--verde); border-color: var(--verde); color: #fff; font-weight: 600; }
  .nota { color: var(--suave); font-size: 13px; margin: 8px 0 0; }

  @media (max-width: 900px) {
    #marco { grid-template-columns: 1fr; grid-template-rows: auto 1fr auto; }
    header { flex-wrap: wrap; }
    header .crece { flex-basis: 100%; height: 0; }
    #lista { border-left: 0; border-top: 1px solid var(--linea); max-height: 30vh; }
    #lienzo { width: 92vw; height: 92vw; max-width: none; max-height: 38vh; }
    #etiquetas { padding: 0 10px; }
  }
</style>

<div id="marco">
  <header>
    <h1>Revisión de skins</h1>
    <span id="cuenta"></span>
    <span id="tablero"></span>
    <span class="crece"></span>
    <div id="recorte">
      <button data-recorte="conectividad">Conectividad</button>
      <button data-recorte="rembg">rembg</button>
    </div>
    <select id="filtro">
      <option value="pendientes">Sin decidir</option>
      <option value="todas">Todas</option>
      <option value="difieren">Donde el recorte cambia algo</option>
      <option value="decididas">Ya decididas</option>
      <option value="regenerar">A regenerar</option>
      <option value="base">Sólo base</option>
      <option value="oro">Sólo oro</option>
      <option value="diamante">Sólo diamante</option>
      <option value="unica">Sólo skins propias</option>
    </select>
    <select id="fondo">
      <option value="damero">Damero</option>
      <option value="#2e7d4f">Verde</option>
      <option value="#1a1a1e">Negro</option>
      <option value="#ffffff">Blanco</option>
      <option value="#c9a227">Dorado</option>
    </select>
    <button id="cerrar-revision">Cerrar revisión</button>
  </header>

  <main>
    <div id="lienzo" class="damero"><img id="arte" alt=""></div>
    <div id="nombre"></div>
    <div id="etiquetas"></div>
    <div id="controles">
      <button id="antes">← Anterior</button>
      <button id="elegir"></button>
      <button id="marcar"></button>
      <button id="despues">Siguiente →</button>
    </div>
    <div id="ayuda">← → moverte · T cambiar el recorte · Enter dejar la que estás viendo ·
      R marcar para regenerar</div>
  </main>

  <div id="lista"></div>
</div>

<dialog id="salida">
  <h2>Cierre de la revisión</h2>
  <p id="resumen"></p>

  <h3>1 · Sacá tus decisiones de acá</h3>
  <div class="pie" style="margin:0 0 8px">
    <button id="bajar">Bajar decisiones.json</button>
    <button id="copiar-json">Copiar el JSON</button>
  </div>
  <textarea id="json" readonly style="height:110px"></textarea>
  <p class="nota">Con el botón de copiar no hace falta descargar nada. Las decisiones se
    guardan solas en este navegador: podés cerrar y seguir después.</p>

  <h3>2 · Aplicalas al juego</h3>
  <pre id="comando"></pre>
  <p class="nota">Deja en el atlas el recorte que elegiste y anota la elección en el pipeline,
    para que una corrida futura de <code>recut_assets.py</code> no te la pise.</p>

  <h3>3 · Las que hay que regenerar (<span id="cuantas">0</span>)</h3>
  <textarea id="texto" readonly></textarea>

  <div class="pie">
    <button id="copiar">Copiar la lista</button>
    <button id="borrar">Empezar de cero</button>
    <span class="crece"></span>
    <button id="cerrar">Volver</button>
  </div>
</dialog>

<script>
const SKINS = __DATOS__;
const NOMBRE_VARIANTE = { base: "Base", oro: "Oro", diamante: "Diamante", unica: "Skin propia" };
const NOMBRE_RECORTE = { conectividad: "conectividad", rembg: "rembg", juego: "la que está en el juego" };
const PY = "Tools/asset-pipeline/.venv/bin/python Tools/asset-pipeline/scripts/aplicar_revision.py";
const COMANDO = `# si copiaste el JSON:\\npbpaste | ${PY} -\\n\\n` +
  `# si bajaste el archivo:\\n${PY} ~/Downloads/decisiones.json\\n\\n` +
  `# para ver qué haría sin tocar nada, agregale  --dry-run`;

const leer = (clave, porDefecto) => {
  try { return JSON.parse(localStorage.getItem(clave)) ?? porDefecto; } catch { return porDefecto; }
};
const escribir = (clave, valor) => { try { localStorage.setItem(clave, JSON.stringify(valor)); } catch {} };

const elecciones = new Map(Object.entries(leer("skins-eleccion-recorte", {})));
const marcadas = new Set(leer("skins-a-regenerar", []));
const guardar = () => {
  escribir("skins-eleccion-recorte", Object.fromEntries(elecciones));
  escribir("skins-a-regenerar", [...marcadas]);
};

let recorte = "conectividad";
let visibles = SKINS.slice();
let i = 0;

const $ = (id) => document.getElementById(id);
const actual = () => visibles[i];
const rutaDe = (skin, cual) => `img/${skin.tiene.includes(cual) ? cual : skin.tiene[0]}/${skin.key}.png`;
const comparable = (skin) => skin.tiene.length > 1;

function filtrar() {
  const cual = $("filtro").value;
  const anterior = actual()?.key;
  visibles = SKINS.filter((s) =>
    cual === "todas" ? true :
    cual === "pendientes" ? !elecciones.has(s.key) && !marcadas.has(s.key) :
    cual === "decididas" ? elecciones.has(s.key) :
    cual === "regenerar" ? marcadas.has(s.key) :
    cual === "difieren" ? s.dif >= 1 : s.variante === cual);
  if (!visibles.length) { visibles = SKINS.slice(); $("filtro").value = "todas"; }
  i = Math.max(0, visibles.findIndex((s) => s.key === anterior));
  construirLista();
  pintar();
}

function construirLista() {
  $("lista").innerHTML = "";
  visibles.forEach((s, n) => {
    const fila = document.createElement("div");
    fila.innerHTML = `<span class="punto"></span>
      <span class="quien">${s.personaje}</span>
      <span class="cual">${s.skin || NOMBRE_VARIANTE[s.variante]}</span>`;
    fila.onclick = () => { i = n; pintar(); };
    $("lista").append(fila);
  });
}

function precargar() {
  const s = actual();
  if (!s) return;
  const urls = [rutaDe(s, recorte === "rembg" ? "conectividad" : "rembg")];
  for (const paso of [1, -1]) {
    const vecina = visibles[i + paso];
    if (vecina) urls.push(rutaDe(vecina, recorte));
  }
  urls.forEach((url) => { new Image().src = url; });
}

function pintar() {
  const s = actual();
  if (!s) return;
  const elegida = elecciones.get(s.key);
  const regenerar = marcadas.has(s.key);
  const disponible = s.tiene.includes(recorte);

  $("arte").src = rutaDe(s, recorte);
  $("lienzo").className = ($("fondo").value === "damero" ? "damero " : "") +
    (regenerar ? "regenerar" : elegida ? "elegida" : "");
  $("lienzo").style.background = $("fondo").value === "damero" ? "" : $("fondo").value;
  $("nombre").textContent = s.personaje;
  $("cuenta").textContent = `${i + 1} / ${visibles.length}`;

  const pendientes = SKINS.length - elecciones.size - marcadas.size;
  $("tablero").innerHTML =
    `<span style="color:var(--verde)">elegidas <b>${elecciones.size}</b></span>` +
    `<span style="color:var(--rojo)">a regenerar <b>${marcadas.size}</b></span>` +
    `<span>sin decidir <b>${pendientes}</b></span>`;

  const chips = [`<span class="chip">${NOMBRE_VARIANTE[s.variante]}</span>`];
  if (s.skin) chips.push(`<span class="chip">${s.skin}</span>`);
  if (regenerar) {
    chips.push(`<span class="chip aviso">las dos están mal — a regenerar</span>`);
  } else if (elegida) {
    chips.push(`<span class="chip buena">va al juego la de ${NOMBRE_RECORTE[elegida]}</span>`);
  } else {
    chips.push(`<span class="chip">sin decidir · hoy está la de ${NOMBRE_RECORTE[s.vivo]}</span>`);
  }
  if (!disponible) {
    chips.push(`<span class="chip aviso">${s.tiene[0] === "juego"
      ? "no está el original: sólo se puede mirar la que está en el juego"
      : `no hay versión de ${recorte}, se muestra la de ${NOMBRE_RECORTE[s.tiene[0]]}`}</span>`);
  }
  chips.push(!comparable(s)
    ? `<span class="chip">no hay con qué comparar</span>`
    : s.dif >= 1
      ? `<span class="chip">el recorte cambia ${s.dif}% de la silueta</span>`
      : `<span class="chip">las dos dan lo mismo</span>`);
  chips.push(`<code>${s.key}</code>`);
  $("etiquetas").innerHTML = chips.join("");

  const yaEsta = elegida === recorte;
  $("elegir").textContent = !disponible ? "No se puede elegir ésta"
    : yaEsta ? `✓ Queda la de ${NOMBRE_RECORTE[recorte]}`
    : `Que quede la de ${NOMBRE_RECORTE[recorte]}`;
  $("elegir").className = yaEsta ? "puesta" : "";
  $("elegir").disabled = !disponible;
  $("marcar").textContent = regenerar ? "✓ A regenerar — sacar" : "Las dos están mal";
  $("marcar").className = regenerar ? "activa" : "";

  document.querySelectorAll("#recorte button").forEach((b) => {
    b.setAttribute("aria-pressed", String(b.dataset.recorte === recorte));
    b.disabled = !s.tiene.includes(b.dataset.recorte);
  });
  [...$("lista").children].forEach((fila, n) => {
    fila.classList.toggle("actual", n === i);
    fila.classList.toggle("decidida", elecciones.has(visibles[n].key));
    fila.classList.toggle("pendiente", marcadas.has(visibles[n].key));
  });
  precargar();
}

const mover = (paso) => { i = (i + paso + visibles.length) % visibles.length; pintar(); };

function elegirActual() {
  const s = actual();
  if (!s || !s.tiene.includes(recorte)) return;
  if (elecciones.get(s.key) === recorte) elecciones.delete(s.key);
  else { elecciones.set(s.key, recorte); marcadas.delete(s.key); }
  guardar();
  pintar();
}

function marcarActual() {
  const s = actual();
  if (!s) return;
  if (marcadas.has(s.key)) marcadas.delete(s.key);
  else { marcadas.add(s.key); elecciones.delete(s.key); }
  guardar();
  pintar();
}

function alternarRecorte() {
  const s = actual();
  const otro = recorte === "rembg" ? "conectividad" : "rembg";
  if (s?.tiene.includes(otro)) { recorte = otro; pintar(); }
}

function avisar(boton, dice, vuelveA, cuanto = 1800) {
  $(boton).textContent = dice;
  setTimeout(() => ($(boton).textContent = vuelveA), cuanto);
}

const decisiones = () => ({
  elecciones: Object.fromEntries(elecciones),
  regenerar: [...marcadas],
});

$("antes").onclick = () => mover(-1);
$("despues").onclick = () => mover(1);
$("elegir").onclick = elegirActual;
$("marcar").onclick = marcarActual;
$("filtro").onchange = filtrar;
$("fondo").onchange = pintar;
document.querySelectorAll("#recorte button").forEach((b) => {
  b.onclick = () => { recorte = b.dataset.recorte; pintar(); };
});

$("cerrar-revision").onclick = () => {
  const pendientes = SKINS.length - elecciones.size - marcadas.size;
  $("resumen").textContent = `${elecciones.size} elegidas · ${marcadas.size} a regenerar · ` +
    `${pendientes} sin decidir` + (pendientes ? " (las sin decidir quedan como están)" : "");
  $("cuantas").textContent = marcadas.size;
  $("comando").textContent = COMANDO;
  $("json").value = JSON.stringify(decisiones(), null, 2);
  $("texto").value = SKINS.filter((s) => marcadas.has(s.key))
    .map((s) => `${s.key}  (${s.personaje} — ${s.skin || NOMBRE_VARIANTE[s.variante]})`)
    .join("\\n");
  $("salida").showModal();
};
$("bajar").onclick = () => {
  // El <a> va al documento y la URL se revoca MUCHO despues del click: revocarla
  // en la linea siguiente mata el blob antes de que la descarga lo lea, y un <a>
  // suelto no dispara nada en varios navegadores. Las dos cosas fallan calladas.
  try {
    const blob = new Blob([JSON.stringify(decisiones(), null, 2)], { type: "application/json" });
    const url = URL.createObjectURL(blob);
    const enlace = document.createElement("a");
    enlace.href = url;
    enlace.download = "decisiones.json";
    document.body.append(enlace);
    enlace.click();
    enlace.remove();
    setTimeout(() => URL.revokeObjectURL(url), 30000);
    avisar("bajar", "Fijate en Descargas", "Bajar decisiones.json");
  } catch (error) {
    avisar("bajar", "No se pudo — copiá el JSON", "Bajar decisiones.json", 4000);
  }
};
$("copiar-json").onclick = async () => {
  const texto = JSON.stringify(decisiones(), null, 2);
  $("json").select();
  try {
    await navigator.clipboard.writeText(texto);
    avisar("copiar-json", "✓ Copiado", "Copiar el JSON");
  } catch {
    avisar("copiar-json", "Copialo a mano del cuadro", "Copiar el JSON", 4000);
  }
};
$("copiar").onclick = async () => {
  $("texto").select();
  try {
    await navigator.clipboard.writeText($("texto").value);
    avisar("copiar", "✓ Copiada", "Copiar la lista");
  } catch {
    avisar("copiar", "Copiala a mano del cuadro", "Copiar la lista", 4000);
  }
};
$("borrar").onclick = () => {
  if (!confirm("¿Borrar TODAS las decisiones y empezar de cero?")) return;
  elecciones.clear();
  marcadas.clear();
  guardar();
  $("salida").close();
  filtrar();
};
$("cerrar").onclick = () => $("salida").close();

addEventListener("keydown", (e) => {
  if ($("salida").open) return;
  if (e.key === "ArrowLeft") mover(-1);
  else if (e.key === "ArrowRight") mover(1);
  else if (e.key === "Enter") { e.preventDefault(); elegirActual(); }
  else if (e.key === "r" || e.key === "R") marcarActual();
  else if (e.key === "t" || e.key === "T") alternarRecorte();
});

filtrar();
</script>
"""


def pagina(fichas: list[dict]) -> str:
    return PLANTILLA.replace("__DATOS__", json.dumps(fichas, ensure_ascii=False))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--salida", type=Path, default=Path.home() / "Desktop" / "skins-review")
    parser.add_argument("--limite", type=int, default=0, help="cortar a N skins (para probar)")
    args = parser.parse_args()

    personajes, skins = nombres_de_personaje(), nombres_de_skin()
    destino = args.salida
    for sub in ("conectividad", "rembg"):
        (destino / "img" / sub).mkdir(parents=True, exist_ok=True)

    sesion = None
    fichas, sin_original, solo_una = [], [], []
    integrados = sprites_integrados()
    if args.limite:
        integrados = integrados[: args.limite]

    for numero, (atlas, sprite) in enumerate(integrados, 1):
        key = asset_key(sprite)
        vivo = Image.open(RESOURCES / atlas / f"{sprite}@3x.png")
        lado = vivo.size[0]
        versiones: dict[str, Image.Image] = {}
        nuevas: set[str] = set()

        # Reanudable: lo que ya esta recortado en la salida no se vuelve a hacer.
        for herramienta in ("conectividad", "rembg"):
            hecho = destino / "img" / herramienta / f"{key}.png"
            if hecho.exists():
                versiones[herramienta] = Image.open(hecho)

        guardado = REMBG / atlas / f"{sprite}@3x.png"
        if "rembg" not in versiones and guardado.exists():
            versiones["rembg"] = Image.open(guardado)
            nuevas.add("rembg")

        original = original_de(key)
        fuente = None
        if original.exists():
            if "conectividad" not in versiones:
                fuente = Image.open(original)
                versiones["conectividad"] = cutout(fuente, key).resize((lado, lado), Image.LANCZOS)
                nuevas.add("conectividad")
            if "rembg" not in versiones:
                if sesion is None:
                    from rembg import new_session

                    print("Cargando modelo rembg isnet-general-use...", flush=True)
                    sesion = new_session("isnet-general-use")
                fuente = fuente or Image.open(original)
                saliencia = por_saliencia(sesion, fuente)
                versiones["rembg"] = saliencia.resize((lado, lado), Image.LANCZOS)
                nuevas.add("rembg")
                a2x, a3x = export_size("skin", key)
                (REMBG / atlas).mkdir(parents=True, exist_ok=True)
                saliencia.resize((a3x, a3x), Image.LANCZOS).save(REMBG / atlas / f"{sprite}@3x.png")
                saliencia.resize((a2x, a2x), Image.LANCZOS).save(REMBG / atlas / f"{sprite}@2x.png")
        else:
            sin_original.append(key)

        # Sin original no hay nada que comparar, pero el asset SI esta en el juego:
        # entra igual con el PNG del atlas para poder mirarlo y marcarlo.
        if not versiones:
            versiones["juego"] = vivo
            nuevas.add("juego")
            (destino / "img" / "juego").mkdir(parents=True, exist_ok=True)
        if len(versiones) == 1:
            solo_una.append(key)

        for nombre in nuevas:
            versiones[nombre].save(destino / "img" / nombre / f"{key}.png", optimize=True)

        mascaras = {n: mascara(i) for n, i in versiones.items()}
        contra_vivo = {n: iou(mascara(vivo), m) for n, m in mascaras.items()}
        en_el_juego = max(contra_vivo, key=contra_vivo.get)
        if contra_vivo[en_el_juego] < 99.0:
            en_el_juego = "otro"

        diferencia = 0.0
        if {"conectividad", "rembg"} <= set(mascaras):
            diferencia = round(100 - iou(mascaras["conectividad"], mascaras["rembg"]), 1)

        base, _, skin = key.partition("__")
        fichas.append({
            "key": key,
            "personaje": personajes.get(base, base.replace("_", " ").title()),
            "variante": variante(key),
            "skin": skins.get(skin, ""),
            "atlas": atlas[: -len(".atlas")],
            "vivo": en_el_juego,
            "tiene": sorted(versiones),
            "dif": diferencia,
        })
        print(f"  [{numero:3}/{len(integrados)}] {key} → {en_el_juego} (dif {diferencia}%)", flush=True)

    fichas.sort(key=lambda f: (f["personaje"], f["variante"], f["key"]))
    (destino / "index.html").write_text(pagina(fichas), encoding="utf-8")

    visibles = sum(1 for f in fichas if f["dif"] >= DIFERENCIA_VISIBLE)
    print(f"\nskins en la pagina: {len(fichas)}")
    print(f"donde el recorte cambia algo (>{DIFERENCIA_VISIBLE}%): {visibles}")
    if solo_una:
        print(f"con una sola version ({len(solo_una)}): {', '.join(solo_una)}")
    if sin_original:
        print(f"sin original, no se pudo recortar de nuevo ({len(sin_original)}): {', '.join(sin_original)}")
    print(f"pagina: {destino / 'index.html'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
