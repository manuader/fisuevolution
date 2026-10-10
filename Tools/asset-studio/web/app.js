"use strict";
// El Estudio de assets: la lista, el lienzo (paso 1: fondo, paso 2: islas) y el panel.
// El navegador no escribe ningun PNG: manda las marcas y el servidor rehace la imagen.

const $ = (id) => document.getElementById(id);
const ROJO = [214, 40, 40, 150], VERDE = [46, 160, 90, 110], PINCEL = [214, 40, 40, 150];
const AMARILLO = [255, 210, 0, 150];
const PISO = { cosmic: "#2b2550", default: "#7a6a55" };
const NOMBRES_METODO = { original: "Original", conectividad: "Conectividad", rembg: "rembg", juego: "En el juego", opaco: "Original (fondo opaco)" };
const EXPLICA_METODO = {
  original: "con su fondo blanco",
  conectividad: "saca solo el blanco que toca el borde",
  rembg: "el modelo decide qué es fondo",
  juego: "como está hoy en el juego",
  opaco: "los fondos van enteros",
};

const E = {
  meta: null, assets: [], porId: new Map(), visibles: [], actual: null, detalle: null,
  paso: 1, filtros: {}, q: "", conNotas: false, fondo: "damero",
};

// ---------- utilidades ----------
async function pedir(url, opciones = {}) {
  const r = await fetch(url, opciones);
  const tipo = r.headers.get("Content-Type") || "";
  const datos = tipo.includes("json") ? await r.json() : await r.blob();
  if (!r.ok && r.status !== 202) {
    const error = new Error((datos && datos.error) || `Error ${r.status}`);
    error.status = r.status; error.datos = datos;
    throw error;
  }
  return { status: r.status, datos };
}
const postJSON = (url, cuerpo) => pedir(url, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(cuerpo || {}) });
let temporizadorToast;
function avisar(texto, error = false, ms = 2200) {
  const t = $("toast");
  t.textContent = texto; t.className = error ? "error" : ""; t.hidden = false;
  clearTimeout(temporizadorToast);
  temporizadorToast = setTimeout(() => (t.hidden = true), error ? 5000 : ms);
}
const guardarLocal = (k, v) => { try { v == null ? localStorage.removeItem(k) : localStorage.setItem(k, JSON.stringify(v)); } catch (e) {} };
const leerLocal = (k) => { try { return JSON.parse(localStorage.getItem(k)); } catch (e) { return null; } };
const escribiendo = () => ["INPUT", "TEXTAREA", "SELECT"].includes(document.activeElement?.tagName);
const slug = (s) => (s || "").replace(/\s+/g, "-");
const esSafari = /^((?!chrome|android|crios|fxios).)*safari/i.test(navigator.userAgent);

async function bitmapDe(url, opciones) {
  const r = await fetch(url, opciones);
  if (!r.ok) throw new Error(`no se pudo cargar ${url}`);
  return createImageBitmap(await r.blob(), { premultiplyAlpha: "none", colorSpaceConversion: "none" });
}
async function esperarTrabajo(trabajo, alAvanzar) {
  while (trabajo.estado === "en cola" || trabajo.estado === "corriendo") {
    alAvanzar?.(trabajo);
    await new Promise((ok) => setTimeout(ok, 700));
    trabajo = (await pedir(`/api/trabajo/${trabajo.id}`)).datos;
  }
  alAvanzar?.(trabajo);
  if (trabajo.estado === "fallo") throw new Error(trabajo.error || "falló");
  return trabajo;
}

// ---------- vista compartida y visores ----------
const damero = (() => {
  const c = document.createElement("canvas");
  c.width = c.height = 16;
  const x = c.getContext("2d");
  x.fillStyle = "#fff"; x.fillRect(0, 0, 16, 16);
  x.fillStyle = "#c9c2b4"; x.fillRect(0, 0, 8, 8); x.fillRect(8, 8, 8, 8);
  return c;
})();

function colorDeFondo() {
  if (E.fondo !== "piso") return E.fondo;
  return E.detalle?.atlas === "cosmic" ? PISO.cosmic : PISO.default;
}

class Vista {
  constructor() { this.escala = 1; this.x = 0; this.y = 0; this.visores = []; this.ajustada = true; this.mundo = null; }
  dibujar() { for (const v of this.visores) v.dibujar(); $("zoom-num").textContent = Math.round(this.escala * 100) + "%"; }
  ajustar() {
    for (const visor of this.visores) visor.medir();
    const v = this.visores[0];
    if (!v || !this.mundo || !v.ancho) return;
    const [w, h] = this.mundo;
    this.escala = Math.min(v.ancho / w, v.alto / h) * 0.94;
    this.x = (v.ancho - w * this.escala) / 2;
    this.y = (v.alto - h * this.escala) / 2;
    this.ajustada = true;
    this.dibujar();
  }
  zoom(factor, px, py) {
    const nueva = Math.min(48, Math.max(0.05, this.escala * factor));
    const v = this.visores[0];
    if (px == null) { px = v.ancho / 2; py = v.alto / 2; }
    this.x = px - (px - this.x) * (nueva / this.escala);
    this.y = py - (py - this.y) * (nueva / this.escala);
    this.escala = nueva;
    this.ajustada = false;
    this.dibujar();
  }
  mover(dx, dy) { this.x += dx; this.y += dy; this.ajustada = false; this.dibujar(); }
}

class Visor {
  constructor(canvas, vista, contenido, encima) {
    this.canvas = canvas; this.ctx = canvas.getContext("2d"); this.vista = vista;
    this.contenido = contenido; this.encima = encima;
    vista.visores.push(this);
    new ResizeObserver(() => this.redimensionar()).observe(canvas);
    conectarGestos(this);
  }
  medir() {
    const r = this.canvas.getBoundingClientRect();
    if (!r.width || !r.height) return false;
    const ppp = window.devicePixelRatio || 1;
    const w = Math.round(r.width * ppp), h = Math.round(r.height * ppp);
    this.ancho = r.width; this.alto = r.height;
    if (this.canvas.width !== w || this.canvas.height !== h) { this.canvas.width = w; this.canvas.height = h; }
    return true;
  }
  redimensionar() {
    if (!this.medir()) return;
    if (this.vista.ajustada) this.vista.ajustar(); else this.dibujar();
  }
  dibujar() {
    if (!this.ancho) return;
    const ctx = this.ctx, ppp = window.devicePixelRatio || 1, v = this.vista;
    ctx.setTransform(ppp, 0, 0, ppp, 0, 0);
    ctx.clearRect(0, 0, this.ancho, this.alto);
    ctx.fillStyle = E.fondo === "damero" ? ctx.createPattern(damero, "repeat") : colorDeFondo();
    ctx.fillRect(0, 0, this.ancho, this.alto);
    if (!v.mundo) return;
    ctx.save();
    ctx.translate(v.x, v.y);
    ctx.scale(v.escala, v.escala);
    ctx.imageSmoothingEnabled = v.escala < 2;
    ctx.imageSmoothingQuality = "high";
    this.contenido(ctx);
    ctx.restore();
    this.encima?.(ctx);
  }
  aMundo(ev) {
    const r = this.canvas.getBoundingClientRect(), v = this.vista;
    return [(ev.clientX - r.left - v.x) / v.escala, (ev.clientY - r.top - v.y) / v.escala];
  }
}

let espacio = false, mano = false;
function conectarGestos(visor) {
  const c = visor.canvas, v = visor.vista;
  c.addEventListener("wheel", (ev) => {
    ev.preventDefault();
    const r = c.getBoundingClientRect();
    const fuerza = ev.ctrlKey ? 0.012 : 0.0022;
    v.zoom(Math.exp(-ev.deltaY * fuerza), ev.clientX - r.left, ev.clientY - r.top);
  }, { passive: false });
  let gesto = 1;
  c.addEventListener("gesturestart", (ev) => { ev.preventDefault(); gesto = 1; });
  c.addEventListener("gesturechange", (ev) => {
    ev.preventDefault();
    const r = c.getBoundingClientRect();
    v.zoom(ev.scale / gesto, ev.clientX - r.left, ev.clientY - r.top);
    gesto = ev.scale;
  });
  let arrastre = null;
  c.addEventListener("pointerdown", (ev) => {
    const paneo = ev.button === 1 || espacio || mano;
    arrastre = { x: ev.clientX, y: ev.clientY, x0: ev.clientX, y0: ev.clientY, paneo, movio: false };
    c.setPointerCapture(ev.pointerId);
    if (paneo) { ev.preventDefault(); c.style.cursor = "grabbing"; }
    else visor.alBajar?.(ev);
  });
  c.addEventListener("pointermove", (ev) => {
    if (arrastre) {
      if (Math.hypot(ev.clientX - arrastre.x0, ev.clientY - arrastre.y0) > 4) arrastre.movio = true;
      if (arrastre.paneo) { v.mover(ev.clientX - arrastre.x, ev.clientY - arrastre.y); arrastre.x = ev.clientX; arrastre.y = ev.clientY; return; }
    }
    visor.alMover?.(ev, !!arrastre);
  });
  const soltar = (ev) => {
    if (!arrastre) return;
    const a = arrastre; arrastre = null;
    c.style.cursor = "";
    if (!a.paneo) visor.alSoltar?.(ev, a.movio);
  };
  c.addEventListener("pointerup", soltar);
  c.addEventListener("pointercancel", soltar);
  c.addEventListener("pointerleave", () => visor.alSalir?.());
  c.addEventListener("auxclick", (ev) => ev.preventDefault());
}

// ---------- lista y filtros ----------
const CAMPOS_FILTRO = ["tipo", "tipo_skin", "personaje", "atlas", "estado_imagen", "estado_video"];
const tieneNotas = (a) => !!(a.nota_imagen || a.nota_video);

function pasaFiltro(a, salvo) {
  for (const campo of CAMPOS_FILTRO) {
    if (campo === salvo) continue;
    const valor = E.filtros[campo];
    if (valor && a[campo] !== valor) return false;
  }
  if (salvo !== "notas" && E.conNotas && !tieneNotas(a)) return false;
  if (E.q && !`${a.id} ${a.nombre}`.toLowerCase().includes(E.q)) return false;
  return true;
}

function opcionesDe(campo) {
  const m = E.meta;
  if (campo === "tipo") return m.tipos;
  if (campo === "tipo_skin") return m.tipos_skin;
  if (campo === "estado_imagen") return m.estados_imagen;
  if (campo === "estado_video") return m.estados_video;
  return [...new Set(E.assets.map((a) => a[campo]).filter(Boolean))].sort();
}
const nombresPersonaje = new Map();
function etiqueta(campo, valor) {
  if (campo === "personaje") return nombresPersonaje.get(valor) || valor;
  return valor;
}

function armarFiltros() {
  nombresPersonaje.clear();
  for (const a of E.assets) {
    if (!a.personaje || nombresPersonaje.has(a.personaje)) continue;
    const base = E.assets.find((b) => b.id === a.personaje);
    nombresPersonaje.set(a.personaje, base ? base.nombre : a.nombre.split(" — ")[0].replace(/ \((habla|pide|cara|loop)\)$/, ""));
  }
  filtrar();
}

function filtrar() {
  const cuentas = {};
  for (const campo of [...CAMPOS_FILTRO, "notas"]) cuentas[campo] = new Map();
  for (const a of E.assets) {
    for (const campo of CAMPOS_FILTRO) if (pasaFiltro(a, campo)) cuentas[campo].set(a[campo], (cuentas[campo].get(a[campo]) || 0) + 1);
    if (pasaFiltro(a, "notas") && tieneNotas(a)) cuentas.notas.set(true, (cuentas.notas.get(true) || 0) + 1);
  }
  for (const sel of document.querySelectorAll("[data-filtro]")) {
    const campo = sel.dataset.filtro;
    const total = [...cuentas[campo].values()].reduce((x, y) => x + y, 0);
    const actual = E.filtros[campo] || "";
    sel.innerHTML = "";
    sel.append(new Option(`Todos (${total})`, ""));
    for (const valor of opcionesDe(campo)) {
      const n = cuentas[campo].get(valor) || 0;
      if (!n && valor !== actual) continue;
      sel.append(new Option(`${etiqueta(campo, valor)} (${n})`, valor));
    }
    sel.value = actual;
    sel.classList.toggle("usado", !!actual);
  }
  $("cuenta-notas").textContent = `(${cuentas.notas.get(true) || 0})`;
  E.visibles = E.assets.filter((a) => pasaFiltro(a));
  dibujarLista();
}

function chipEstado(texto) {
  return `<span class="chip e-${slug(texto)}">${texto}</span>`;
}
function dibujarLista() {
  const lista = $("lista");
  const frag = document.createDocumentFragment();
  for (const a of E.visibles) {
    const fila = document.createElement("div");
    fila.className = "fila-asset" + (E.actual === a.id ? " actual" : "");
    fila.dataset.id = a.id;
    const chips = [a.solo_video ? "" : chipEstado(a.estado_imagen),
                   a.estado_video !== "sin video" ? chipEstado("🎬 " + a.estado_video).replace("e-🎬-", "e-") : ""].join("");
    fila.innerHTML = `<img loading="lazy" alt="" src="/api/miniatura/${a.id}?v=${encodeURIComponent(a.guardado || "")}">` +
      `<div class="txt"><div class="nom"></div><div class="sub">${chips}</div></div>`;
    fila.querySelector(".nom").textContent = a.nombre;
    fila.querySelector(".nom").title = a.id;
    fila.onclick = () => abrir(a.id);
    frag.append(fila);
  }
  lista.replaceChildren(frag);
  $("cuenta-lista").textContent = `${E.visibles.length} de ${E.assets.length}`;
  const listos = E.assets.filter((a) => a.estado_imagen === "listo").length;
  const conImagen = E.assets.filter((a) => !a.solo_video).length;
  const va = E.assets.filter((a) => a.estado_video === "va").length;
  const conVideo = E.assets.filter((a) => a.estado_video !== "sin video").length;
  $("progreso-global").textContent = `${listos} de ${conImagen} imágenes listas · ${va} de ${conVideo} videos van`;
}
function marcarActualEnLista() {
  for (const f of $("lista").children) f.classList.toggle("actual", f.dataset.id === E.actual);
  $("lista").querySelector(".actual")?.scrollIntoView({ block: "nearest" });
}

async function cargarAssets() {
  const { datos } = await pedir("/api/assets");
  E.meta = datos;
  E.assets = datos.assets;
  E.porId = new Map(E.assets.map((a) => [a.id, a]));
  armarFiltros();
}
function refrescarResumen(entrada) {
  const a = E.porId.get(entrada.id);
  if (!a) return;
  Object.assign(a, {
    estado_imagen: entrada.imagen.estado, nota_imagen: entrada.imagen.nota || "",
    estado_video: entrada.video ? entrada.video.estado : "sin video",
    nota_video: entrada.video && entrada.video.tocado ? entrada.video.nota || "" : "",
    metodo: entrada.recorte?.metodo, guardado: entrada.fechas?.guardado,
  });
  filtrar();
  marcarActualEnLista();
}

function mover(paso) {
  if (!E.visibles.length) return;
  const i = E.visibles.findIndex((a) => a.id === E.actual);
  const j = Math.max(0, Math.min(E.visibles.length - 1, (i < 0 ? 0 : i + paso)));
  if (E.visibles[j].id !== E.actual) abrir(E.visibles[j].id);
}

// ---------- abrir un asset ----------
let abriendo = 0;
async function abrir(id) {
  const turno = ++abriendo;
  E.actual = id;
  marcarActualEnLista();
  guardarLocal("estudio-ultimo", id);
  const { datos } = await pedir(`/api/asset/${id}`);
  if (turno !== abriendo) return;
  E.detalle = datos;
  pintarPanel();
  islas.descargar();
  if (datos.solo_video) return mostrarPaso(0);
  await armarPaso1();
  const metodo = datos.recorte?.metodo;
  const listoParaIslas = metodo && metodo !== "opaco" && E.detalle.cortes_disponibles[metodo];
  mostrarPaso(listoParaIslas && E.paso === 2 ? 2 : 1);
}

function mostrarPaso(n) {
  E.paso = n || E.paso;
  $("paso1").classList.toggle("visible", n === 1);
  $("paso2").classList.toggle("visible", n === 2);
  $("solo-video").classList.toggle("visible", n === 0);
  for (const b of document.querySelectorAll("#pasos .paso")) b.classList.toggle("activo", +b.dataset.paso === n);
  $("herramientas-vista").style.visibility = n === 0 ? "hidden" : "";
  if (n === 0) {
    const d = E.detalle;
    $("poster").src = `/api/miniatura/${d.id}`;
    $("poster").src = d.archivos.poster ? `/api/imagen/${d.id}?vista=poster` : `/api/miniatura/${d.id}`;
  }
  if (n === 2) islas.cargar();
  else if (n === 1) vista1.ajustar();
}

// ---------- paso 1: el fondo ----------
const vista1 = new Vista();
let tarjetas = [];

function metodosDe(d) {
  if (d.tipo === "fondo") return d.archivos.original ? ["opaco"] : ["juego"];
  const lista = [];
  if (d.archivos.original) lista.push("original", "conectividad", "rembg");
  if (d.archivos.juego) lista.push("juego");
  return lista;
}

async function armarPaso1() {
  const d = E.detalle;
  const caja = $("tarjetas");
  caja.replaceChildren();
  vista1.visores = [];
  vista1.mundo = null;
  vista1.ajustada = true;
  tarjetas = [];
  const metodos = metodosDe(d);
  caja.style.gridTemplateColumns = `repeat(${metodos.length}, minmax(0, 1fr))`;
  for (const metodo of metodos) {
    const tarjeta = document.createElement("div");
    tarjeta.className = "tarjeta" + (metodo === "original" ? " referencia" : "");
    tarjeta.innerHTML = `<div class="tit"><span>${NOMBRES_METODO[metodo]}</span><span class="crece"></span></div><canvas></canvas><div class="estado">${EXPLICA_METODO[metodo]}</div>`;
    caja.append(tarjeta);
    const t = { metodo, tarjeta, imagen: null };
    t.visor = new Visor(tarjeta.querySelector("canvas"), vista1, (ctx) => {
      if (t.imagen) ctx.drawImage(t.imagen, 0, 0, vista1.mundo[0], vista1.mundo[1]);
    });
    t.visor.alSoltar = (ev, movio) => { if (!movio && metodo !== "original") elegir(metodo); };
    t.visor.canvas.addEventListener("dblclick", () => { if (metodo !== "original") elegir(metodo).then(() => irAIslas()); });
    tarjetas.push(t);
  }
  pintarElegida();
  const turno = abriendo;
  await Promise.all(tarjetas.map((t) => cargarTarjeta(t, turno)));
}

async function cargarTarjeta(t, turno) {
  const d = E.detalle;
  const vistaUrl = t.metodo === "opaco" ? "original" : t.metodo;
  const estado = t.tarjeta.querySelector(".estado");
  try {
    let url = `/api/imagen/${d.id}?vista=${vistaUrl}`;
    if (t.metodo === "rembg") {
      const r = await pedir(url);
      if (r.status === 202) {
        await esperarTrabajo(r.datos.trabajo, (tr) => {
          estado.textContent = tr.estado === "en cola" ? "rembg: esperando turno…" : `rembg: calculando… ${tr.mensaje || ""}`;
        });
        estado.textContent = EXPLICA_METODO.rembg;
        if (turno === abriendo) E.detalle.cortes_disponibles.rembg = true;
      }
    }
    const imagen = await bitmapDe(url + `&t=${Date.now()}`);
    if (turno !== abriendo) return;
    t.imagen = imagen;
    if (!vista1.mundo || t.metodo === "original" || t.metodo === "opaco") {
      vista1.mundo = [imagen.width, imagen.height];
      vista1.ajustar();
    } else vista1.dibujar();
  } catch (error) {
    estado.textContent = "No se pudo: " + error.message;
  }
}

function pintarElegida() {
  const metodo = E.detalle?.recorte?.metodo;
  const ninguno = E.detalle?.imagen.estado === "ninguno sirve";
  for (const t of tarjetas) {
    t.tarjeta.classList.toggle("elegida", t.metodo === metodo && !ninguno);
    const tit = t.tarjeta.querySelector(".tit .crece");
    tit.nextSibling?.remove();
    if (t.metodo === metodo && !ninguno) tit.insertAdjacentHTML("afterend", `<span class="chip e-listo">elegido</span>`);
  }
  $("ninguno").classList.toggle("activo", ninguno);
  $("a-islas").disabled = !metodo || metodo === "opaco" || ninguno;
}

async function elegir(metodo) {
  const { datos } = await postJSON(`/api/elegir/${E.detalle.id}`, { metodo });
  E.detalle = { ...E.detalle, ...datos };
  pintarElegida();
  pintarPanel();
  refrescarResumen(datos);
  if (metodo === "ninguno") avisar("Marcado: ningún recorte sirve");
  else avisar(`Elegido: ${NOMBRES_METODO[metodo]}`, false, 1200);
}

function irAIslas() {
  const metodo = E.detalle?.recorte?.metodo;
  if (!metodo || metodo === "opaco") return avisar("Primero elegí un recorte (un clic sobre la vista).", true);
  if (!E.detalle.cortes_disponibles[metodo]) return avisar("Ese recorte todavía se está calculando…", true);
  mostrarPaso(2);
}

// ---------- paso 2: las islas ----------
const vista2 = new Vista();
const islas = {
  herr: "rojo", radio: 12, verQueda: false, carga: null, sobre: null, trazo: null, puntero: null,

  descargar() { this.carga = null; this.verQueda = false; vista2.mundo = null; vista2.dibujar(); $("cuenta-islas").textContent = ""; $("chiquitas").replaceChildren(); },

  async cargar() {
    const d = E.detalle, metodo = d.recorte?.metodo;
    if (!metodo || metodo === "opaco") return;
    if (this.carga && this.carga.id === d.id && this.carga.metodo === metodo) { vista2.ajustar(); return; }
    const turno = abriendo;
    $("cargando").hidden = false;
    $("cargando").textContent = "Buscando las islas…";
    try {
      const [imagen, info, mapa] = await Promise.all([
        bitmapDe(`/api/imagen/${d.id}?vista=${metodo}`),
        pedir(`/api/islas/${d.id}?corte=${metodo}`).then((r) => r.datos),
        bitmapDe(`/api/mapa/${d.id}?corte=${metodo}`),
      ]);
      if (turno !== abriendo) return;
      this.preparar(d.id, metodo, imagen, info, mapa);
    } catch (error) {
      avisar("No se pudieron cargar las islas: " + error.message, true);
    } finally {
      $("cargando").hidden = true;
    }
  },

  preparar(id, metodo, imagen, info, mapa) {
    const W = info.ancho, H = info.alto, n = W * H;
    const lienzoMapa = new OffscreenCanvas(W, H);
    const cm = lienzoMapa.getContext("2d", { willReadFrequently: true });
    cm.drawImage(mapa, 0, 0);
    const m = cm.getImageData(0, 0, W, H).data;
    const sid = new Int32Array(n), hid = new Uint8Array(n);
    for (let i = 0; i < n; i++) { sid[i] = m[4 * i] + 256 * m[4 * i + 1]; hid[i] = m[4 * i + 2]; }
    const capa = new OffscreenCanvas(W, H);
    const resalte = new OffscreenCanvas(W, H);
    const porId = Object.fromEntries(info.islas.map((i) => [i.id, i]));
    this.carga = {
      id, metodo, imagen, W, H, sid, hid, porId, islas: info.islas,
      listaS: indexar(sid, n), listaH: indexar(hid, n),
      capa, cctx: capa.getContext("2d"), datos: new ImageData(W, H),
      resalte, rctx: resalte.getContext("2d"), pintado: new Uint8Array(n),
      previa: null,
    };
    // Las marcas: el borrador sin guardar, o lo guardado con este mismo corte.
    const borrador = leerLocal(`estudio-borrador-${id}`);
    const guardadas = E.detalle.marcas;
    const base = borrador && borrador.corte === metodo ? borrador
      : guardadas && guardadas.corte === metodo ? guardadas : { rojas: [], verdes: [], trazos: [] };
    this.marcas = { rojas: new Set(base.rojas), verdes: new Set(base.verdes), trazos: [...(base.trazos || [])] };
    this.atras = []; this.adelante = [];
    this.verQueda = false;
    this.rasterizarTodo();
    vista2.mundo = [W, H];
    vista2.ajustada = true;
    vista2.ajustar();
    this.contar();
  },

  // ----- estado de cada pixel -----
  sets() {
    const rS = new Set(), rH = new Set(), vS = new Set(), vH = new Set();
    for (const id of this.marcas.rojas) (id[0] === "s" ? rS : rH).add(+id.slice(1));
    for (const id of this.marcas.verdes) (id[0] === "s" ? vS : vH).add(+id.slice(1));
    this.conj = { rS, rH, vS, vH };
  },
  colorDe(i) {
    const c = this.carga, p = c.pintado[i];
    if (p === 1) return PINCEL;
    const s = c.sid[i], h = c.hid[i], { rS, rH, vS, vH } = this.conj;
    if (p === 2) return null;
    if ((s && rS.has(s)) || (h && rH.has(h))) return ROJO;
    if ((h && vH.has(h)) || (!h && s && vS.has(s))) return VERDE;
    return null;
  },
  escribir(i) {
    const d = this.carga.datos.data, o = 4 * i, col = this.colorDe(i);
    if (col) { d[o] = col[0]; d[o + 1] = col[1]; d[o + 2] = col[2]; d[o + 3] = col[3]; }
    else d[o + 3] = 0;
  },
  repintarCaja(x0, y0, x1, y1) {
    const c = this.carga;
    x0 = Math.max(0, Math.floor(x0)); y0 = Math.max(0, Math.floor(y0));
    x1 = Math.min(c.W, Math.ceil(x1)); y1 = Math.min(c.H, Math.ceil(y1));
    if (x1 <= x0 || y1 <= y0) return;
    for (let y = y0; y < y1; y++) for (let x = x0; x < x1; x++) this.escribir(y * c.W + x);
    c.cctx.putImageData(c.datos, 0, 0, x0, y0, x1 - x0, y1 - y0);
  },
  repintarIsla(id) {
    const c = this.carga, ficha = c.porId[id];
    if (!ficha) return;
    const [lista, n] = id[0] === "s" ? [c.listaS, +id.slice(1)] : [c.listaH, +id.slice(1)];
    for (let k = lista.desde[n]; k < lista.desde[n + 1]; k++) this.escribir(lista.pixeles[k]);
    const [x0, y0, x1, y1] = ficha.caja;
    c.cctx.putImageData(c.datos, 0, 0, x0, y0, x1 - x0, y1 - y0);
  },
  rasterizarTodo() {
    const c = this.carga;
    c.pintado.fill(0);
    for (const t of this.marcas.trazos) this.estampar(t, 0, t.puntos.length);
    this.sets();
    this.repintarCaja(0, 0, c.W, c.H);
    vista2.dibujar();
  },
  estampar(t, desde, hasta) {
    // Discos de radio r a lo largo del trazo: lo mismo que la linea + circulos de PIL.
    const c = this.carga, r = t.radio, valor = t.modo === "goma" ? 2 : 1, r2 = r * r;
    const caja = [Infinity, Infinity, -Infinity, -Infinity];
    const disco = (cx, cy) => {
      const ya = Math.max(0, Math.floor(cy - r)), yb = Math.min(c.H - 1, Math.ceil(cy + r));
      const xa = Math.max(0, Math.floor(cx - r)), xb = Math.min(c.W - 1, Math.ceil(cx + r));
      for (let y = ya; y <= yb; y++) for (let x = xa; x <= xb; x++) {
        const dx = x - cx, dy = y - cy;
        if (dx * dx + dy * dy <= r2) c.pintado[y * c.W + x] = valor;
      }
      caja[0] = Math.min(caja[0], xa); caja[1] = Math.min(caja[1], ya);
      caja[2] = Math.max(caja[2], xb + 1); caja[3] = Math.max(caja[3], yb + 1);
    };
    const pts = t.puntos;
    for (let k = Math.max(desde, 0); k < hasta; k++) {
      const [x, y] = pts[k];
      if (k === 0) { disco(x, y); continue; }
      const [px, py] = pts[k - 1];
      const largo = Math.hypot(x - px, y - py), pasos = Math.max(1, Math.ceil(largo / Math.max(0.5, r / 2)));
      for (let s = 1; s <= pasos; s++) disco(px + ((x - px) * s) / pasos, py + ((y - py) * s) / pasos);
    }
    return caja;
  },

  // ----- historia -----
  recordar() {
    this.atras.push({ rojas: [...this.marcas.rojas], verdes: [...this.marcas.verdes], trazos: [...this.marcas.trazos] });
    if (this.atras.length > 200) this.atras.shift();
    this.adelante = [];
  },
  restaurar(estado) {
    this.marcas = { rojas: new Set(estado.rojas), verdes: new Set(estado.verdes), trazos: [...estado.trazos] };
    this.rasterizarTodo();
    this.cambio();
  },
  deshacer() {
    if (!this.carga || !this.atras.length) return avisar("No hay nada para deshacer");
    this.adelante.push({ rojas: [...this.marcas.rojas], verdes: [...this.marcas.verdes], trazos: [...this.marcas.trazos] });
    this.restaurar(this.atras.pop());
  },
  rehacer() {
    if (!this.carga || !this.adelante.length) return avisar("No hay nada para rehacer");
    this.atras.push({ rojas: [...this.marcas.rojas], verdes: [...this.marcas.verdes], trazos: [...this.marcas.trazos] });
    this.restaurar(this.adelante.pop());
  },
  cambio() {
    const c = this.carga;
    if (this.verQueda) this.alternarQueda(false);
    guardarLocal(`estudio-borrador-${c.id}`, { corte: c.metodo, rojas: [...this.marcas.rojas], verdes: [...this.marcas.verdes], trazos: this.marcas.trazos });
    this.contar();
    vista2.dibujar();
  },
  borrarTodo() {
    if (!this.carga) return;
    this.recordar();
    this.marcas = { rojas: new Set(), verdes: new Set(), trazos: [] };
    this.rasterizarTodo();
    this.cambio();
  },

  // ----- pintar -----
  islaEn(x, y) {
    const c = this.carga;
    x = Math.floor(x); y = Math.floor(y);
    if (!c || x < 0 || y < 0 || x >= c.W || y >= c.H) return null;
    const i = y * c.W + x;
    if (c.hid[i]) return "h" + c.hid[i];
    if (c.sid[i]) return "s" + c.sid[i];
    return null;
  },
  islaCerca(x, y) {
    const directa = this.islaEn(x, y);
    if (directa) return directa;
    const radio = Math.max(3, Math.round(10 / vista2.escala));
    let mejor = null, dist = Infinity;
    for (let dy = -radio; dy <= radio; dy += 1) for (let dx = -radio; dx <= radio; dx += 1) {
      const d = dx * dx + dy * dy;
      if (d >= dist || d > radio * radio) continue;
      const id = this.islaEn(x + dx, y + dy);
      if (id) { mejor = id; dist = d; }
    }
    return mejor;
  },
  pintar(id) {
    if (!this.carga || !id) return;
    const roja = this.herr === "rojo";
    if (roja && id === "s1" && !this.marcas.rojas.has(id) &&
        !confirm("Esa es la isla más grande: casi seguro es el personaje.\n¿La pinto de rojo igual (se borra entera)?")) return;
    this.recordar();
    const [pon, saca] = roja ? [this.marcas.rojas, this.marcas.verdes] : [this.marcas.verdes, this.marcas.rojas];
    if (pon.has(id)) pon.delete(id); else { pon.add(id); saca.delete(id); }
    this.sets();
    this.repintarIsla(id);
    const ficha = this.carga.porId[id];
    // Pintar una suelta pinta tambien sus huecos: se repintan.
    if (id[0] === "s") for (const f of this.carga.islas) if (f.dentro_de === id) this.repintarIsla(f.id);
    if (ficha && ficha.dentro_de) this.repintarIsla(ficha.dentro_de);
    this.cambio();
  },
  resaltar(id) {
    const c = this.carga;
    if (!c || id === this.sobre) return;
    if (this.sobre && c.porId[this.sobre]) { const [x0, y0, x1, y1] = c.porId[this.sobre].caja; c.rctx.clearRect(x0, y0, x1 - x0, y1 - y0); }
    this.sobre = id;
    if (id && c.porId[id]) {
      const [x0, y0, x1, y1] = c.porId[id].caja, w = x1 - x0, h = y1 - y0;
      const img = new ImageData(w, h), d = img.data;
      const [lista, n] = id[0] === "s" ? [c.listaS, +id.slice(1)] : [c.listaH, +id.slice(1)];
      for (let k = lista.desde[n]; k < lista.desde[n + 1]; k++) {
        const p = lista.pixeles[k], x = (p % c.W) - x0, y = ((p / c.W) | 0) - y0, o = 4 * (y * w + x);
        d[o] = AMARILLO[0]; d[o + 1] = AMARILLO[1]; d[o + 2] = AMARILLO[2]; d[o + 3] = AMARILLO[3];
      }
      c.rctx.putImageData(img, x0, y0);
    }
    vista2.dibujar();
  },

  async alternarQueda(forzar) {
    if (!this.carga) return;
    this.verQueda = forzar ?? !this.verQueda;
    $("como-queda").classList.toggle("activo", this.verQueda);
    if (this.verQueda) {
      const c = this.carga;
      $("cargando").hidden = false; $("cargando").textContent = "Armando cómo queda…";
      try {
        c.previa = await bitmapDe(`/api/previa/${c.id}`, {
          method: "POST", headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ corte: c.metodo, rojas: [...this.marcas.rojas], trazos: this.marcas.trazos }),
        });
      } catch (error) { avisar(error.message, true); this.verQueda = false; }
      finally { $("cargando").hidden = true; }
    }
    vista2.dibujar();
  },

  contar() {
    const c = this.carga;
    if (!c) return;
    const n = c.islas.length, rojas = c.islas.filter((i) => this.marcas.rojas.has(i.id)).length;
    const verdes = c.islas.filter((i) => this.marcas.verdes.has(i.id)).length;
    const trazos = this.marcas.trazos.length;
    $("cuenta-islas").textContent = `${n} islas: ${rojas} se sacan, ${verdes} se quedan` + (trazos ? ` · ${trazos} trazos a mano` : "");
    const chicas = c.islas.filter((i) => i.diminuta);
    const caja = $("chiquitas");
    caja.replaceChildren();
    if (chicas.length) caja.append(`Chiquitas (${chicas.length}): `);
    for (const isla of chicas.slice(0, 40)) {
      const b = document.createElement("button");
      b.className = "chico" + (this.marcas.rojas.has(isla.id) ? " malo activo" : this.marcas.verdes.has(isla.id) ? " bueno activo" : "");
      b.textContent = isla.id;
      b.title = `${isla.area} px — clic para pintarla con el balde`;
      b.onmouseenter = () => this.resaltar(isla.id);
      b.onmouseleave = () => this.resaltar(null);
      b.onclick = () => { if (this.herr !== "rojo" && this.herr !== "verde") elegirHerramienta("rojo"); this.pintar(isla.id); };
      caja.append(b);
    }
    if (chicas.length > 40) caja.append(` …y ${chicas.length - 40} más`);
  },
};

function indexar(ids, n) {
  let max = 0;
  for (let i = 0; i < n; i++) if (ids[i] > max) max = ids[i];
  const desde = new Int32Array(max + 2);
  for (let i = 0; i < n; i++) if (ids[i]) desde[ids[i] + 1]++;
  for (let k = 1; k < desde.length; k++) desde[k] += desde[k - 1];
  const pixeles = new Int32Array(desde[max + 1]), lleno = desde.slice();
  for (let i = 0; i < n; i++) if (ids[i]) pixeles[lleno[ids[i]]++] = i;
  return { desde, pixeles };
}

const visor2 = new Visor($("lienzo"), vista2, (ctx) => {
  const c = islas.carga;
  if (!c) return;
  if (islas.verQueda && c.previa) { ctx.drawImage(c.previa, 0, 0); return; }
  ctx.drawImage(c.imagen, 0, 0);
  ctx.drawImage(c.capa, 0, 0);
  ctx.drawImage(c.resalte, 0, 0);
}, (ctx) => {
  const c = islas.carga;
  if (!c || islas.verQueda) return;
  const v = vista2;
  for (const isla of c.islas) {
    if (!isla.diminuta) continue;
    const [x0, y0, x1, y1] = isla.caja;
    const cx = v.x + ((x0 + x1) / 2) * v.escala, cy = v.y + ((y0 + y1) / 2) * v.escala;
    const r = Math.max(9, (Math.max(x1 - x0, y1 - y0) * v.escala) / 2 + 6);
    const resaltada = islas.sobre === isla.id;
    ctx.beginPath();
    ctx.arc(cx, cy, resaltada ? r + 5 : r, 0, 2 * Math.PI);
    ctx.lineWidth = resaltada ? 3 : 2;
    ctx.setLineDash(resaltada ? [] : [4, 3]);
    ctx.strokeStyle = islas.marcas.rojas.has(isla.id) ? "#c0392b" : islas.marcas.verdes.has(isla.id) ? "#2e7d4f" : resaltada ? "#ffd200" : "#e08a00";
    ctx.stroke();
  }
  ctx.setLineDash([]);
  if (islas.puntero && (islas.herr === "pincel" || islas.herr === "goma")) {
    const [mx, my] = islas.puntero;
    ctx.beginPath();
    ctx.arc(v.x + mx * v.escala, v.y + my * v.escala, Math.max(1, islas.radio * v.escala), 0, 2 * Math.PI);
    ctx.lineWidth = 1.5;
    ctx.strokeStyle = islas.herr === "pincel" ? "#d62828" : "#2f5d9b";
    ctx.stroke();
  }
});

visor2.alBajar = (ev) => {
  if (!islas.carga || islas.verQueda) return;
  if (islas.herr === "pincel" || islas.herr === "goma") {
    const [x, y] = visor2.aMundo(ev);
    islas.recordar();
    islas.trazo = { modo: islas.herr, radio: islas.radio, puntos: [[+x.toFixed(1), +y.toFixed(1)]] };
    islas.marcas.trazos.push(islas.trazo);
    const caja = islas.estampar(islas.trazo, 0, 1);
    islas.repintarCaja(...caja);
    vista2.dibujar();
  }
};
visor2.alMover = (ev, apretado) => {
  if (!islas.carga) return;
  const [x, y] = visor2.aMundo(ev);
  islas.puntero = [x, y];
  if (islas.trazo && apretado) {
    const pts = islas.trazo.puntos, [px, py] = pts[pts.length - 1];
    if (Math.hypot(x - px, y - py) >= Math.max(0.5, islas.radio / 4)) {
      pts.push([+x.toFixed(1), +y.toFixed(1)]);
      const caja = islas.estampar(islas.trazo, pts.length - 1, pts.length);
      islas.repintarCaja(...caja);
    }
    vista2.dibujar();
    return;
  }
  if (islas.herr === "rojo" || islas.herr === "verde") {
    const id = islas.verQueda ? null : islas.islaCerca(x, y);
    const globo = $("globo");
    if (id) {
      const f = islas.carga.porId[id] || { area: "?" };
      const que = id[0] === "h" ? "blanco encerrado" : id === "s1" ? "la isla más grande (el personaje)" : "isla suelta";
      const estado = islas.marcas.rojas.has(id) ? " — se saca" : islas.marcas.verdes.has(id) ? " — se queda" : "";
      globo.textContent = `${id}: ${que}, ${f.area} px${estado}`;
      globo.style.left = ev.clientX + 14 + "px"; globo.style.top = ev.clientY + 14 + "px";
      globo.hidden = false;
    } else globo.hidden = true;
    islas.resaltar(id);
  } else vista2.dibujar();
};
visor2.alSoltar = (ev, movio) => {
  if (!islas.carga) return;
  if (islas.trazo) { islas.trazo = null; islas.cambio(); return; }
  if (movio || islas.verQueda) { if (islas.verQueda && !movio) avisar("Estás viendo cómo queda: tocá C para volver a pintar"); return; }
  if (islas.herr === "rojo" || islas.herr === "verde") {
    const id = islas.islaCerca(...visor2.aMundo(ev));
    if (!id) return avisar("Ahí no hay ninguna isla. Para lo que no se detecta, usá el pincel (P).");
    islas.pintar(id);
  }
};
visor2.alSalir = () => { $("globo").hidden = true; islas.puntero = null; islas.resaltar(null); vista2.dibujar(); };

function elegirHerramienta(h) {
  islas.herr = h;
  for (const b of document.querySelectorAll(".herr")) b.classList.toggle("activo", b.dataset.herr === h);
  $("tamano-caja").style.opacity = h === "pincel" || h === "goma" ? 1 : 0.4;
  $("lienzo").style.cursor = h === "pincel" || h === "goma" ? "none" : "crosshair";
  vista2.dibujar();
}
function cambiarTamano(r) {
  islas.radio = Math.max(1, Math.min(120, Math.round(r)));
  $("tamano").value = islas.radio; $("tamano-num").textContent = islas.radio;
  vista2.dibujar();
}

// ---------- panel derecho ----------
function pintarPanel() {
  const d = E.detalle;
  $("nombre").textContent = d.nombre;
  const filas = [
    ["id", d.id], ["tipo", d.tipo], ["personaje", d.personaje ? `${nombresPersonaje.get(d.personaje) || d.personaje}` : ""],
    ["skin", d.tipo_skin], ["atlas", d.atlas ? `${d.atlas}${d.sprite ? " / " + d.sprite : ""}` : ""],
    ["recorte", d.recorte?.metodo ? `${NOMBRES_METODO[d.recorte.metodo]}${d.recorte.origen === "revision-v2" ? " (revisión anterior)" : ""}` : ""],
    ["original", d.archivos.original ? d.archivos.original.split("/").slice(-2).join("/") : "—"],
    ["en el juego", d.en_juego ? "sí, ya aplicado" : d.aplicado?.imagen ? `aplicado en ${d.aplicado.imagen.rama}` : ""],
  ].filter(([, v]) => v);
  if (d.origen === "importado") filas.push(["origen", "importado en el Estudio"]);
  $("datos").innerHTML = "";
  for (const [k, v] of filas) {
    const a = document.createElement("span"); a.textContent = k;
    const b = document.createElement("b"); b.textContent = v;
    $("datos").append(a, b);
  }
  // imagen
  const sel = $("estado-imagen");
  sel.innerHTML = "";
  for (const e of E.meta.estados_imagen) if (e !== "sin imagen" || d.solo_video) sel.append(new Option(e, e));
  sel.value = d.imagen.estado;
  sel.disabled = !!d.solo_video;
  $("nota-imagen").value = d.imagen.nota || "";
  $("nota-imagen").disabled = !!d.solo_video;
  const previo = d.marcas_previas;
  $("previo").hidden = !previo;
  if (previo) $("previo").textContent = `Islas ya revisadas en el balde (${(previo.rojas || []).length} sacadas, ${previo.guardado || ""}): la vista «En el juego» ya las tiene sacadas.`;
  $("guardar").disabled = !!d.solo_video;
  // video
  pintarVideo();
  // historial
  $("historial").innerHTML = "";
  for (const h of [...(d.historial || [])].reverse().slice(0, 15)) {
    const li = document.createElement("li"); li.textContent = `${h.fecha.replace("T", " ")} — ${h.que}`;
    $("historial").append(li);
  }
}

function pintarVideo() {
  const d = E.detalle, v = d.video;
  $("sin-video").hidden = !!v;
  $("con-video").hidden = !v;
  $("radio-video").hidden = !v;
  const video = $("video");
  if (!v) { video.removeAttribute("src"); video.load(); return; }
  const opciones = { estudio: !!v.mov_estudio, juego: !!v.mov, master: !!v.master };
  for (const o of $("video-cual").options) o.disabled = !opciones[o.value];
  const preferido = opciones.estudio ? "estudio" : opciones.juego ? "juego" : "master";
  $("video-cual").value = preferido;
  cargarVideo();
  for (const b of document.querySelectorAll("[data-video]")) b.classList.toggle("activo", b.dataset.video === v.estado);
  $("nota-video").value = v.nota || "";
  $("procesar-video").disabled = !v.master;
  const trabajo = d.trabajo_video;
  if (trabajo) seguirVideo(trabajo);
  else $("progreso-video").hidden = true;
  if (v.procesado?.menores != null) $("menores").value = v.procesado.menores;
}

function cargarVideo() {
  const d = E.detalle, cual = $("video-cual").value, video = $("video");
  $("aviso-video").hidden = true;
  $("aviso-safari").hidden = esSafari || cual === "master";
  video.src = `/api/video/${d.id}?cual=${cual}&t=${Date.now()}`;
  video.play().catch(() => {});
  pintarFondoVideo();
}
function pintarFondoVideo() {
  const marco = $("video-marco"), f = $("video-fondo").value;
  marco.className = f === "damero" ? "damero" : "";
  marco.style.backgroundColor = f === "damero" ? "" : f === "piso" ? (E.detalle?.atlas === "cosmic" ? PISO.cosmic : PISO.default) : f;
}
$("video").addEventListener("error", () => {
  const v = E.detalle?.video, cual = $("video-cual").value;
  if (!v) return;
  if (cual !== "master" && v.master) {
    $("aviso-video").hidden = false;
    $("aviso-video").textContent = "Este navegador no puede reproducir el .mov: muestro el master (con fondo). En Safari se ve el recortado.";
    $("video-cual").value = "master";
    cargarVideo();
  } else {
    $("aviso-video").hidden = false;
    $("aviso-video").textContent = "No se pudo reproducir el video.";
  }
});

async function seguirVideo(trabajo) {
  const barra = $("progreso-video"), id = E.detalle.id;
  barra.hidden = false;
  $("procesar-video").disabled = true;
  try {
    await esperarTrabajo(trabajo, (t) => {
      barra.querySelector("div").style.width = Math.round((t.progreso || 0) * 100) + "%";
      barra.querySelector("span").textContent = t.estado === "en cola" ? "esperando turno…" : t.mensaje || "procesando…";
    });
    if (E.detalle?.id === id) {
      const { datos } = await pedir(`/api/asset/${id}`);
      E.detalle = datos;
      pintarVideo();
      $("video-cual").value = "estudio";
      cargarVideo();
      avisar("Video procesado: estás viendo el resultado");
    }
  } catch (error) {
    avisar("No se pudo procesar el video: " + error.message, true);
  } finally {
    if (E.detalle?.id === id) { barra.hidden = true; $("procesar-video").disabled = false; }
  }
}

async function estadoVideo(estado, nota) {
  const id = E.detalle.id;
  const cuerpo = { estado };
  if (nota !== undefined) cuerpo.nota = nota;
  const { datos } = await postJSON(`/api/estado-video/${id}`, cuerpo);
  if (E.detalle?.id === id) { E.detalle = { ...E.detalle, ...datos }; pintarPanelSinVideo(); }
  refrescarResumen(datos);
}
async function estadoImagen(estado, nota) {
  const id = E.detalle.id;
  const cuerpo = { estado };
  if (nota !== undefined) cuerpo.nota = nota;
  const { datos } = await postJSON(`/api/estado-imagen/${id}`, cuerpo);
  if (E.detalle?.id === id) { E.detalle = { ...E.detalle, ...datos }; pintarPanelSinVideo(); pintarElegida(); }
  refrescarResumen(datos);
}
function pintarPanelSinVideo() {
  const d = E.detalle;
  $("estado-imagen").value = d.imagen.estado;
  if (document.activeElement !== $("nota-imagen")) $("nota-imagen").value = d.imagen.nota || "";
  if (d.video) {
    for (const b of document.querySelectorAll("[data-video]")) b.classList.toggle("activo", b.dataset.video === d.video.estado);
    if (document.activeElement !== $("nota-video")) $("nota-video").value = d.video.nota || "";
  }
  $("historial").innerHTML = "";
  for (const h of [...(d.historial || [])].reverse().slice(0, 15)) {
    const li = document.createElement("li"); li.textContent = `${h.fecha.replace("T", " ")} — ${h.que}`;
    $("historial").append(li);
  }
}

async function guardar() {
  const d = E.detalle;
  if (!d || d.solo_video) return;
  const metodo = d.recorte?.metodo;
  if (!metodo) return avisar("Primero elegí el fondo (paso 1).", true);
  const c = islas.carga && islas.carga.id === d.id && islas.carga.metodo === metodo ? islas : null;
  const cuerpo = { corte: metodo, rojas: c ? [...c.marcas.rojas] : (d.marcas?.corte === metodo ? d.marcas.rojas : []),
                   verdes: c ? [...c.marcas.verdes] : (d.marcas?.corte === metodo ? d.marcas.verdes : []),
                   trazos: c ? c.marcas.trazos : (d.marcas?.corte === metodo ? d.marcas.trazos : []) };
  $("guardar").disabled = true;
  try {
    const { datos } = await postJSON(`/api/guardar/${d.id}`, cuerpo);
    guardarLocal(`estudio-borrador-${d.id}`, null);
    if (E.detalle?.id === d.id) E.detalle = { ...E.detalle, ...datos };
    refrescarResumen(datos);
    avisar("✓ Guardado");
    const i = E.visibles.findIndex((a) => a.id === d.id);
    const siguiente = E.visibles.slice(i + 1).find((a) => a.estado_imagen === "sin revisar" && !a.solo_video)
      || E.visibles.find((a) => a.estado_imagen === "sin revisar" && !a.solo_video);
    if (siguiente) setTimeout(() => abrir(siguiente.id), 350);
    else avisar("✓ Guardado — no quedan sin revisar en esta lista");
  } catch (error) {
    avisar("No se pudo guardar: " + error.message, true);
  } finally {
    $("guardar").disabled = false;
  }
}

function pedirRegenerar(que) {
  const d = E.detalle;
  if (!d) return;
  const dlg = $("dlg-regenerar");
  const radios = dlg.querySelectorAll("input[name=que]");
  radios[0].disabled = !!d.solo_video;
  const elegido = que || (d.solo_video ? "video" : "imagen");
  for (const r of radios) r.checked = r.value === elegido;
  const nota = () => (dlg.querySelector("input[name=que]:checked").value === "video" ? d.video?.nota : d.imagen.nota) || "";
  $("regenerar-nota").value = nota();
  for (const r of radios) r.onchange = () => ($("regenerar-nota").value = nota());
  dlg.returnValue = "";
  dlg.showModal();
  $("regenerar-nota").focus();
  dlg.onclose = async () => {
    if (dlg.returnValue !== "ok") return;
    const texto = $("regenerar-nota").value.trim();
    const cual = dlg.querySelector("input[name=que]:checked").value;
    try {
      if (cual === "video") await estadoVideo("regenerar", texto);
      else await estadoImagen("regenerar", texto);
      avisar(`Marcado para regenerar (${cual}): le llega al generador`);
    } catch (error) { avisar(error.message, true); }
  };
}

// ---------- importar ----------
let archivoImportar = null;
function abrirImportar(archivo) {
  const dlg = $("dlg-importar");
  archivoImportar = null;
  $("archivo-nombre").textContent = "";
  $("imp-aviso").textContent = "";
  $("imp-carpeta-caja").hidden = true;
  const personajes = [...new Set(E.assets.map((a) => a.personaje).filter(Boolean))].sort();
  $("lista-personajes").innerHTML = personajes.map((p) => `<option value="${p}">${nombresPersonaje.get(p) || ""}</option>`).join("");
  const skins = new Set(["oro", "diamante", "pijama", "gaucho", "dinosaurio"]);
  for (const a of E.assets) if (a.id.includes("__")) skins.add(a.id.split("__")[1]);
  $("lista-skins").innerHTML = [...skins].sort().map((s) => `<option value="${s}">`).join("");
  $("lista-ids").innerHTML = E.assets.map((a) => `<option value="${a.id}">${a.nombre}</option>`).join("");
  $("imp-carpeta").innerHTML = `<option value="">(adivinar por el nombre)</option>` + E.meta.carpetas_video.map((c) => `<option>${c}</option>`).join("");
  if (archivo) elegirArchivo(archivo);
  dlg.showModal();
}
function elegirArchivo(archivo) {
  archivoImportar = archivo;
  $("archivo-nombre").textContent = `📎 ${archivo.name} (${(archivo.size / 1048576).toFixed(1)} MB)`;
  const esVideo = /\.mp4$/i.test(archivo.name) || archivo.type === "video/mp4";
  $("imp-carpeta-caja").hidden = !esVideo;
  if (!$("imp-id").value) {
    const base = archivo.name.replace(/\.[^.]+$/, "").toLowerCase().replace(/[^a-z0-9_]/g, "_");
    $("imp-id").value = base;
  }
  avisoImportar();
}
function avisoImportar() {
  const id = $("imp-id").value.trim();
  const a = E.porId.get(id);
  const esVideo = !$("imp-carpeta-caja").hidden;
  $("imp-aviso").textContent = !id ? "" : !/^[a-z0-9_]+$/.test(id) ? "El nombre va en minúsculas, con _ (sin espacios ni acentos)."
    : esVideo ? (a ? `Va como master del video de «${a.nombre}». Si ya hay uno, te pregunto antes de reemplazarlo.` : "Video nuevo: elegí su clase si no la adivino.")
    : a ? `Ya existe «${a.nombre}»: la imagen nueva reemplaza su original para revisarla. El juego no cambia hasta «Aplicar».`
    : "Es nuevo: entra como «sin revisar». Para que el juego lo use hace falta su entrada en prompts.json (y skins.json si es skin).";
}
function componerId() {
  const p = $("imp-personaje").value.trim(), s = $("imp-skin").value.trim();
  if (p) $("imp-id").value = s ? `${p}__${s}` : p;
  avisoImportar();
}
async function importar(reemplazar = false) {
  if (!archivoImportar) return avisar("Elegí o arrastrá un archivo.", true);
  const id = $("imp-id").value.trim();
  const params = new URLSearchParams({ id, nombre: archivoImportar.name, reemplazar: reemplazar ? "1" : "0", carpeta: $("imp-carpeta").value });
  $("imp-ok").disabled = true;
  $("imp-aviso").textContent = "Subiendo y calculando los recortes…";
  try {
    const { datos } = await pedir(`/api/importar?${params}`, { method: "POST", body: archivoImportar });
    $("dlg-importar").close();
    await cargarAssets();
    avisar(`Importado: ${datos.nombre}`);
    abrir(datos.id);
  } catch (error) {
    if (error.status === 409 && error.datos?.existe) {
      if (confirm(error.message)) return importar(true);
      $("imp-aviso").textContent = "No se importó.";
    } else {
      if (error.datos?.pedir_carpeta) $("imp-carpeta-caja").hidden = false;
      $("imp-aviso").textContent = error.message;
    }
  } finally {
    $("imp-ok").disabled = false;
  }
}

// ---------- aplicar ----------
async function abrirAplicar() {
  const dlg = $("dlg-aplicar");
  $("aplicar-resumen").textContent = "Calculando…";
  $("aplicar-detalle").textContent = "";
  $("aplicar-ok").disabled = true;
  $("progreso-aplicar").hidden = true;
  dlg.showModal();
  const { datos } = await pedir("/api/aplicar");
  const p = datos.plan;
  const tocadas = p.imagenes.filter((i) => i.tocada).length;
  $("aplicar-resumen").innerHTML = `<p><b>${p.imagenes.length}</b> imágenes listas (${p.imagenes.length - tocadas} con el recorte elegido, ${tocadas} limpias de islas) y <b>${p.videos.length}</b> videos procesados que van.` +
    (p.salteadas.length ? ` ${p.salteadas.length} quedan afuera (abajo dice por qué).` : "") +
    `</p><p>Se aplica en una <b>rama nueva</b> (no toca tu copia del juego), se corren los tests del pipeline y, si pasan, se commitea. Después se integra como siempre, por los relevos.</p>`;
  $("aplicar-detalle").textContent = [...datos.informe, ...p.salteadas.map((s) => `  ✗ ${s.id}: ${s.motivo}`)].join("\n") || "Nada para aplicar.";
  $("aplicar-ok").disabled = !(p.imagenes.length || p.videos.length);
  if (datos.trabajo) seguirAplicar(datos.trabajo);
}
async function seguirAplicar(trabajo) {
  const barra = $("progreso-aplicar");
  barra.hidden = false;
  $("aplicar-ok").disabled = true;
  try {
    const t = await esperarTrabajo(trabajo, (t) => {
      barra.querySelector("div").style.width = t.estado === "listo" ? "100%" : "50%";
      barra.querySelector("span").textContent = t.mensaje || "trabajando…";
    });
    const r = t.resultado;
    $("aplicar-resumen").innerHTML = `<p><b>${r.ok ? "✓ " : "✗ "}${r.mensaje}</b></p>` + (r.carpeta ? `<p>Carpeta: <code>${r.carpeta}</code></p>` : "");
    $("aplicar-detalle").textContent = r.log || "";
    await cargarAssets();
  } catch (error) {
    $("aplicar-resumen").textContent = "Falló: " + error.message;
  } finally {
    barra.hidden = true;
  }
}

// ---------- botones y teclas ----------
for (const sel of document.querySelectorAll("[data-filtro]")) sel.onchange = () => { E.filtros[sel.dataset.filtro] = sel.value; filtrar(); };
$("con-notas").onchange = (e) => { E.conNotas = e.target.checked; filtrar(); };
$("buscar").oninput = (e) => { E.q = e.target.value.trim().toLowerCase(); filtrar(); };
$("limpiar-filtros").onclick = () => { E.filtros = {}; E.conNotas = false; $("con-notas").checked = false; E.q = ""; $("buscar").value = ""; filtrar(); };
for (const b of document.querySelectorAll("#pasos .paso")) b.onclick = () => (+b.dataset.paso === 2 ? irAIslas() : mostrarPaso(1));
$("a-islas").onclick = irAIslas;
$("ninguno").onclick = () => elegir("ninguno");
const vistaActual = () => (E.paso === 2 ? vista2 : vista1);
$("zoom-mas").onclick = () => vistaActual().zoom(1.25);
$("zoom-menos").onclick = () => vistaActual().zoom(1 / 1.25);
$("ajustar").onclick = () => vistaActual().ajustar();
$("mano").onclick = () => { mano = !mano; $("mano").classList.toggle("activo", mano); };
$("fondo").onchange = (e) => { E.fondo = e.target.value; vista1.dibujar(); vista2.dibujar(); };
for (const b of document.querySelectorAll(".herr")) b.onclick = () => elegirHerramienta(b.dataset.herr);
$("tamano").oninput = (e) => cambiarTamano(+e.target.value);
$("deshacer").onclick = () => islas.deshacer();
$("rehacer").onclick = () => islas.rehacer();
$("como-queda").onclick = () => islas.alternarQueda();
$("borrar-todo").onclick = () => islas.borrarTodo();
$("guardar").onclick = guardar;
$("regenerar").onclick = () => pedirRegenerar();
$("estado-imagen").onchange = (e) => (e.target.value === "regenerar" ? (pedirRegenerar("imagen"), pintarPanelSinVideo()) : estadoImagen(e.target.value));
$("nota-imagen").onchange = (e) => estadoImagen(E.detalle.imagen.estado, e.target.value);
for (const b of document.querySelectorAll("[data-video]")) b.onclick = () => (b.dataset.video === "regenerar" ? pedirRegenerar("video") : estadoVideo(b.dataset.video, $("nota-video").value));
$("nota-video").onchange = (e) => estadoVideo(E.detalle.video.estado, e.target.value);
$("video-cual").onchange = cargarVideo;
$("video-fondo").onchange = pintarFondoVideo;
$("procesar-video").onclick = async () => {
  try {
    const { datos } = await postJSON(`/api/procesar-video/${E.detalle.id}`, { menores: +$("menores").value || 0 });
    seguirVideo(datos.trabajo);
  } catch (error) { avisar(error.message, true); }
};
$("btn-importar").onclick = () => abrirImportar();
$("btn-aplicar").onclick = () => abrirAplicar().catch((e) => avisar(e.message, true));
$("btn-ayuda").onclick = () => $("dlg-ayuda").showModal();
$("aplicar-ok").onclick = async (ev) => {
  ev.preventDefault();
  if (!confirm("¿Aplicar en una rama nueva? No toca tu copia del juego.")) return;
  try { const { datos } = await postJSON("/api/aplicar", { confirmar: true }); seguirAplicar(datos.trabajo); }
  catch (error) { avisar(error.message, true); }
};
$("imp-ok").onclick = (ev) => { ev.preventDefault(); importar(); };
$("archivo").onchange = (e) => e.target.files[0] && elegirArchivo(e.target.files[0]);
$("imp-personaje").oninput = componerId;
$("imp-skin").oninput = componerId;
$("imp-id").oninput = avisoImportar;
const soltar = $("soltar");
soltar.ondragover = (e) => { e.preventDefault(); soltar.classList.add("encima"); };
soltar.ondragleave = () => soltar.classList.remove("encima");
soltar.ondrop = (e) => { e.preventDefault(); soltar.classList.remove("encima"); if (e.dataTransfer.files[0]) elegirArchivo(e.dataTransfer.files[0]); };
// Soltar un archivo en cualquier lado abre el importador.
document.addEventListener("dragover", (e) => { if (e.dataTransfer?.types?.includes("Files")) e.preventDefault(); });
document.addEventListener("drop", (e) => {
  if (!e.dataTransfer?.files?.length || $("dlg-importar").open) return;
  e.preventDefault();
  abrirImportar(e.dataTransfer.files[0]);
});

document.addEventListener("keydown", (ev) => {
  const cmd = ev.metaKey || ev.ctrlKey;
  if (cmd && ev.key.toLowerCase() === "s") { ev.preventDefault(); guardar(); return; }
  if (document.querySelector("dialog[open]") || escribiendo()) return;
  if (cmd && ev.key.toLowerCase() === "z") { ev.preventDefault(); ev.shiftKey ? islas.rehacer() : islas.deshacer(); return; }
  if (cmd) return;
  switch (ev.key) {
    case "ArrowLeft": case "ArrowUp": ev.preventDefault(); mover(-1); break;
    case "ArrowRight": case "ArrowDown": ev.preventDefault(); mover(1); break;
    case " ": ev.preventDefault(); espacio = true; break;
    case "1": elegirHerramienta("rojo"); break;
    case "2": elegirHerramienta("verde"); break;
    case "p": case "P": elegirHerramienta("pincel"); break;
    case "g": case "G": elegirHerramienta("goma"); break;
    case "[": cambiarTamano(islas.radio / 1.25); break;
    case "]": cambiarTamano(islas.radio * 1.25 + 1); break;
    case "c": case "C": if (E.paso === 2) islas.alternarQueda(); break;
    case "f": case "F": vistaActual().ajustar(); break;
    case "?": $("dlg-ayuda").showModal(); break;
  }
});
document.addEventListener("keyup", (ev) => { if (ev.key === " ") espacio = false; });
window.addEventListener("blur", () => (espacio = false));

// ---------- arranque ----------
(async function arrancar() {
  elegirHerramienta("rojo");
  cambiarTamano(12);
  try {
    await cargarAssets();
  } catch (error) {
    avisar("No pude hablar con el servidor: ¿está abierta la ventanita negra?", true);
    return;
  }
  const ultimo = leerLocal("estudio-ultimo");
  const primero = (ultimo && E.porId.get(ultimo)) || E.visibles.find((a) => a.estado_imagen === "sin revisar") || E.visibles[0];
  if (primero) abrir(primero.id);
})();
