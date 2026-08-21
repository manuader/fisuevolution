#!/usr/bin/env python3
"""Arma la pagina para decidir, isla por isla, que blanco encerrado se saca.

`whitebg_cutout` mide cada isla contra el fondo del lienzo y saca sola las que
son papel puro, pero deja una franja ambigua —ojos, chispas, dientes, un blanco
pintado muy claro— donde el color no alcanza y hace falta el ojo. Esta pagina
muestra esas islas encima del asset y las deja alternar con un clic.

    .venv/bin/python scripts/revision_islas.py senior_doctor cartonero__diamante
    .venv/bin/python scripts/revision_islas.py --todas-las-dudosas

La decision se baja como `islas.json` y la aplica `aplicar_islas.py`.

Cada isla se identifica por su etiqueta de `ndimage.label`, que para una misma
imagen es siempre la misma; el JSON guarda ademas el centro y el area, que es lo
que permite darse cuenta si el original cambio debajo.
"""

from __future__ import annotations

import argparse
import base64
import io
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, str(Path(__file__).resolve().parent))

import whitebg_cutout as W  # noqa: E402
from process_dropbox import PIPELINE  # noqa: E402
from revision_recortes import nombres_de_personaje, nombres_de_skin, original_de, variante  # noqa: E402

SALIDA = Path.home() / "Desktop" / "islas-review"


def islas_de(rgb: np.ndarray) -> tuple[np.ndarray, np.ndarray, list[dict]]:
    """(mascara de fondo, etiquetas del interior, fichas de cada isla)."""
    blanco = W.white_distance(rgb) <= W.WHITE_TOLERANCE
    etiquetas, _ = ndimage.label(blanco)
    borde = np.concatenate([etiquetas[0], etiquetas[-1], etiquetas[:, 0], etiquetas[:, -1]])
    fondo = np.isin(etiquetas, np.unique(borde[borde > 0]))

    interior = blanco & ~fondo
    dentro, cuantas = ndimage.label(interior)
    if not cuantas:
        return fondo, dentro, []

    referencia = rgb[fondo].astype(float).mean(axis=0)
    areas = ndimage.sum_labels(interior, dentro, index=np.arange(1, cuantas + 1))
    alto, ancho = rgb.shape[:2]
    fichas = []
    for indice, area in enumerate(areas):
        if area < W.MIN_HOLE_AREA:
            continue
        etiqueta = indice + 1
        isla = dentro == etiqueta
        nucleo = ndimage.binary_erosion(isla, iterations=2)
        if nucleo.sum() < 30:
            nucleo = isla
        distancia = float(np.abs(rgb[nucleo].astype(float).mean(axis=0) - referencia).mean())
        cy, cx = ndimage.center_of_mass(isla)
        fichas.append({
            "id": int(etiqueta),
            "area": int(area),
            "distancia": round(distancia, 2),
            "centro": [round(cx / ancho, 4), round(cy / alto, 4)],
            "saca": distancia < W.DISTANCIA_PAPEL,
            "dudosa": W.DISTANCIA_PAPEL <= distancia < 1.8,
        })
    fichas.sort(key=lambda f: -f["area"])
    return fondo, dentro, fichas


def mapa_de_islas(dentro: np.ndarray, fichas: list[dict]) -> Image.Image:
    """PNG donde cada isla lleva su id pintado en R y G: el clic lo lee de ahi."""
    alto, ancho = dentro.shape
    lienzo = np.zeros((alto, ancho, 4), dtype=np.uint8)
    for ficha in fichas:
        m = dentro == ficha["id"]
        lienzo[m] = [ficha["id"] % 256, ficha["id"] // 256, 180, 255]
    return Image.fromarray(lienzo)


def con_dudas(clave: str) -> bool:
    original = original_de(clave)
    if not original.exists():
        return False
    rgb = np.array(Image.open(original).convert("RGB"))
    _, _, fichas = islas_de(rgb)
    return any(f["dudosa"] for f in fichas)


PLANTILLA = """<meta charset="utf-8">
<title>Islas — qué blanco encerrado se saca</title>
<style>
  :root { --papel:#e9e3d7; --tinta:#23201b; --suave:#6f6858; --linea:#cdc4b2;
          --panel:#f3efe6; --rojo:#a02622; --amarillo:#c98a00; --verde:#2e6b46; }
  * { box-sizing:border-box; }
  body { margin:0; font:15px/1.45 -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
         background:var(--papel); color:var(--tinta); }
  #marco { display:grid; grid-template-columns:1fr 340px; grid-template-rows:auto 1fr; height:100vh; }
  header { grid-column:1/-1; display:flex; gap:14px; align-items:center; padding:10px 16px;
           background:var(--panel); border-bottom:1px solid var(--linea); }
  h1 { font-size:17px; margin:0; }
  .crece { flex:1; }
  select, button { font:inherit; padding:6px 12px; border:1px solid var(--linea);
                   border-radius:8px; background:#fff; color:inherit; cursor:pointer; }
  main { display:flex; flex-direction:column; align-items:center; justify-content:center;
         gap:10px; padding:16px; overflow:auto; }
  #escena { position:relative; width:700px; height:700px; max-width:62vw; max-height:70vh;
            border-radius:12px; overflow:hidden; cursor:crosshair;
            background-image:linear-gradient(45deg,#bdb6a8 25%,transparent 25%,transparent 75%,#bdb6a8 75%),
                             linear-gradient(45deg,#bdb6a8 25%,transparent 25%,transparent 75%,#bdb6a8 75%);
            background-size:28px 28px; background-position:0 0,14px 14px; background-color:#fff; }
  #escena.verde { background-image:none; background-color:#2e7d4f; }
  #arte, #capa { position:absolute; inset:0; width:100%; height:100%; }
  #capa { pointer-events:none; }
  #pie { color:var(--suave); font-size:13px; text-align:center; }
  .leyenda { display:flex; gap:14px; align-items:center; font-size:13px; }
  .cuadro { width:12px; height:12px; border-radius:3px; display:inline-block; vertical-align:-1px;
            margin-right:5px; }
  #lista { border-left:1px solid var(--linea); overflow-y:auto; background:var(--panel); }
  #lista .fila { display:flex; gap:8px; align-items:center; padding:8px 12px; cursor:pointer;
                 border-bottom:1px solid rgba(0,0,0,.05); font-size:13px; }
  #lista .fila:hover { background:rgba(0,0,0,.05); }
  #lista .fila.resaltada { background:var(--tinta); color:#fff; }
  #lista .marca { width:10px; height:10px; border-radius:3px; flex:none; }
  #lista .dato { flex:1; }
  #lista .dist { opacity:.6; font-size:12px; }
  #lista h3 { margin:0; padding:10px 12px 4px; font-size:12px; text-transform:uppercase;
              letter-spacing:.06em; color:var(--suave); }
  dialog { border:1px solid var(--linea); border-radius:14px; padding:22px; max-width:680px;
           background:var(--panel); }
  dialog::backdrop { background:rgba(0,0,0,.45); }
  textarea { width:100%; height:200px; font:12px/1.5 ui-monospace, Menlo, monospace; padding:10px;
             border:1px solid var(--linea); border-radius:10px; background:#fff; color:inherit; }
  pre { background:#fff; border:1px solid var(--linea); border-radius:10px; padding:10px;
        font:12px/1.5 ui-monospace, Menlo, monospace; overflow-x:auto; margin:0; }
  .nota { color:var(--suave); font-size:13px; }
  .pie2 { display:flex; gap:10px; margin-top:14px; }
</style>

<div id="marco">
  <header>
    <h1>Islas</h1>
    <select id="asset"></select>
    <span id="cuenta" class="nota"></span>
    <span class="crece"></span>
    <div class="leyenda">
      <span><i class="cuadro" style="background:#a02622"></i>se saca</span>
      <span><i class="cuadro" style="background:#c98a00"></i>sin decidir</span>
      <span><i class="cuadro" style="background:#2e6b46"></i>se conserva</span>
    </div>
    <button id="fondo">Fondo verde</button>
    <button id="cerrar-todo">Exportar</button>
  </header>

  <main>
    <div id="escena">
      <img id="arte" alt="">
      <canvas id="capa"></canvas>
    </div>
    <div id="pie">Clic en una isla para alternar entre sacarla y conservarla ·
      las que no están pintadas son personaje y se conservan</div>
  </main>

  <div id="lista"></div>
</div>

<dialog id="salida">
  <h2 style="margin:0 0 4px;font-size:18px">Decisiones por isla</h2>
  <p class="nota" id="resumen"></p>
  <textarea id="texto" readonly></textarea>
  <p class="nota">Copiá esto y pegámelo, o guardalo como <code>islas.json</code> y corré:</p>
  <pre>Tools/asset-pipeline/.venv/bin/python Tools/asset-pipeline/scripts/aplicar_islas.py islas.json</pre>
  <div class="pie2">
    <button id="copiar" style="background:var(--verde);border-color:var(--verde);color:#fff;font-weight:600">Copiar</button>
    <span class="crece"></span>
    <button id="volver">Volver</button>
  </div>
</dialog>

<script>
const ASSETS = __DATOS__;
const ALMACEN = "islas-decididas";
const leer = () => { try { return JSON.parse(localStorage.getItem(ALMACEN)) || {}; } catch { return {}; } };
const guardar = () => { try { localStorage.setItem(ALMACEN, JSON.stringify(estado)); } catch {} };

// estado[key][id] = "saca" | "conserva".  Lo que no esta acá usa el default medido.
const estado = leer();
let n = 0, mapa = null, ancho = 0, alto = 0, resaltada = null;

const $ = (id) => document.getElementById(id);

function avisarRoto(motivo) {
  const aviso = document.createElement("div");
  aviso.style.cssText = "position:fixed;inset:auto 16px 16px 16px;z-index:99;padding:12px 16px;" +
    "background:#a02622;color:#fff;border-radius:10px;font-size:14px";
  aviso.textContent = "⚠ " + motivo + " — los clics no van a funcionar.";
  document.body.append(aviso);
}
const actual = () => ASSETS[n];
const decision = (key, isla) => estado[key]?.[isla.id] ?? (isla.saca ? "saca" : "conserva");
const COLOR = { saca: [160, 38, 34], conserva: [46, 107, 70], duda: [201, 138, 0] };

// Una isla dudosa que nadie toco se pinta AMARILLA: es la pregunta abierta.
// Apenas se la decide —aunque sea confirmando lo que ya hacia— pasa a su color.
function comoSePinta(key, isla) {
  const tocada = estado[key]?.[isla.id];
  if (!tocada && isla.dudosa) return "duda";
  return decision(key, isla);
}

function fijar(key, id, valor) {
  (estado[key] ||= {})[id] = valor;
  guardar();
}

function cargarAsset() {
  const a = actual();
  $("asset").value = String(n);
  $("arte").src = `img/${a.key}.png`;
  const img = new Image();
  img.onerror = () => avisarRoto("No cargó el mapa de islas de " + a.key);
  img.onload = () => {
    ancho = img.naturalWidth; alto = img.naturalHeight;
    const off = document.createElement("canvas");
    off.width = ancho; off.height = alto;
    const octx = off.getContext("2d", { willReadFrequently: true });
    octx.drawImage(img, 0, 0);
    try {
      mapa = octx.getImageData(0, 0, ancho, alto);
    } catch (error) {
      avisarRoto("No puedo leer el mapa de islas: " + error.message);
      return;
    }
    $("capa").width = ancho; $("capa").height = alto;
    pintar();
  };
  img.src = a.mapa;
  construirLista();
}

function idEn(x, y) {
  if (!mapa) return 0;
  const i = (Math.floor(y) * ancho + Math.floor(x)) * 4;
  if (mapa.data[i + 3] === 0) return 0;
  return mapa.data[i] + mapa.data[i + 1] * 256;
}

function pintar() {
  if (!mapa) return;
  const a = actual();
  const porId = new Map(a.islas.map((i) => [i.id, comoSePinta(a.key, i)]));
  const salida = new ImageData(ancho, alto);
  const d = mapa.data, s = salida.data;
  for (let p = 0; p < d.length; p += 4) {
    if (d[p + 3] === 0) continue;
    const id = d[p] + d[p + 1] * 256;
    const cual = porId.get(id);
    if (!cual) continue;
    const c = COLOR[cual];
    const fuerte = id === resaltada;
    s[p] = c[0]; s[p + 1] = c[1]; s[p + 2] = c[2];
    s[p + 3] = cual === "conserva" ? (fuerte ? 150 : 55)
             : cual === "duda" ? (fuerte ? 235 : 190)
             : (fuerte ? 240 : 175);
  }
  $("capa").getContext("2d").putImageData(salida, 0, 0);

  const saca = a.islas.filter((i) => decision(a.key, i) === "saca").length;
  const dudando = a.islas.filter((i) => comoSePinta(a.key, i) === "duda").length;
  $("cuenta").textContent = `${a.islas.length} islas · se sacan ${saca}` +
    (dudando ? ` · ${dudando} en amarillo esperando` : " · ninguna en amarillo");
  [...$("lista").querySelectorAll(".fila")].forEach((f) => {
    const isla = a.islas.find((i) => i.id === Number(f.dataset.id));
    const pintura = comoSePinta(a.key, isla);
    f.querySelector(".marca").style.background =
      pintura === "saca" ? "var(--rojo)" : pintura === "duda" ? "var(--amarillo)" : "var(--verde)";
    f.classList.toggle("resaltada", isla.id === resaltada);
  });
}

function construirLista() {
  const a = actual();
  const dudosas = a.islas.filter((i) => i.dudosa);
  const resto = a.islas.filter((i) => !i.dudosa);
  $("lista").innerHTML = "";
  const grupo = (titulo, islas) => {
    if (!islas.length) return;
    const h = document.createElement("h3"); h.textContent = titulo; $("lista").append(h);
    for (const isla of islas) {
      const f = document.createElement("div");
      f.className = "fila"; f.dataset.id = isla.id;
      f.innerHTML = `<span class="marca"></span>
        <span class="dato">${isla.area.toLocaleString("es")} px</span>
        <span class="dist">distancia ${isla.distancia}</span>`;
      f.onmouseenter = () => { resaltada = isla.id; pintar(); };
      f.onmouseleave = () => { resaltada = null; pintar(); };
      f.onclick = () => {
        fijar(a.key, isla.id, decision(a.key, isla) === "saca" ? "conserva" : "saca");
        pintar();
      };
      $("lista").append(f);
    }
  };
  grupo(`Sin decidir — las mira el ojo (${dudosas.length})`, dudosas);
  grupo(`Las demás (${resto.length})`, resto);
}

$("escena").onclick = (e) => {
  const r = $("escena").getBoundingClientRect();
  const id = idEn((e.clientX - r.left) / r.width * ancho, (e.clientY - r.top) / r.height * alto);
  if (!id) return;
  const a = actual();
  const isla = a.islas.find((i) => i.id === id);
  if (!isla) return;
  fijar(a.key, id, decision(a.key, isla) === "saca" ? "conserva" : "saca");
  pintar();
};
$("escena").onmousemove = (e) => {
  const r = $("escena").getBoundingClientRect();
  const id = idEn((e.clientX - r.left) / r.width * ancho, (e.clientY - r.top) / r.height * alto);
  if (id !== resaltada) { resaltada = id || null; pintar(); }
};
$("asset").onchange = () => { n = Number($("asset").value); resaltada = null; cargarAsset(); };
$("fondo").onclick = () => {
  $("escena").classList.toggle("verde");
  $("fondo").textContent = $("escena").classList.contains("verde") ? "Fondo damero" : "Fondo verde";
};
$("cerrar-todo").onclick = () => {
  const salida = {};
  let total = 0;
  for (const a of ASSETS) {
    const sacar = a.islas.filter((i) => decision(a.key, i) === "saca").map((i) => i.id);
    if (sacar.length) { salida[a.key] = sacar; total += sacar.length; }
  }
  $("texto").value = JSON.stringify(salida, null, 2);
  $("resumen").textContent = `${total} islas se sacan, en ${Object.keys(salida).length} assets.`;
  $("salida").showModal();
};
$("copiar").onclick = async () => {
  $("texto").select();
  try { await navigator.clipboard.writeText($("texto").value); $("copiar").textContent = "✓ Copiado"; }
  catch { $("copiar").textContent = "Copialo a mano"; }
  setTimeout(() => ($("copiar").textContent = "Copiar"), 1600);
};
$("volver").onclick = () => $("salida").close();

$("asset").innerHTML = ASSETS.map((a, i) =>
  `<option value="${i}">${a.personaje}${a.skin ? " — " + a.skin : ""} (${a.islas.length} islas)</option>`).join("");
cargarAsset();
</script>
"""


def pagina(assets: list[dict]) -> str:
    return PLANTILLA.replace("__DATOS__", json.dumps(assets, ensure_ascii=False))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("claves", nargs="*", metavar="ASSETKEY")
    parser.add_argument("--salida", type=Path, default=SALIDA)
    args = parser.parse_args()
    if not args.claves:
        raise SystemExit("pasame al menos un assetKey")

    personajes, skins = nombres_de_personaje(), nombres_de_skin()
    destino = args.salida
    (destino / "img").mkdir(parents=True, exist_ok=True)

    assets = []
    for clave in args.claves:
        original = original_de(clave)
        if not original.exists():
            print(f"  ✗ {clave}: no está el original {original.name}")
            continue
        imagen = Image.open(original)
        rgb = np.array(imagen.convert("RGB"))
        fondo, dentro, fichas = islas_de(rgb)
        if not fichas:
            print(f"  · {clave}: sin islas encerradas, nada que decidir")
            continue

        # Con clave vacia el cutout no cae en ninguna lista y conserva TODAS las
        # islas: es el asset sin ninguna decision tomada, que es lo que hay que
        # mirar. Se llama al de verdad y no se replica su cuenta: replicarla ya
        # costo una pagina entera en blanco por un alfa sin multiplicar por 255.
        recorte = W.cutout(imagen, "")
        lado = 700
        recorte.resize((lado, lado), Image.LANCZOS).save(destino / "img" / f"{clave}.png", optimize=True)
        # El mapa va INCRUSTADO y no como archivo: abierta con doble clic la pagina
        # es `file://`, y ahi dibujar un archivo en un canvas lo contamina — el
        # `getImageData` que necesita el clic tira SecurityError. Un data: URI es
        # del mismo origen y no contamina.
        crudo = io.BytesIO()
        mapa_de_islas(dentro, fichas).resize((lado, lado), Image.NEAREST).save(crudo, format="PNG")
        mapa = "data:image/png;base64," + base64.b64encode(crudo.getvalue()).decode()

        base, _, skin = clave.partition("__")
        assets.append({
            "key": clave,
            "personaje": personajes.get(base, base.replace("_", " ").title()),
            "skin": skins.get(skin, ""),
            "variante": variante(clave),
            "mapa": mapa,
            "islas": fichas,
        })
        saca = sum(1 for f in fichas if f["saca"])
        duda = sum(1 for f in fichas if f["dudosa"])
        print(f"  ✓ {clave}: {len(fichas)} islas · saca {saca} · dudosas {duda}")

    if not assets:
        raise SystemExit("no quedo ningun asset con islas")
    (destino / "index.html").write_text(pagina(assets), encoding="utf-8")
    print(f"\npagina: {destino / 'index.html'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
