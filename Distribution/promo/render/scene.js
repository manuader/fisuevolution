'use strict';
// FisuEvolution — reel promocional 9:16.
// Escena determinística: drawAt(t) dibuja el frame del segundo t sin estado,
// así cualquier worker puede renderizar cualquier rango de frames.
// Unidades lógicas 1080×1920; ?scale=2 renderiza 2160×3840.

const W = 1080, H = 1920, DURATION = 30;
const BEAT = 0.5; // 120 BPM
const params = new URLSearchParams(location.search);
const SCALE = parseFloat(params.get('scale') || '1');
const FPS = parseFloat(params.get('fps') || '60');

const cv = document.getElementById('cv');
cv.width = Math.round(W * SCALE); cv.height = Math.round(H * SCALE);
const mainCtx = cv.getContext('2d');
const buf = document.createElement('canvas');
buf.width = cv.width; buf.height = cv.height;
const bufCtx = buf.getContext('2d');
let g = mainCtx;

const C = {
  ink: '#2C2C2C', cream: '#FFF8E7', yellow: '#FFD93D', orange: '#FF6B35', pink: '#FF4D6D',
  blue: '#4D96FF', green: '#6BCB77', parch: '#F1E5C9', brown: '#7A4E26',
};
const CONFETTI = [C.yellow, C.orange, C.pink, C.blue, C.green, C.cream];

// ───────────────────────────── assets ─────────────────────────────
const RES = '/FisuEvolution/Resources/';
const COSMIC = ['dueno_luna', 'dueno_marte', 'rey_asteroides', 'magnate_solar', 'fondo_buitre', 'rentista_soles',
  'estanciero_estelar', 'senor_galaxia', 'coleccionista_galaxias', 'emperador_cosmico', 'ser_ascendido',
  'semidios', 'deidad', 'god'];
const TIERS = [
  ['homeless', 'El Fisura', 1], ['trapito', 'El Trapito', 2], ['limpiavidrios', 'Limpiavidrios', 3],
  ['cartonero', 'Cartonero', 4], ['mantero', 'El Mantero', 5], ['repartidor', 'Repartidor', 6],
  ['chofer_app', 'Chofer de App', 7], ['fast_food', 'Empleado de Fast Food', 8], ['oficinista', 'Oficinista', 9],
  ['administrativo', 'Administrativo', 10], ['junior_programmer', 'Programador Jr.', 11],
  ['junior_architect', 'Arquitecto Jr.', 11], ['junior_doctor', 'Médico Jr.', 11], ['junior_lawyer', 'Abogado Jr.', 11],
  ['senior_programmer', 'Programador Sr.', 12], ['director', 'Director', 13], ['fundador_startup', 'Fundador de Startup', 14],
  ['dueno_pyme', 'Dueño de PYME', 15], ['emprendedor', 'Emprendedor', 16], ['ceo', 'CEO', 17],
  ['millonario', 'Millonario', 18], ['multimillonario', 'Multimillonario', 19], ['rey_ladrillo', 'Rey del Ladrillo', 20],
  ['magnate_petrolero', 'Magnate Petrolero', 21], ['space_billionaire', 'Space Billionaire', 22],
  ['trillonario', 'Trillonario', 23], ['dueno_luna', 'Dueño de la Luna', 24], ['dueno_marte', 'Dueño de Marte', 25],
  ['rey_asteroides', 'Rey de los Asteroides', 26], ['magnate_solar', 'Magnate del Sistema Solar', 27],
  ['fondo_buitre', 'Fondo Buitre Estelar', 28], ['rentista_soles', 'Rentista de Soles', 29],
  ['estanciero_estelar', 'Estanciero Estelar', 30], ['senor_galaxia', 'Señor de la Galaxia', 31],
  ['coleccionista_galaxias', 'Coleccionista de Galaxias', 32], ['emperador_cosmico', 'Emperador Cósmico', 33],
  ['ser_ascendido', 'Ser Ascendido', 34], ['semidios', 'Semidiós', 35], ['deidad', 'Deidad', 36], ['god', 'Dios', 37],
];
const TIER = Object.fromEntries(TIERS.map(([id, name, n]) => [id, { name, n }]));
const FACE_IDS = TIERS.map(t => t[0]).filter(id => !id.startsWith('junior_') && !id.startsWith('senior_') || id === 'junior_programmer');

const IMG = {};
function charPath(id) {
  return RES + (COSMIC.includes(id) ? 'cosmic.atlas/' : 'earth.atlas/') + id + '_idle@3x.png';
}
function assetList() {
  const L = {
    hero: '/Distribution/promo/render/assets/hero_fisura.png',
    logo: RES + 'ui.atlas/logo@3x.png',
    coin: RES + 'ui.atlas/ui_coin@3x.png',
    fx_merge: RES + 'ui.atlas/fx_merge@3x.png',
    fx_tap: RES + 'ui.atlas/fx_tap@3x.png',
    fx_evo: RES + 'ui.atlas/fx_evolution_flash@3x.png',
    star: RES + 'ui.atlas/fx_unlock@3x.png',
    dollar: RES + 'ui.atlas/ui_dollar@3x.png',
    btn_buy: RES + 'ui.atlas/ui_btn_buy@3x.png',
    celebrate: RES + 'ui.atlas/fisura_celebrate@3x.png',
  };
  for (const b of ['alley', 'urban', 'corporate', 'luxury', 'moon', 'mars', 'solar', 'galaxy', 'god_realm'])
    L['bg_' + b] = RES + 'Backgrounds/bg_' + b + '@3x.png';
  for (const [id] of TIERS) L[id] = charPath(id);
  for (const id of FACE_IDS) L['face_' + id] = RES + 'ui.atlas/' + id + '_face@3x.png';
  return L;
}
function loadImage(src) {
  return new Promise((res, rej) => {
    const im = new Image();
    im.onload = () => res(im);
    im.onerror = () => rej(new Error('no carga ' + src));
    im.src = src;
  });
}
// Caja del contenido opaco: los sprites vienen en 512² con aire alrededor,
// así los pies apoyan exactos y las alturas se comparan en pantalla.
function trimBox(im) {
  const c = document.createElement('canvas');
  c.width = im.width; c.height = im.height;
  const x = c.getContext('2d');
  x.drawImage(im, 0, 0);
  const d = x.getImageData(0, 0, c.width, c.height).data;
  let x0 = c.width, y0 = c.height, x1 = 0, y1 = 0;
  for (let y = 0; y < c.height; y++) for (let i = 0; i < c.width; i++) {
    if (d[(y * c.width + i) * 4 + 3] > 24) {
      if (i < x0) x0 = i; if (i > x1) x1 = i; if (y < y0) y0 = y; if (y > y1) y1 = y;
    }
  }
  return { x: x0, y: y0, w: x1 - x0 + 1, h: y1 - y0 + 1 };
}

// ───────────────────────────── math ─────────────────────────────
const cl = (x, a = 0, b = 1) => Math.max(a, Math.min(b, x));
const seg = (t, a, b) => cl((t - a) / (b - a));
const lerp = (a, b, t) => a + (b - a) * t;
const E = {
  lin: t => t,
  qOut: t => 1 - (1 - t) * (1 - t),
  cOut: t => 1 - Math.pow(1 - t, 3),
  cIn: t => t * t * t,
  cInOut: t => t < .5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2,
  expoOut: t => t >= 1 ? 1 : 1 - Math.pow(2, -10 * t),
  expoIn: t => t <= 0 ? 0 : Math.pow(2, 10 * t - 10),
  expoInOut: t => t <= 0 ? 0 : t >= 1 ? 1 : t < .5 ? Math.pow(2, 20 * t - 10) / 2 : (2 - Math.pow(2, -20 * t + 10)) / 2,
  backOut: (t, s = 1.9) => 1 + (s + 1) * Math.pow(t - 1, 3) + s * Math.pow(t - 1, 2),
  elasticOut: t => t <= 0 ? 0 : t >= 1 ? 1 : Math.pow(2, -10 * t) * Math.sin((t * 10 - .75) * (2 * Math.PI) / 3) + 1,
};
function rng(seed) {
  let a = seed >>> 0;
  return () => {
    a |= 0; a = a + 0x6D2B79F5 | 0;
    let t = Math.imul(a ^ a >>> 15, 1 | a);
    t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t;
    return ((t ^ t >>> 14) >>> 0) / 4294967296;
  };
}
// Ruido suave 1D determinístico (para drift de cámara y shake).
function noise(x, s = 0) {
  return Math.sin(x * 1.7 + s) * .5 + Math.sin(x * 3.1 + s * 2.3) * .3 + Math.sin(x * 5.3 + s * 4.1) * .2;
}

// Impactos: cada uno sacude la cámara con decaimiento exponencial.
const IMPACTS = [];
function impact(t, amp) { IMPACTS.push([t, amp]); }
function shakeAt(t) {
  let x = 0, y = 0, r = 0;
  for (const [ti, a] of IMPACTS) {
    const d = t - ti;
    if (d < 0 || d > .6) continue;
    const k = a * Math.exp(-d * 10);
    x += k * noise(d * 40, ti * 7);
    y += k * noise(d * 40, ti * 13 + 1);
    r += k * .0012 * noise(d * 30, ti * 3 + 2);
  }
  return { x, y, r };
}

// ───────────────────────────── primitives ─────────────────────────────
const GLOW = {};
function makeGlow(color) {
  const s = 256, c = document.createElement('canvas');
  c.width = c.height = s;
  const x = c.getContext('2d');
  const gr = x.createRadialGradient(s / 2, s / 2, 0, s / 2, s / 2, s / 2);
  gr.addColorStop(0, color); gr.addColorStop(.25, color.replace(/[\d.]+\)$/, '0.55)'));
  gr.addColorStop(1, color.replace(/[\d.]+\)$/, '0)'));
  x.fillStyle = gr; x.fillRect(0, 0, s, s);
  return c;
}
function glow(name, x, y, r, a = 1) {
  if (a <= 0 || r <= 0) return;
  g.save();
  g.globalCompositeOperation = 'lighter';
  g.globalAlpha = cl(a);
  g.drawImage(GLOW[name], x - r, y - r, r * 2, r * 2);
  g.restore();
}

function rr(x, y, w, h, r) {
  g.beginPath();
  g.moveTo(x + r, y);
  g.arcTo(x + w, y, x + w, y + h, r);
  g.arcTo(x + w, y + h, x, y + h, r);
  g.arcTo(x, y + h, x, y, r);
  g.arcTo(x, y, x + w, y, r);
  g.closePath();
}

// Fondo "cover" de 1536² sobre el vertical, con zoom/paneo de parallax.
function drawBg(img, o = {}) {
  const z = o.zoom || 1, s = H / img.height * z;
  const w = img.width * s, h = img.height * s;
  g.save();
  g.globalAlpha = o.alpha == null ? 1 : o.alpha;
  g.translate(W / 2 + (o.x || 0), H / 2 + (o.y || 0));
  g.rotate(o.rot || 0);
  g.drawImage(img, -w / 2, -h / 2, w, h);
  g.restore();
}

// Personaje apoyado por los pies en (x, y), alto h. Squash & stretch desde los pies.
function drawChar(id, x, y, h, o = {}) {
  const im = IMG[id];
  if (!im) return;
  const bb = im.bb;
  const w = h * bb.w / bb.h;
  const sx = o.sx == null ? 1 : o.sx, sy = o.sy == null ? 1 : o.sy;
  const a = o.alpha == null ? 1 : o.alpha;
  if (a <= 0) return;
  g.save();
  g.translate(x, y);
  if (o.shadow !== false) {
    g.save();
    g.globalAlpha = a * .35;
    g.fillStyle = '#000';
    g.beginPath();
    g.ellipse(0, 0, w * .38 * sx, h * .035, 0, 0, Math.PI * 2);
    g.fill();
    g.restore();
  }
  g.rotate(o.rot || 0);
  g.scale(sx, sy);
  g.globalAlpha = a;
  if (o.flip) g.scale(-1, 1);
  g.drawImage(im, bb.x, bb.y, bb.w, bb.h, -w / 2, -h, w, h);
  if (o.white > 0) {
    // Destello blanco sobre la silueta (el "flash" del merge): se tiñe una copia.
    const tc = tint(id, '#FFFFFF');
    g.globalAlpha = a * cl(o.white);
    g.drawImage(tc, 0, 0, tc.width, tc.height, -w / 2, -h, w, h);
  }
  g.restore();
}
const TINT = {};
function tint(id, color) {
  const key = id + color;
  if (TINT[key]) return TINT[key];
  const im = IMG[id], bb = im.bb;
  const c = document.createElement('canvas');
  c.width = bb.w; c.height = bb.h;
  const x = c.getContext('2d');
  x.drawImage(im, bb.x, bb.y, bb.w, bb.h, 0, 0, bb.w, bb.h);
  x.globalCompositeOperation = 'source-in';
  x.fillStyle = color; x.fillRect(0, 0, bb.w, bb.h);
  return (TINT[key] = c);
}

function drawImg(img, x, y, size, o = {}) {
  const a = o.alpha == null ? 1 : o.alpha;
  if (a <= 0) return;
  const w = size * (o.sx || 1), h = size * img.height / img.width * (o.sy || 1);
  g.save();
  g.translate(x, y);
  g.rotate(o.rot || 0);
  g.globalAlpha = a;
  if (o.add) g.globalCompositeOperation = 'lighter';
  g.drawImage(img, -w / 2, -h / 2, w, h);
  g.restore();
}

// Rayos de luz girando (aditivos).
function rays(x, y, n, rot, len, color, a, width = .5) {
  if (a <= 0) return;
  g.save();
  g.translate(x, y);
  g.rotate(rot);
  g.globalCompositeOperation = 'lighter';
  const gr = g.createRadialGradient(0, 0, 0, 0, 0, len);
  gr.addColorStop(0, color.replace(/[\d.]+\)$/, a + ')'));
  gr.addColorStop(1, color.replace(/[\d.]+\)$/, '0)'));
  g.fillStyle = gr;
  const step = Math.PI * 2 / n;
  g.beginPath();
  for (let i = 0; i < n; i++) {
    const a0 = i * step, a1 = a0 + step * width;
    g.moveTo(0, 0);
    g.arc(0, 0, len, a0, a1);
    g.closePath();
  }
  g.fill();
  g.restore();
}

// Sunburst de la marca (mismo lenguaje que fx_merge / fx_evolution_flash).
function sunburst(x, y, n, rot, c1, c2, len = 2600) {
  g.save();
  g.translate(x, y);
  g.fillStyle = c1;
  g.fillRect(-len, -len, len * 2, len * 2);
  g.rotate(rot);
  g.fillStyle = c2;
  const step = Math.PI * 2 / n;
  g.beginPath();
  for (let i = 0; i < n; i += 2) {
    g.moveTo(0, 0);
    g.arc(0, 0, len, i * step, (i + 1) * step);
    g.closePath();
  }
  g.fill();
  g.restore();
}

// ─── partículas analíticas: posición = f(edad), nada acumulado entre frames ───
function burst(t, b) {
  const age = t - b.t0;
  if (age < 0) return;
  const r = rng(b.seed);
  const ang = b.ang || [0, Math.PI * 2];
  for (let i = 0; i < b.n; i++) {
    const a = lerp(ang[0], ang[1], r());
    const s = lerp(b.spd[0], b.spd[1], r());
    const life = lerp(b.life[0], b.life[1], r());
    const size = lerp(b.size[0], b.size[1], r());
    const ph = r() * 6.283, spin = lerp(3, 11, r()) * (r() < .5 ? -1 : 1);
    const delay = (b.delay || 0) * r();
    const col = (b.colors || CONFETTI)[Math.floor(r() * (b.colors || CONFETTI).length)];
    const ox = (b.spread || 0) * (r() - .5), oy = (b.spreadY || 0) * (r() - .5);
    const ag = age - delay;
    if (ag < 0 || ag > life) continue;
    const k = b.drag || 0;
    const f = k ? (1 - Math.exp(-k * ag)) / k : ag;
    const x = b.x + ox + Math.cos(a) * s * f;
    const y = b.y + oy + Math.sin(a) * s * f + .5 * (b.grav || 0) * ag * ag;
    const lp = ag / life;
    const fade = lp > .7 ? 1 - (lp - .7) / .3 : 1;
    const z = 1 + (b.zoom || 0) * ag;
    switch (b.kind) {
      case 'coin': {
        const im = IMG.coin, sz = size * z;
        g.save();
        g.translate(x, y);
        g.rotate(ph * .3);
        g.scale(Math.max(.08, Math.abs(Math.cos(ph + spin * ag))), 1);
        g.globalAlpha = fade;
        g.drawImage(im, -sz / 2, -sz / 2, sz, sz);
        g.restore();
        break;
      }
      case 'bill': {
        const im = IMG.dollar, sz = size * z;
        g.save();
        g.translate(x, y);
        g.rotate(ph + spin * .25 * ag);
        g.scale(1, Math.max(.15, Math.abs(Math.cos(ph + spin * .6 * ag))));
        g.globalAlpha = fade;
        g.drawImage(im, -sz / 2, -sz / 2, sz, sz);
        g.restore();
        break;
      }
      case 'spark': {
        const e = k ? Math.exp(-k * ag) : 1;
        const vx = Math.cos(a) * s * e, vy = Math.sin(a) * s * e + (b.grav || 0) * ag;
        const tl = b.trail || .035;
        g.save();
        g.globalCompositeOperation = 'lighter';
        g.globalAlpha = fade;
        g.strokeStyle = b.color || 'rgba(255,230,140,1)';
        g.lineWidth = size * (1 - lp * .6);
        g.lineCap = 'round';
        g.beginPath();
        g.moveTo(x, y);
        g.lineTo(x - vx * tl, y - vy * tl);
        g.stroke();
        g.restore();
        break;
      }
      case 'confetti': {
        g.save();
        g.translate(x, y);
        g.rotate(ph + spin * ag);
        g.scale(1, Math.cos(ph * 2 + spin * 1.3 * ag));
        g.globalAlpha = fade;
        g.fillStyle = col;
        g.fillRect(-size / 2, -size / 4, size, size / 2);
        g.strokeStyle = C.ink; g.lineWidth = 2.5;
        g.strokeRect(-size / 2, -size / 4, size, size / 2);
        g.restore();
        break;
      }
      case 'star': {
        const tw = .6 + .4 * Math.sin(ph + ag * 14);
        drawImg(IMG.star, x, y, size * z * tw, { alpha: fade, rot: ph * .2 });
        break;
      }
      case 'dust': {
        glow(b.glow || 'gold', x, y, size * (.7 + .3 * Math.sin(ph + ag * 6)), fade * (b.alpha || .8));
        break;
      }
    }
  }
}

// ─── tipografía cinética: sticker de trazo de tinta, como el arte ───
const FONT_T = 'Baloo2', FONT_N = 'Nunito';
function goldFill(size) {
  const gr = g.createLinearGradient(0, -size * .45, 0, size * .3);
  gr.addColorStop(0, '#FFF6C2'); gr.addColorStop(.45, C.yellow); gr.addColorStop(1, '#FF9F1C');
  return gr;
}
// tin: segundos desde que entra; tout: segundos desde que sale (null = no sale).
function title(str, x, y, size, o = {}) {
  const tin = o.tin == null ? 99 : o.tin;
  if (tin < 0) return;
  const tout = o.tout;
  if (tout != null && tout > 1) return;
  g.save();
  g.font = `800 ${size}px ${o.font || FONT_T}`;
  g.textBaseline = 'middle';
  g.textAlign = 'center';
  const track = (o.track || 0) * size;
  const chars = [...str];
  const ws = chars.map(ch => g.measureText(ch).width);
  let total = ws.reduce((a, b) => a + b, 0) + track * (chars.length - 1);
  if (o.maxW && total > o.maxW) {
    size *= o.maxW / total;
    g.font = `800 ${size}px ${o.font || FONT_T}`;
    for (let i = 0; i < chars.length; i++) ws[i] = g.measureText(chars[i]).width;
    total = ws.reduce((a, b) => a + b, 0) + (o.track || 0) * size * (chars.length - 1);
  }
  const st = o.stagger == null ? .035 : o.stagger;
  const dur = o.dur || .42;
  const anim = o.anim || 'pop';
  let cx = x - total / 2;
  chars.forEach((ch, i) => {
    const w = ws[i];
    const lx = cx + w / 2;
    cx += w + (o.track || 0) * size;
    if (ch === ' ') return;
    const p = seg(tin, i * st, i * st + dur);
    if (p <= 0) return;
    let sc = 1, dy = 0, rot = 0, a = 1, dx = 0;
    if (anim === 'pop') {
      sc = E.backOut(p, 2.4); dy = (1 - E.expoOut(p)) * size * .55; rot = (1 - E.expoOut(p)) * .5 * (i % 2 ? 1 : -1);
    } else if (anim === 'slam') {
      sc = lerp(2.6, 1, E.expoOut(p)); a = cl(p * 4);
    } else if (anim === 'rise') {
      dy = (1 - E.expoOut(p)) * size * .9; a = cl(p * 3);
    }
    if (tout != null && tout > 0) {
      const q = seg(tout, i * st * .5, i * st * .5 + .22);
      const e = E.expoIn(q);
      sc *= 1 - e * .6; dy -= e * size * .7; a *= 1 - q;
    }
    if (o.wave) dy += Math.sin(tin * 5 - i * .5) * size * .03;
    if (a <= 0 || sc <= 0) return;
    g.save();
    g.translate(lx + dx, y + dy);
    g.rotate(rot + (o.rot || 0));
    g.scale(sc, sc);
    g.globalAlpha = a * (o.alpha == null ? 1 : o.alpha);
    g.lineJoin = 'round'; g.miterLimit = 2;
    const sw = size * (o.strokeK || .17);
    // sombra dura de tinta
    g.fillStyle = o.shadowColor || C.ink;
    g.strokeStyle = o.shadowColor || C.ink;
    g.lineWidth = sw;
    g.strokeText(ch, 0, size * .075);
    g.fillText(ch, 0, size * .075);
    g.strokeStyle = o.stroke || C.ink;
    g.strokeText(ch, 0, 0);
    g.fillStyle = o.gold ? goldFill(size) : (o.fill || C.cream);
    g.fillText(ch, 0, 0);
    g.restore();
  });
  g.restore();
}

// Pastilla caramelo (lenguaje v3 de la UI): relleno, borde marrón, brillo arriba.
function pill(x, y, w, h, o = {}) {
  g.save();
  g.translate(x, y);
  g.scale(o.sc || 1, o.sc || 1);
  g.globalAlpha = o.alpha == null ? 1 : o.alpha;
  rr(-w / 2, -h / 2 + 6, w, h, h / 2);
  g.fillStyle = 'rgba(0,0,0,.35)'; g.fill();
  rr(-w / 2, -h / 2, w, h, h / 2);
  g.fillStyle = o.fill || C.cream; g.fill();
  g.lineWidth = o.lw || 6; g.strokeStyle = o.stroke || C.brown; g.stroke();
  rr(-w / 2 + h * .22, -h / 2 + h * .12, w - h * .44, h * .22, h * .11);
  g.fillStyle = 'rgba(255,255,255,.45)'; g.fill();
  g.restore();
}

// Formato del HUD del juego (CoinFormatter.swift): 1500 → "1,5K", luego B/T y pares aa…
const SUFFIX = ['K', 'M', 'B', 'T'];
for (let a = 97; a <= 101; a++) for (let b = 97; b <= 122; b++) SUFFIX.push(String.fromCharCode(a) + String.fromCharCode(b));
function coinFmt(v) {
  if (v < 1000) return String(Math.floor(v));
  let i = -1;
  while (v >= 1000 && i < SUFFIX.length - 1) { v /= 1000; i++; }
  const s = v >= 100 ? Math.floor(v).toString() : (Math.floor(v * 10) / 10).toString().replace('.', ',');
  return s + SUFFIX[i];
}

// HUD de monedas (moneda + número), como el contador del juego.
function coinHud(x, y, value, o = {}) {
  const txt = coinFmt(value);
  g.save();
  g.font = `900 64px ${FONT_N}`;
  const tw = g.measureText(txt).width;
  const w = tw + 150, h = 96;
  const sc = o.sc || 1;
  g.translate(x, y);
  g.scale(sc, sc);
  pill(0, 0, w, h, { fill: C.cream, alpha: o.alpha });
  g.globalAlpha = o.alpha == null ? 1 : o.alpha;
  const bump = o.bump || 0;
  g.drawImage(IMG.coin, -w / 2 + 6 - bump * 6, -h / 2 - 8 - bump * 6, 110 + bump * 12, 110 + bump * 12);
  g.textAlign = 'left'; g.textBaseline = 'middle';
  g.fillStyle = C.ink;
  g.fillText(txt, -w / 2 + 122, 4);
  g.restore();
}

// Etiqueta de nivel + nombre bajo el personaje.
function tierTag(id, x, y, tin, o = {}) {
  if (tin < 0) return;
  const t = TIER[id];
  const p = E.backOut(seg(tin, 0, .28), 2.2);
  g.save();
  g.translate(x, y);
  g.scale(p, p);
  g.font = `800 58px ${FONT_T}`;
  const name = t.name.toUpperCase();
  const nw = Math.min(g.measureText(name).width, 820);
  const w = nw + 70, h = 88;
  pill(0, 0, w, h, { fill: C.cream });
  g.fillStyle = C.ink; g.textAlign = 'center'; g.textBaseline = 'middle';
  g.fillText(name, 0, 5, 820);
  // chapita de nivel encima
  const lv = 'NIVEL ' + t.n;
  g.font = `900 36px ${FONT_N}`;
  const lw = g.measureText(lv).width + 44;
  g.translate(0, -h / 2 - 12);
  g.rotate(-.04);
  rr(-lw / 2, -24, lw, 48, 24);
  g.fillStyle = o.lvColor || C.orange; g.fill();
  g.lineWidth = 5; g.strokeStyle = C.ink; g.stroke();
  g.fillStyle = C.cream; g.fillText(lv, 0, 2);
  g.restore();
}

// Indicador de toque (círculo blanco con borde) para mostrar la interacción.
function touch(x, y, press, a = 1) {
  if (a <= 0) return;
  g.save();
  g.globalAlpha = a;
  const r = 46 * (1 - press * .18);
  g.beginPath(); g.arc(x, y, r, 0, Math.PI * 2);
  g.fillStyle = 'rgba(255,255,255,.55)'; g.fill();
  g.lineWidth = 7; g.strokeStyle = C.ink; g.stroke();
  if (press > 0) {
    g.beginPath(); g.arc(x, y, r + 30 * press, 0, Math.PI * 2);
    g.lineWidth = 5; g.strokeStyle = `rgba(255,255,255,${.8 * (1 - press)})`; g.stroke();
  }
  g.restore();
}

function flash(a, color = '#FFFFFF') {
  if (a <= 0) return;
  g.save();
  g.globalAlpha = cl(a);
  g.fillStyle = color;
  g.fillRect(-200, -200, W + 400, H + 400);
  g.restore();
}
function shade(a, color = '#000') { flash(a, color); }

// Badge oficial "Descárgalo en el App Store" (negro, borde gris, logo + texto).
const APPLE = new Path2D('M12.152 6.896c-.948 0-2.415-1.078-3.96-1.04-2.04.027-3.91 1.183-4.961 3.014-2.117 3.675-.546 9.103 1.519 12.09 1.013 1.454 2.208 3.09 3.792 3.039 1.52-.065 2.09-.987 3.935-.987 1.831 0 2.35.987 3.96.948 1.637-.026 2.676-1.48 3.676-2.948 1.156-1.688 1.636-3.325 1.662-3.415-.039-.013-3.182-1.221-3.22-4.857-.026-3.04 2.48-4.494 2.597-4.559-1.429-2.09-3.623-2.324-4.39-2.376-2-.156-3.675 1.09-4.61 1.09zM15.53 3.83c.843-1.012 1.4-2.427 1.245-3.83-1.207.052-2.662.805-3.532 1.818-.78.896-1.454 2.338-1.273 3.714 1.338.104 2.715-.688 3.559-1.701');
function appStoreBadge(x, y, w, sc = 1, a = 1) {
  const h = w * 40 / 120;
  g.save();
  g.translate(x, y);
  g.scale(sc, sc);
  g.globalAlpha = a;
  rr(-w / 2, -h / 2, w, h, h * .2);
  g.fillStyle = '#000'; g.fill();
  g.lineWidth = w * .008; g.strokeStyle = '#A6A6A6'; g.stroke();
  g.save();
  const ls = h * .6 / 24;
  g.translate(-w / 2 + h * .28, -h * .31);
  g.scale(ls, ls);
  g.fillStyle = '#fff'; g.fill(APPLE);
  g.restore();
  g.fillStyle = '#fff'; g.textAlign = 'left'; g.textBaseline = 'alphabetic';
  g.font = `600 ${h * .2}px Inter`;
  g.fillText('Descárgalo en el', -w / 2 + h * .98, -h * .06);
  g.font = `600 ${h * .38}px Inter`;
  g.fillText('App Store', -w / 2 + h * .94, h * .3, w - h * 1.1);
  g.restore();
}

// ───────────────────────────── escena ─────────────────────────────
const CX = 540, FLOOR = 1340, CH = 800;

// Merges de la mecánica (acto 2): [split, hit, de, a].
const MERGES = [
  [4.0, 4.75, 'homeless', 'trapito'],
  [5.55, 6.25, 'trapito', 'limpiavidrios'],
  [6.8, 7.25, 'limpiavidrios', 'cartonero'],
  [7.45, 7.75, 'cartonero', 'mantero'],
];
const TAPS = [3.0, 3.25, 3.5, 3.75];

// Montaje (acto 3): [t, id, fondo].
const MONTAGE = [
  [8.0, 'repartidor', 'urban'], [8.5, 'chofer_app', 'urban'], [9.0, 'fast_food', 'urban'],
  [9.5, 'oficinista', 'urban'], [10.0, 'administrativo', 'urban'],
  // 10.5–12.0: elegí tu carrera
  [12.0, 'senior_programmer', 'corporate'], [12.5, 'director', 'corporate'], [12.75, 'fundador_startup', 'corporate'],
  [13.0, 'emprendedor', 'corporate'], [13.25, 'ceo', 'corporate'],
  [13.5, 'millonario', 'luxury'], [13.75, 'multimillonario', 'luxury'], [14.0, 'rey_ladrillo', 'luxury'],
  [14.25, 'magnate_petrolero', 'luxury'], [14.5, 'space_billionaire', 'luxury'], [14.75, 'trillonario', 'luxury'],
  [15.0, 'dueno_luna', 'moon'], [15.5, 'dueno_marte', 'mars'], [15.75, 'rey_asteroides', 'mars'],
  [16.0, 'magnate_solar', 'solar'], [16.125, 'fondo_buitre', 'solar'], [16.25, 'rentista_soles', 'solar'],
  [16.375, 'estanciero_estelar', 'galaxy'], [16.5, 'senor_galaxia', 'galaxy'], [16.625, 'coleccionista_galaxias', 'galaxy'],
  [16.75, 'emperador_cosmico', 'galaxy'], [16.8125, 'ser_ascendido', 'galaxy'], [16.875, 'semidios', 'galaxy'],
  [16.9375, 'deidad', 'galaxy'],
];
const CAREERS = ['junior_programmer', 'junior_architect', 'junior_doctor', 'junior_lawyer'];
const CAREER_NAMES = ['PROGRAMADOR', 'ARQUITECTO', 'MÉDICO', 'ABOGADO'];

function setupImpacts() {
  impact(0, 34); impact(.8, 26);
  for (const tt of TAPS) impact(tt, 6);
  for (const [, hit] of MERGES) impact(hit, 30);
  for (const [t] of MONTAGE) if (t < 16) impact(t, 12);
  impact(12.0, 22); impact(15.0, 26);
  impact(19.0, 44); impact(23.0, 40); impact(24.45, 10); impact(25.65, 16); impact(26.8, 24);
}

// ── Acto 1 · Hook (0–3 s) ──
function sceneHook(t) {
  const sh = shakeAt(t);
  // callejón porteño de fondo
  const bz = t < .8 ? 1.5 - t * .12 : lerp(1.42, 1.08, E.expoOut(seg(t, .8, 1.9))) + seg(t, 1.9, 3) * .06;
  g.save();
  g.translate(sh.x, sh.y);
  drawBg(IMG.bg_alley, { zoom: bz, y: 60 });
  shade(.35 + .15 * (t < .8 ? 1 : 0));
  // luz cálida del farol
  glow('warm', 250, 380, 520, .55 + .1 * Math.sin(t * 23) * (t < 1.2 ? 1 : 0));
  if (t < .8) {
    // Macro: los ojos del Fisura llenan el cuadro (hero de 2048 px).
    const im = IMG.hero;
    const s = lerp(3.3, 2.7, E.cOut(seg(t, 0, .8)));
    const ex = 338, ey = 520; // entre los ojos, en coords del recorte
    g.save();
    g.translate(CX + noise(t * 2, 3) * 8, 900);
    g.rotate(-.05 + t * .04);
    g.drawImage(im, -ex * s, -ey * s, im.width * s, im.height * s);
    g.restore();
  } else {
    // Plano entero con el sprite del juego, zoom-out dramático.
    const p = E.expoOut(seg(t, .8, 1.7));
    const z = lerp(1.9, 1, p) + E.expoIn(seg(t, 2.55, 3)) * .5;
    const bob = Math.sin(t * Math.PI * 2) * 6;
    g.save();
    g.translate(CX, FLOOR);
    g.scale(z, z);
    g.translate(-CX, -FLOOR);
    const land = seg(t, .8, 1.0);
    const sq = 1 - Math.sin(land * Math.PI) * .08;
    drawChar('homeless', CX, FLOOR + 10, CH, { sy: sq + bob * .002, sx: 1 / sq });
    g.restore();
  }
  g.restore();
  // monedas explotando hacia cámara
  burst(t, { t0: 0, x: CX, y: 2050, n: 46, seed: 11, kind: 'coin', spd: [2600, 4200], ang: [-Math.PI * .72, -Math.PI * .28], grav: 3000, life: [1.3, 1.9], size: [80, 150], drag: .5, zoom: 1.1, spread: 900, delay: .25 });
  burst(t, { t0: 0, x: CX, y: 1150, n: 60, seed: 12, kind: 'spark', spd: [1200, 3200], grav: 900, life: [.35, .7], size: [6, 12], drag: 3 });
  burst(t, { t0: .8, x: CX, y: 950, n: 40, seed: 13, kind: 'coin', spd: [600, 1900], ang: [-Math.PI, 0], grav: 2400, life: [1.2, 1.8], size: [60, 110], drag: .5, zoom: .5 });
  // lluvia de monedas desde arriba
  burst(t, { t0: 1.0, x: CX, y: -120, n: 40, seed: 14, kind: 'coin', spd: [100, 300], ang: [Math.PI * .3, Math.PI * .7], grav: 1400, life: [1.6, 2.2], size: [50, 95], spread: 1100, delay: 1.6 });
  // texto
  title('DE FISURA…', CX, 360, 170, { tin: t - .12, tout: t - 2.72, stagger: .045, maxW: 960 });
  flash(1 - seg(t, 0, .12));
  flash((1 - seg(t, .8, .9)) * (t >= .8 ? 1 : 0));
  // viñeta de enfoque
}

// ── Acto 2 · Mecánica (3–8 s): tap + merges ──
function mergeState(t) {
  // Devuelve qué dibujar: [{id,x,sx,sy,rot,white}], y la última fusión ocurrida.
  let cur = 'homeless', lastHit = -9;
  for (const [split, hit, from, to] of MERGES) {
    if (t < split) break;
    const d = hit - split;
    if (t < hit) {
      const p1 = E.expoOut(seg(t, split, split + .35 * d));
      const p2 = E.cOut(seg(t, split + .35 * d, split + .7 * d));
      const p3 = E.expoIn(seg(t, split + .7 * d, hit));
      const D = 250;
      let off = lerp(0, D, p1) + p2 * 30;
      off = lerp(off, 20, p3);
      const stretch = p3 * .25 - p2 * .08 + (1 - p1) * p1 * .6;
      const white = p3 * .8;
      return { chars: [
        { id: from, x: CX - off, sx: 1 + stretch, sy: 1 / (1 + stretch), rot: -p2 * .12 + p3 * .2, white },
        { id: from, x: CX + off, sx: 1 + stretch, sy: 1 / (1 + stretch), rot: p2 * .12 - p3 * .2, white, flip: true },
      ], lastHit, cur: from };
    }
    cur = to; lastHit = hit;
  }
  const since = t - lastHit;
  const pop = since < .5 ? E.elasticOut(seg(since, 0, .5)) : 1;
  const sy = since < .5 ? lerp(1.35, 1, E.elasticOut(seg(since, 0, .45))) : 1;
  return { chars: [{ id: cur, x: CX, sx: pop / sy * (since < .5 ? 1 : 1), sy: pop * sy, rot: 0, white: since < .2 ? 1 - since / .2 : 0 }], lastHit, cur };
}

function sceneMechanic(t) {
  const sh = shakeAt(t);
  const st = mergeState(t);
  // tap squash
  let tapSq = 0;
  for (const tt of TAPS) { const d = t - tt; if (d >= 0 && d < .2) tapSq = Math.max(tapSq, Math.sin(d / .2 * Math.PI) * .1); }
  const z = 1.08 + seg(t, 3, 8) * .08;
  g.save();
  g.translate(sh.x, sh.y);
  g.translate(CX, 960); g.rotate(sh.r + noise(t * .8, 5) * .01); g.scale(z, z); g.translate(-CX, -960);
  drawBg(IMG.bg_alley, { zoom: 1.15, x: -30 * seg(t, 3, 8), y: 60 });
  shade(.45);
  // aura detrás del personaje
  glow('gold', CX, 900, 560 + 30 * Math.sin(t * 6), .45);
  rays(CX, 900, 18, t * .3, 1000, 'rgba(255,217,61,1)', .12);
  for (const hit of MERGES.map(m => m[1])) {
    const d = t - hit;
    if (d >= 0 && d < 1.2) {
      rays(CX, 880, 14, d * .8 + hit, 1400 * E.expoOut(seg(d, 0, .4)), 'rgba(255,240,170,1)', .55 * (1 - d / 1.2), .45);
      glow('white', CX, 900, 700 * E.expoOut(seg(d, 0, .3)), 1 - d / .8);
    }
  }
  for (const c of st.chars) {
    drawChar(c.id, c.x, FLOOR, CH * .92, { sx: (c.sx || 1) * (1 + tapSq * .6), sy: (c.sy || 1) * (1 - tapSq), rot: c.rot, white: c.white, flip: c.flip });
  }
  // FX de los merges
  MERGES.forEach(([, hit], i) => {
    const d = t - hit;
    if (d >= 0 && d < .7) {
      drawImg(IMG.fx_merge, CX, 880, 300 + 900 * E.expoOut(seg(d, 0, .4)), { alpha: 1 - seg(d, .12, .5), rot: d * 2 });
      drawImg(IMG.fx_evo, CX, 880, 300 + 900 * E.expoOut(seg(d, 0, .3)), { alpha: 1 - seg(d, .1, .45), rot: -d * 3 });
    }
    burst(t, { t0: hit, x: CX, y: 880, n: 50, seed: 100 + i, kind: 'spark', spd: [1400, 3400], grav: 700, life: [.3, .6], size: [7, 13], drag: 3.2 });
    burst(t, { t0: hit, x: CX, y: 880, n: 22, seed: 200 + i, kind: 'coin', spd: [900, 2200], grav: 3000, life: [.9, 1.3], size: [60, 100], drag: 1.2 });
    burst(t, { t0: hit, x: CX, y: 880, n: 36, seed: 300 + i, kind: 'confetti', spd: [800, 2000], grav: 1600, life: [1, 1.5], size: [22, 34], drag: 2 });
  });
  g.restore();
  // taps: anillo, +1, dedo
  TAPS.forEach((tt, i) => {
    const d = t - tt;
    if (d >= 0 && d < .45) {
      drawImg(IMG.fx_tap, CX + 60, 820, 160 + 300 * E.expoOut(seg(d, 0, .4)), { alpha: 1 - seg(d, .15, .45) });
      const fy = 760 - 260 * E.expoOut(seg(d, 0, .45));
      g.save(); g.globalAlpha = 1 - seg(d, .25, .45);
      drawImg(IMG.coin, CX + 150, fy, 80);
      g.restore();
      title('+1', CX + 240, fy, 80, { tin: 99, font: FONT_N, alpha: 1 - seg(d, .25, .45), gold: true, strokeK: .2 });
    }
    burst(t, { t0: tt, x: CX + 60, y: 820, n: 10, seed: 400 + i, kind: 'coin', spd: [500, 1100], ang: [-Math.PI * .85, -Math.PI * .15], grav: 2600, life: [.6, .9], size: [40, 60] });
  });
  const tapA = 1 - seg(t, 3.85, 4.0);
  if (t < 4) {
    let press = 0;
    for (const tt of TAPS) { const d = t - tt; if (d >= 0 && d < .18) press = Math.max(press, 1 - d / .18); }
    touch(CX + 60 + (1 - E.expoOut(seg(t, 2.9, 3.0))) * 300, 820 + press * 6, press, tapA * E.expoOut(seg(t, 2.9, 3.05)));
  }
  // HUD de monedas
  let coins = 0, bump = 0;
  for (const tt of TAPS) if (t >= tt) { coins += 1; bump = Math.max(bump, 1 - (t - tt) / .15); }
  for (const [, hit] of MERGES) if (t >= hit) coins = coins * 2 + 25;
  const hudIn = E.backOut(seg(t, 3, 3.3));
  coinHud(CX, 250, coins, { sc: hudIn, bump: cl(bump) });
  // textos
  title('TAPEÁ', CX, 420, 150, { tin: t - 3.0, tout: t - 3.85, stagger: .03 });
  title('FUSIONÁ.', CX, 420, 185, { tin: t - 4.72, tout: t - 6.1, stagger: .03, anim: 'slam', dur: .3 });
  title('EVOLUCIONÁ.', CX, 420, 185, { tin: t - 6.22, tout: t - 7.9, stagger: .025, anim: 'slam', dur: .3, gold: true, maxW: 1000 });
  // etiqueta de nivel del resultado
  if (st.lastHit > 0 && t - st.lastHit >= 0 && st.chars.length === 1) tierTag(st.cur, CX, 1440, t - st.lastHit - .08);
  else if (t < 4.0) tierTag('homeless', CX, 1440, t - 3.1);
}

// ── Acto 3 · Montaje (8–17 s) ──
function montageAt(t) {
  let idx = -1;
  for (let i = 0; i < MONTAGE.length; i++) if (t >= MONTAGE[i][0]) idx = i;
  return idx;
}
function sceneMontage(t, o = {}) {
  const i = montageAt(t);
  if (i < 0) return;
  const [t0, id, bgName] = MONTAGE[i];
  const next = MONTAGE[i + 1] ? MONTAGE[i + 1][0] : 17;
  const d = t - t0;
  const sh = shakeAt(t);
  const punch = E.expoOut(seg(d, 0, .22));
  const bgZ = lerp(1.14, 1.04, punch) + (t - 8) * .004;
  const side = i % 2 ? 1 : -1;
  g.save();
  g.translate(sh.x, sh.y);
  g.translate(CX, 960);
  g.rotate(sh.r + noise(t * .6, 9) * .018);
  g.translate(-CX, -960);
  const space = ['moon', 'mars', 'solar', 'galaxy'].includes(bgName);
  drawBg(IMG['bg_' + bgName], { zoom: bgZ, x: side * 40 * (1 - punch) - (t - 8) * 12, y: space ? 120 : 60 });
  shade(space ? .2 : .32);
  // luz y rayos detrás
  const hue = space ? 'violet' : 'gold';
  glow(hue, CX, 880, 620, .5);
  rays(CX, 880, 16, t * .5 * side, 1300, space ? 'rgba(190,160,255,1)' : 'rgba(255,217,61,1)', .16);
  // eco del anterior (la evolución deja estela)
  if (i > 0 && d < .25 && MONTAGE[i - 1][0] > 10.4) {
    const pid = MONTAGE[i - 1][1];
    const e = seg(d, 0, .25);
    drawChar(pid, CX, FLOOR, CH * (1 + e * .35), { alpha: (1 - e) * .45, shadow: false, white: .6 });
  } else if (i > 0 && d < .25 && t >= 8.5 && t < 10.5) {
    const pid = MONTAGE[i - 1][1];
    const e = seg(d, 0, .25);
    drawChar(pid, CX, FLOOR, CH * (1 + e * .35), { alpha: (1 - e) * .45, shadow: false, white: .6 });
  }
  const sc = lerp(1.22, 1, punch);
  const sq = 1 + Math.sin(seg(d, 0, .18) * Math.PI) * .07;
  const bob = Math.sin((t - t0) * 7) * .01;
  drawChar(id, CX + side * 30 * (1 - punch), FLOOR, CH * sc, { sx: 1 / sq, sy: sq + bob, rot: side * .06 * (1 - punch), white: 1 - seg(d, 0, .1) });
  burst(t, { t0, x: CX, y: 860, n: 18, seed: 500 + i, kind: 'spark', spd: [1000, 2600], grav: 500, life: [.2, .4], size: [6, 10], drag: 3, color: space ? 'rgba(210,190,255,1)' : undefined });
  burst(t, { t0, x: CX, y: 880, n: 8, seed: 600 + i, kind: space ? 'star' : 'coin', spd: [700, 1600], grav: space ? 0 : 2400, life: [.45, .7], size: [40, 70], drag: 1.5 });
  g.restore();
  flash(.35 * (1 - seg(d, 0, .08)));
  tierTag(id, CX, 1440, next - t0 < .2 ? 1 : d, {});
  // HUD de plata que se dispara con la escalera
  const v = Math.pow(10, 3 + seg(t, 8, 17) * 40);
  coinHud(CX, 250, v, { bump: 1 - seg(d, 0, .12) });
}

function sceneCareer(t) {
  const sh = shakeAt(t);
  g.save();
  g.translate(sh.x, sh.y);
  drawBg(IMG.bg_corporate, { zoom: 1.1 + (t - 10.5) * .03 });
  shade(.55);
  glow('gold', CX, 900, 900, .35);
  const sel = 0;
  const zoomSel = E.expoIn(seg(t, 11.62, 12.0));
  CAREERS.forEach((id, i) => {
    const cx = CX + (i % 2 ? 215 : -215), cy = 800 + (i < 2 ? -20 : 480);
    const pin = E.backOut(seg(t, 10.52 + i * .07, 10.82 + i * .07), 2);
    if (pin <= 0) return;
    const isSel = i === sel;
    const chosen = seg(t, 11.3, 11.45);
    let x = cx, y = cy, s = pin * (1 + (isSel ? chosen * .08 : 0));
    let a = 1;
    if (!isSel) { a = 1 - chosen * .6 - zoomSel; y += zoomSel * 900 * (i < 2 ? -1 : 1); }
    if (isSel) { x = lerp(cx, CX, zoomSel); y = lerp(cy, 900, zoomSel); s *= lerp(1, 4.2, zoomSel); }
    if (a <= 0) return;
    g.save();
    g.translate(x, y);
    g.scale(s, s);
    g.rotate((i % 2 ? .02 : -.02) * (1 - zoomSel));
    g.globalAlpha = cl(a);
    const w = 390, h = 450;
    rr(-w / 2, -h / 2 + 10, w, h, 38); g.fillStyle = 'rgba(0,0,0,.4)'; g.fill();
    rr(-w / 2, -h / 2, w, h, 38); g.fillStyle = C.parch; g.fill();
    g.lineWidth = 9; g.strokeStyle = isSel && chosen > 0 ? C.orange : C.brown; g.stroke();
    if (isSel && chosen > 0) { g.lineWidth = 16 * chosen; g.strokeStyle = `rgba(255,107,53,${.35 * chosen})`; rr(-w / 2 - 10, -h / 2 - 10, w + 20, h + 20, 46); g.stroke(); }
    g.restore();
    g.save();
    g.globalAlpha = cl(a);
    g.translate(x, y); g.scale(s, s); g.translate(-x, -y);
    drawChar(id, x, y + 140, 330, { shadow: false });
    g.font = `800 44px ${FONT_T}`; g.textAlign = 'center'; g.textBaseline = 'middle';
    g.fillStyle = C.brown; g.fillText(CAREER_NAMES[i], x, y + 185);
    g.restore();
  });
  g.restore();
  title('ELEGÍ TU', CX, 290, 120, { tin: t - 10.5, tout: t - 11.6, stagger: .03 });
  title('CARRERA', CX, 410, 150, { tin: t - 10.62, tout: t - 11.62, stagger: .03, gold: true });
  const v = Math.pow(10, 3 + seg(t, 8, 17) * 40);
  coinHud(CX, 170, v, { alpha: 1 - zoomSel, sc: .8 });
  flash(zoomSel * seg(t, 11.9, 12.0));
}

// ── Acto 4 · Silencio + Dios (17–23 s) ──
function starfield(t, seed, n, a) {
  const r = rng(seed);
  for (let i = 0; i < n; i++) {
    const x = r() * W, y0 = r() * H, s = lerp(1.5, 5, r()), ph = r() * 6.28, sp = lerp(10, 60, r());
    const y = ((y0 - t * sp) % H + H) % H;
    g.globalAlpha = a * (.4 + .6 * Math.abs(Math.sin(ph + t * 1.3)));
    g.fillStyle = '#fff';
    g.fillRect(x, y, s, s);
  }
  g.globalAlpha = 1;
}
function galaxy(x, y, rot, scale, a) {
  if (a <= 0 || scale <= 0) return;
  const r = rng(77);
  g.save();
  g.translate(x, y);
  g.rotate(rot);
  g.scale(scale, scale * .62);
  g.globalCompositeOperation = 'lighter';
  const arms = 3;
  for (let i = 0; i < 1300; i++) {
    const arm = i % arms;
    const d = Math.pow(r(), .7);
    const ang = arm * Math.PI * 2 / arms + d * 5.2 + (r() - .5) * .55 * (1 - d * .4);
    const rad = d * 620;
    const px = Math.cos(ang) * rad + (r() - .5) * 30, py = Math.sin(ang) * rad + (r() - .5) * 30;
    const s = lerp(2, 7, r()) * (1.2 - d);
    const c = r();
    g.globalAlpha = a * (1 - d * .65) * .85;
    g.fillStyle = c < .35 ? '#FFE9A8' : c < .7 ? '#C9A2FF' : c < .85 ? '#8FB8FF' : '#FFFFFF';
    g.fillRect(px - s / 2, py - s / 2, s, s);
  }
  g.globalAlpha = a;
  g.drawImage(GLOW.white, -220, -220, 440, 440);
  g.drawImage(GLOW.gold, -380, -380, 760, 760);
  g.restore();
}
let CLOUDS = null;
function makeClouds() {
  // Nubes delanteras: la franja baja del propio bg_god_realm con fundido arriba.
  const im = IMG.bg_god_realm;
  const c = document.createElement('canvas');
  c.width = im.width; c.height = Math.round(im.height * .45);
  const x = c.getContext('2d');
  x.drawImage(im, 0, im.height - c.height, im.width, c.height, 0, 0, c.width, c.height);
  x.globalCompositeOperation = 'destination-in';
  const gr = x.createLinearGradient(0, 0, 0, c.height);
  gr.addColorStop(0, 'rgba(0,0,0,0)'); gr.addColorStop(.35, 'rgba(0,0,0,1)'); gr.addColorStop(1, 'rgba(0,0,0,1)');
  x.fillStyle = gr; x.fillRect(0, 0, c.width, c.height);
  CLOUDS = c;
}
function sceneSilence(t) {
  g.fillStyle = '#05040A'; g.fillRect(0, 0, W, H);
  starfield(t, 5, 160, seg(t, 17.0, 17.6));
  burst(t, { t0: 17.0, x: CX, y: 1900, n: 40, seed: 900, kind: 'dust', spd: [40, 120], ang: [-Math.PI * .6, -Math.PI * .4], life: [3, 4], size: [16, 40], spread: 900, delay: 1.2, alpha: .5 });
  // amanece desde abajo
  const up = seg(t, 17.7, 18.5);
  if (up > 0) {
    const s = H / IMG.bg_god_realm.height * 1.2;
    const by = lerp(1100, 700, E.cInOut(up));
    drawBg(IMG.bg_god_realm, { zoom: 1.2, y: by, alpha: E.cIn(up) * .9 });
    shade(.8 * up, '#120A2E');
    const top = H / 2 + by - H * .6;
    const gr = g.createLinearGradient(0, top - 10, 0, top + 600);
    gr.addColorStop(0, '#05040A'); gr.addColorStop(1, 'rgba(5,4,10,0)');
    g.fillStyle = gr; g.fillRect(0, top - 20, W, 640);
  }
}
function sceneGod(t) {
  const sh = shakeAt(t);
  const d = t - 18.5;
  const tilt = E.expoOut(seg(t, 18.5, 19.6));
  const push = (t - 18.5) * .025 + E.expoIn(seg(t, 22.55, 23.0)) * .6;
  g.save();
  g.translate(sh.x, sh.y);
  g.translate(CX, 900); g.scale(1 + push, 1 + push); g.rotate(sh.r); g.translate(-CX, -900);
  drawBg(IMG.bg_god_realm, { zoom: 1.2, y: lerp(700, 120, tilt) });
  shade(lerp(.8, .5, seg(t, 18.5, 19.2)), '#120A2E');
  // galaxia girando detrás
  galaxy(CX, 640, t * .35, E.expoOut(seg(t, 18.85, 19.9)) * 1.1, 1);
  // halo dorado que se expande
  const hp = E.expoOut(seg(t, 19.0, 19.9));
  rays(CX, 700, 24, t * .22, 1500 * hp, 'rgba(255,225,120,1)', .3 * hp, .4);
  rays(CX, 700, 12, -t * .15, 1100 * hp, 'rgba(255,255,255,1)', .12 * hp, .3);
  const ring = 330 * hp + 8 * Math.sin(t * 4);
  if (hp > 0) {
    g.save();
    glow('gold', CX, 560, ring * 1.8, .7 * hp);
    g.lineWidth = 26; g.strokeStyle = `rgba(255,217,61,${hp})`;
    g.beginPath(); g.ellipse(CX, 560, ring, ring, 0, 0, Math.PI * 2); g.stroke();
    g.lineWidth = 9; g.strokeStyle = `rgba(255,250,220,${hp})`; g.stroke();
    g.restore();
    const sw = seg(t, 19.0, 19.7);
    g.save();
    g.lineWidth = 40 * (1 - sw); g.strokeStyle = `rgba(255,240,180,${(1 - sw) * .9})`;
    g.beginPath(); g.arc(CX, 700, 1400 * E.expoOut(sw), 0, Math.PI * 2); g.stroke();
    g.restore();
  }
  // Dios sube entre las nubes
  const rise = E.expoOut(seg(t, 18.55, 19.25));
  const float = Math.sin(t * 2.2) * 14;
  const gy = lerp(1900, 1440, rise) + float;
  drawChar('god', CX, gy, 1000, { shadow: false, white: (1 - seg(t, 19.0, 19.35)) * seg(t, 18.9, 19.0) });
  glow('gold', CX, gy - 500, 700, .25 + .1 * Math.sin(t * 3));
  // nubes delante (parallax más rápido)
  if (CLOUDS) {
    const s = W * 1.5 / CLOUDS.width;
    const ch = CLOUDS.height * s;
    g.drawImage(CLOUDS, CX - W * .75 + Math.sin(t * .4) * 30, lerp(H + 100, H - ch + 120, tilt), W * 1.5, ch);
  }
  burst(t, { t0: 19.0, x: CX, y: 700, n: 70, seed: 950, kind: 'spark', spd: [1500, 3600], grav: 200, life: [.4, .9], size: [7, 14], drag: 2.5, color: 'rgba(255,236,160,1)' });
  burst(t, { t0: 19.0, x: CX, y: 1600, n: 60, seed: 951, kind: 'dust', spd: [60, 200], ang: [-Math.PI * .7, -Math.PI * .3], life: [3, 4.5], size: [14, 34], spread: 1000, delay: 2.5, alpha: .7 });
  burst(t, { t0: 19.1, x: CX, y: 800, n: 26, seed: 952, kind: 'star', spd: [200, 800], life: [1.5, 3], size: [30, 70], drag: 1.2, delay: 2 });
  g.restore();
  title('…A DIOS.', CX, 330, 200, { tin: t - 19.0, stagger: .06, anim: 'slam', dur: .35, gold: true, maxW: 980 });
  // brillo que barre el título
  flash((1 - seg(t, 19.0, 19.25)) * (t >= 19 ? .85 : 0), '#FFF6D0');
  flash(seg(t, 22.75, 23.0), '#FFFFFF');
}

// ── Acto 5 · Logo + juego + CTA (23–30 s) ──
function brandBg(t, dark = 0) {
  sunburst(CX, 820, 28, t * .12, C.orange, '#FF8A4C');
  glow('warm', CX, 820, 1200, .6);
  if (dark > 0) shade(dark, C.ink);
  // viñeta cálida
  const gr = g.createRadialGradient(CX, 900, 300, CX, 960, 1400);
  gr.addColorStop(0, 'rgba(0,0,0,0)'); gr.addColorStop(1, 'rgba(40,10,0,.55)');
  g.fillStyle = gr; g.fillRect(0, 0, W, H);
}
function sceneLogo(t) {
  const sh = shakeAt(t);
  g.save();
  g.translate(sh.x, sh.y);
  brandBg(t);
  const p = seg(t, 23.0, 23.38);
  const s = lerp(2.8, 1, E.backOut(p, 1.6));
  const breathe = 1 + Math.sin((t - 23) * 4) * .01;
  burst(t, { t0: 23.0, x: CX, y: 760, n: 60, seed: 1000, kind: 'confetti', spd: [1000, 2600], grav: 1500, life: [1.2, 1.8], size: [24, 38], drag: 1.8 });
  burst(t, { t0: 23.0, x: CX, y: 760, n: 26, seed: 1001, kind: 'coin', spd: [900, 2400], grav: 2600, life: [1.1, 1.5], size: [60, 110], drag: 1 });
  burst(t, { t0: 23.0, x: CX, y: 760, n: 20, seed: 1002, kind: 'bill', spd: [700, 1700], grav: 900, life: [1.3, 1.8], size: [110, 160], drag: 1.5 });
  const out = E.expoIn(seg(t, 24.12, 24.4));
  drawImg(IMG.logo, CX, 760 - out * 900, 760 * s * breathe * (1 - out * .4), { rot: (1 - E.expoOut(p)) * -.35, alpha: cl(p * 5) });
  g.restore();
  title('FISUEVOLUTION', CX, 1250 - out * 900, 132, { tin: t - 23.2, stagger: .028, maxW: 1000 });
  g.save(); const pa = E.expoOut(seg(t, 23.6, 23.9)) * (1 - out); g.globalAlpha = pa;
  pill(CX, 1385 - out * 900, 560, 84, { fill: C.yellow, stroke: C.ink, alpha: pa });
  g.font = `900 44px ${FONT_N}`; g.textAlign = 'center'; g.textBaseline = 'middle'; g.fillStyle = C.ink;
  g.fillText('DE FISURA A DIOS', CX, 1389 - out * 900);
  g.restore();
  flash(1 - seg(t, 23.0, 23.12));
}

function scenePhone(t) {
  const sh = shakeAt(t);
  g.save();
  g.translate(sh.x, sh.y);
  brandBg(t, .55);
  // teléfono
  const pin = E.expoOut(seg(t, 24.3, 24.75));
  const pw = 600, ph = 1100, px = CX, py = 1040 + (1 - pin) * 1400;
  const prot = (1 - pin) * .12 + Math.sin(t * 1.5) * .008;
  g.save();
  g.translate(px, py);
  g.rotate(prot);
  rr(-pw / 2 - 22, -ph / 2 - 22 + 18, pw + 44, ph + 44, 92); g.fillStyle = 'rgba(0,0,0,.45)'; g.fill();
  rr(-pw / 2 - 22, -ph / 2 - 22, pw + 44, ph + 44, 92); g.fillStyle = '#141414'; g.fill();
  g.lineWidth = 6; g.strokeStyle = '#3a3a3a'; g.stroke();
  g.save();
  rr(-pw / 2, -ph / 2, pw, ph, 72); g.clip();
  // pantalla del juego (piezas reales: fondo del piso, sprites, HUD, botón de compra)
  const s = ph / IMG.bg_alley.height;
  g.drawImage(IMG.bg_alley, -IMG.bg_alley.width * s / 2, -ph / 2, IMG.bg_alley.width * s, ph);
  g.fillStyle = 'rgba(0,0,0,.12)'; g.fillRect(-pw / 2, -ph / 2, pw, ph);
  const floorY = 300;
  // estado de la partida
  const tBuy = 24.95, tGrab = 25.15, tDrop = 25.6, tTap2 = 26.05;
  const leftX = -140, rightX = 140;
  let coins = 48;
  const taps = [24.6, 24.78];
  let bump = 0;
  for (const tt of taps) if (t >= tt) { coins += 1; bump = Math.max(bump, 1 - (t - tt) / .15); }
  if (t >= tBuy) coins -= 25;
  if (t >= tDrop) { coins += 0; }
  if (t >= tTap2) { coins += 3; bump = Math.max(bump, 1 - (t - tTap2) / .15); }
  // personajes
  const dragP = E.cInOut(seg(t, tGrab, tDrop));
  const merged = t >= tDrop;
  if (!merged) {
    const lift = seg(t, tGrab, tGrab + .1) * (1 - seg(t, tDrop - .08, tDrop));
    const lx = lerp(leftX, rightX, dragP), ly = floorY - Math.sin(dragP * Math.PI) * 120 - lift * 30;
    let tapSq = 0;
    for (const tt of taps) { const d = t - tt; if (d >= 0 && d < .18) tapSq = Math.sin(d / .18 * Math.PI) * .1; }
    if (t >= tBuy) {
      const bp = E.elasticOut(seg(t, tBuy, tBuy + .45));
      drawChar('homeless', rightX, floorY, 400 * bp, { flip: true, white: 1 - seg(t, tBuy, tBuy + .15) });
    }
    drawChar('homeless', lx, ly, 400 * (1 + lift * .08), { sx: 1 + tapSq * .6, sy: 1 - tapSq, rot: (dragP > 0 && dragP < 1 ? Math.sin(t * 30) * .05 : 0) });
  } else {
    const dd = t - tDrop;
    const pop = E.elasticOut(seg(dd, 0, .5));
    let tapSq = 0; const d2 = t - tTap2; if (d2 >= 0 && d2 < .18) tapSq = Math.sin(d2 / .18 * Math.PI) * .1;
    drawImg(IMG.fx_merge, rightX, floorY - 210, 200 + 600 * E.expoOut(seg(dd, 0, .4)), { alpha: 1 - seg(dd, .15, .55), rot: dd * 2 });
    drawChar('trapito', rightX, floorY, 430 * pop, { white: 1 - seg(dd, 0, .2), sx: 1 + tapSq * .6, sy: 1 - tapSq });
    burst(t, { t0: tDrop, x: rightX, y: floorY - 210, n: 30, seed: 1100, kind: 'spark', spd: [700, 1800], grav: 500, life: [.25, .5], size: [5, 9], drag: 3 });
    burst(t, { t0: tDrop, x: rightX, y: floorY - 210, n: 20, seed: 1101, kind: 'confetti', spd: [500, 1200], grav: 1400, life: [.8, 1.2], size: [14, 22], drag: 2 });
    if (dd > .1) {
      g.save(); const tp = E.backOut(seg(dd, .1, .35));
      g.translate(rightX - 20, floorY - 490); g.scale(tp, tp);
      rr(-150, -30, 300, 60, 30); g.fillStyle = C.orange; g.fill(); g.lineWidth = 5; g.strokeStyle = C.ink; g.stroke();
      g.font = `900 34px ${FONT_N}`; g.fillStyle = C.cream; g.textAlign = 'center'; g.textBaseline = 'middle';
      g.fillText('¡NIVEL 2!', 0, 2);
      g.restore();
    }
  }
  // +1 flotantes
  for (const tt of [...taps, tTap2]) {
    const d = t - tt;
    if (d >= 0 && d < .5) {
      const x0 = tt === tTap2 ? rightX : leftX;
      title(tt === tTap2 ? '+3' : '+1', x0 + 90, floorY - 400 - 160 * E.expoOut(seg(d, 0, .5)), 60, { font: FONT_N, gold: true, alpha: 1 - seg(d, .3, .5), strokeK: .2 });
    }
  }
  // HUD del juego
  coinHud(0, -ph / 2 + 110, Math.max(0, coins), { sc: .72, bump: cl(bump) });
  // botón verde de compra (ui_btn_buy)
  const bpress = t >= tBuy && t < tBuy + .15 ? 1 - (t - tBuy) / .15 : 0;
  const bs = 1 - bpress * .08;
  g.save();
  g.translate(0, ph / 2 - 150);
  g.scale(bs, bs);
  const bw = 340, bh = bw * IMG.btn_buy.height / IMG.btn_buy.width;
  g.drawImage(IMG.btn_buy, -bw / 2, -bh / 2, bw, bh);
  g.drawImage(IMG.coin, -110, -34, 64, 64);
  g.font = `900 46px ${FONT_N}`; g.fillStyle = C.cream; g.textAlign = 'left'; g.textBaseline = 'middle';
  g.lineWidth = 8; g.strokeStyle = C.ink; g.lineJoin = 'round';
  g.strokeText('25', -34, 3); g.fillText('25', -34, 3);
  g.restore();
  // dedo
  let fx, fy, press = 0, fa = 1;
  if (t < tBuy - .15) { fx = leftX; fy = floorY - 210; for (const tt of taps) { const d = t - tt; if (d >= 0 && d < .15) press = 1 - d / .15; } }
  else if (t < tGrab) { const m = E.cInOut(seg(t, tBuy - .15, tBuy)); fx = lerp(leftX, 0, m); fy = lerp(floorY - 210, ph / 2 - 150, m); if (t >= tBuy) press = 1 - seg(t, tBuy, tBuy + .15); if (t > tBuy + .05) { const m2 = E.cInOut(seg(t, tBuy + .05, tGrab)); fx = lerp(0, leftX, m2); fy = lerp(ph / 2 - 150, floorY - 210, m2); } }
  else if (t < tDrop + .1) { fx = lerp(leftX, rightX, dragP); fy = floorY - 210 - Math.sin(dragP * Math.PI) * 120; press = .6; }
  else { const m = E.cInOut(seg(t, tDrop + .1, tTap2)); fx = rightX; fy = floorY - 210; const d = t - tTap2; if (d >= 0 && d < .15) press = 1 - d / .15; fa = 1 - seg(t, 26.4, 26.6); }
  touch(fx + 30, fy, press, fa * E.expoOut(seg(t, 24.5, 24.6)));
  g.restore();
  // reflejo del vidrio
  g.save();
  rr(-pw / 2, -ph / 2, pw, ph, 72); g.clip();
  const gl = g.createLinearGradient(-pw / 2, -ph / 2, pw / 2, ph / 2);
  gl.addColorStop(0, 'rgba(255,255,255,.12)'); gl.addColorStop(.4, 'rgba(255,255,255,0)'); gl.addColorStop(1, 'rgba(255,255,255,0)');
  g.fillStyle = gl; g.fillRect(-pw / 2, -ph / 2, pw, ph);
  g.restore();
  // isla dinámica
  rr(-70, -ph / 2 + 22, 140, 38, 19); g.fillStyle = '#000'; g.fill();
  g.restore();
  g.restore();
  title('¿HASTA DÓNDE', CX, 225, 110, { tin: t - 24.35, tout: t - 26.62, stagger: .03 });
  title('VAS A LLEGAR?', CX, 345, 118, { tin: t - 24.5, tout: t - 26.64, stagger: .03, gold: true });
  const out = E.expoIn(seg(t, 26.55, 26.8));
  flash(out * .9);
}

function sceneEnd(t) {
  const sh = shakeAt(t);
  const d = t - 26.8;
  g.save();
  g.translate(sh.x, sh.y);
  // fondo oscuro premium con el sunburst de la marca apenas visible
  g.fillStyle = '#1B1512'; g.fillRect(0, 0, W, H);
  g.save(); g.globalAlpha = .16; sunburst(CX, 560, 28, t * .1, 'rgba(0,0,0,0)', C.orange, 2400); g.restore();
  glow('warm', CX, 560, 900, .55);
  burst(t, { t0: 26.8, x: CX, y: 1950, n: 50, seed: 1200, kind: 'dust', spd: [80, 220], ang: [-Math.PI * .65, -Math.PI * .35], life: [2.5, 3.2], size: [12, 30], spread: 1100, delay: 2.4, alpha: .6 });
  // logo
  const lp = seg(t, 26.8, 27.15);
  const ls = E.backOut(lp, 2);
  rays(CX, 560, 16, t * .4, 700 * ls, 'rgba(255,217,61,1)', .28);
  drawImg(IMG.logo, CX, 560 + Math.sin(d * 2.4) * 8, 600 * ls, { rot: (1 - E.expoOut(lp)) * .4 });
  burst(t, { t0: 26.8, x: CX, y: 560, n: 50, seed: 1201, kind: 'confetti', spd: [900, 2200], grav: 1500, life: [1.2, 1.8], size: [22, 34], drag: 1.8 });
  burst(t, { t0: 26.8, x: CX, y: 560, n: 18, seed: 1202, kind: 'coin', spd: [800, 2000], grav: 2400, life: [1, 1.5], size: [60, 100], drag: 1 });
  g.restore();
  title('DESCARGALO', CX, 980, 140, { tin: t - 27.0, stagger: .03 });
  title('GRATIS', CX, 1120, 190, { tin: t - 27.2, stagger: .045, anim: 'slam', dur: .3, gold: true });
  // badge App Store con pulso
  const bp = E.backOut(seg(t, 27.5, 27.8), 2.2);
  const pulse = 1 + Math.max(0, Math.sin((t - 28.2) * Math.PI * 2)) * .03 * (t > 28.2 ? 1 : 0);
  appStoreBadge(CX, 1290, 440, bp * pulse, cl(bp));
  // tira de caras de toda la escalera
  const fy = 1470, fs = 124, gap = 22;
  const ids = FACE_IDS;
  const total = ids.length * (fs + gap);
  const off = (d * 260) % total;
  const fa = E.expoOut(seg(t, 27.6, 28.0));
  g.save();
  g.globalAlpha = fa;
  for (let k = -1; k < 2; k++) {
    ids.forEach((id, i) => {
      const x = i * (fs + gap) - off + k * total + fs / 2 - 40;
      if (x < -fs || x > W + fs) return;
      const im = IMG['face_' + id];
      g.save();
      g.translate(x, fy + (1 - fa) * 80);
      g.beginPath(); g.arc(0, 0, fs / 2, 0, Math.PI * 2);
      g.fillStyle = C.parch; g.fill();
      g.save(); g.clip(); g.drawImage(im, -fs / 2, -fs / 2, fs, fs); g.restore();
      g.lineWidth = 6; g.strokeStyle = id === 'god' ? C.yellow : C.brown; g.stroke();
      g.restore();
    });
  }
  g.restore();
  flash(1 - seg(t, 26.8, 26.95));
}

// ───────────────────────────── compositor ─────────────────────────────
// Ventanas con motion blur por acumulación de sub-frames: [desde, hasta, muestras].
const BLUR = [
  [.78, .86, 5],
  [2.62, 3.04, 7],
  [4.62, 4.8, 5], [6.14, 6.3, 5], [7.12, 7.3, 5], [7.62, 7.8, 5],
  [7.84, 8.14, 9],
  [11.62, 12.05, 8],
  [14.9, 15.12, 9],
  [18.5, 19.1, 5],
  [22.55, 23.05, 7],
  [23.0, 23.3, 6],
  [24.1, 24.75, 7],
  [26.55, 26.9, 6],
];
function samplesAt(t) {
  for (const [a, b, k] of BLUR) if (t >= a && t <= b) return k;
  return 1;
}

// Whip pan horizontal: saliente se va a la izquierda, entrante entra de la derecha.
function whipH(t, t0, t1, outFn, inFn) {
  const p = seg(t, t0, t1);
  const e = E.expoInOut(p);
  g.save(); g.translate(-e * W * 1.1, 0); outFn(t); g.restore();
  g.save(); g.translate((1 - e) * W * 1.1, 0); inFn(t); g.restore();
}
function whipV(t, t0, t1, outFn, inFn) {
  const p = seg(t, t0, t1);
  const e = E.expoInOut(p);
  g.save(); g.translate(0, e * H * 1.05); outFn(t); g.restore();
  g.save(); g.translate(0, -(1 - e) * H * 1.05); inFn(t); g.restore();
}

function drawScene(t) {
  g.setTransform(SCALE, 0, 0, SCALE, 0, 0);
  g.globalAlpha = 1; g.globalCompositeOperation = 'source-over';
  g.fillStyle = '#000'; g.fillRect(0, 0, W, H);
  if (t < 2.92) sceneHook(t);
  else if (t < 3.0) {
    // zoom-through del hook a la mecánica
    sceneHook(t);
    flash(seg(t, 2.92, 3.0) * .8);
  } else if (t < 7.9) sceneMechanic(t);
  else if (t < 8.08) whipH(t, 7.9, 8.08, sceneMechanic, tt => sceneMontage(Math.max(tt, 8.0)));
  else if (t < 10.5) sceneMontage(t);
  else if (t < 12.0) sceneCareer(t);
  else if (t < 14.95) sceneMontage(t);
  else if (t < 15.1) whipV(t, 14.95, 15.1, tt => sceneMontage(Math.min(tt, 14.99)), tt => sceneMontage(Math.max(tt, 15.0)));
  else if (t < 17.0) sceneMontage(t);
  else if (t < 18.5) sceneSilence(t);
  else if (t < 23.0) sceneGod(t);
  else if (t < 24.3) sceneLogo(t);
  else if (t < 26.8) {
    if (t < 24.42) { sceneLogo(t); g.save(); g.globalAlpha = seg(t, 24.3, 24.42); scenePhone(t); g.restore(); }
    else scenePhone(t);
  } else sceneEnd(t);
}

let VIGNETTE = null, GRAIN = null;
function makeOverlays() {
  VIGNETTE = document.createElement('canvas');
  VIGNETTE.width = W / 2; VIGNETTE.height = H / 2;
  const v = VIGNETTE.getContext('2d');
  const gr = v.createRadialGradient(W / 4, H / 4, W * .22, W / 4, H / 4, H * .62);
  gr.addColorStop(0, 'rgba(0,0,0,0)'); gr.addColorStop(1, 'rgba(0,0,0,.5)');
  v.fillStyle = gr; v.fillRect(0, 0, W / 2, H / 2);
  GRAIN = document.createElement('canvas');
  GRAIN.width = GRAIN.height = 256;
  const gx = GRAIN.getContext('2d');
  const id = gx.createImageData(256, 256);
  const r = rng(4242);
  for (let i = 0; i < id.data.length; i += 4) {
    const n = Math.floor(r() * 255);
    id.data[i] = id.data[i + 1] = id.data[i + 2] = n; id.data[i + 3] = 255;
  }
  gx.putImageData(id, 0, 0);
}

function renderFrame(t) {
  const k = samplesAt(t);
  if (k <= 1) {
    g = mainCtx;
    drawScene(t);
  } else {
    const shutter = 1 / 60;
    for (let i = 0; i < k; i++) {
      const ts = t + (i / (k - 1) - .5) * shutter;
      g = bufCtx;
      drawScene(ts);
      mainCtx.setTransform(1, 0, 0, 1, 0, 0);
      mainCtx.globalCompositeOperation = 'source-over';
      mainCtx.globalAlpha = 1 / (i + 1);
      mainCtx.drawImage(buf, 0, 0);
    }
    mainCtx.globalAlpha = 1;
    g = mainCtx;
  }
  // acabado: viñeta + grano
  mainCtx.setTransform(1, 0, 0, 1, 0, 0);
  mainCtx.globalAlpha = 1;
  mainCtx.drawImage(VIGNETTE, 0, 0, cv.width, cv.height);
  mainCtx.globalCompositeOperation = 'overlay';
  mainCtx.globalAlpha = .07;
  const r = rng(Math.floor(t * 1000) + 1);
  const pat = mainCtx.createPattern(GRAIN, 'repeat');
  mainCtx.translate(Math.floor(r() * 256), Math.floor(r() * 256));
  mainCtx.scale(Math.max(1, SCALE), Math.max(1, SCALE));
  mainCtx.fillStyle = pat;
  mainCtx.fillRect(-256, -256, cv.width + 512, cv.height + 512);
  mainCtx.setTransform(1, 0, 0, 1, 0, 0);
  mainCtx.globalCompositeOperation = 'source-over';
  mainCtx.globalAlpha = 1;
}

async function init() {
  const fonts = [
    new FontFace('Baloo2', 'url(fonts/Baloo2.woff2)', { weight: '800' }),
    new FontFace('Nunito', 'url(fonts/Nunito.woff2)', { weight: '900' }),
    new FontFace('Inter', 'url(fonts/Inter.woff2)', { weight: '600' }),
  ];
  for (const f of fonts) { await f.load(); document.fonts.add(f); }
  const L = assetList();
  await Promise.all(Object.entries(L).map(async ([k, src]) => { IMG[k] = await loadImage(src); }));
  for (const [id] of TIERS) IMG[id].bb = trimBox(IMG[id]);
  GLOW.gold = makeGlow('rgba(255,200,80,1)');
  GLOW.warm = makeGlow('rgba(255,140,60,1)');
  GLOW.white = makeGlow('rgba(255,255,255,1)');
  GLOW.violet = makeGlow('rgba(170,120,255,1)');
  makeClouds();
  makeOverlays();
  setupImpacts();
  for (const c of [mainCtx, bufCtx]) { c.imageSmoothingEnabled = true; c.imageSmoothingQuality = 'high'; }
  window.READY = true;
  if (params.has('t')) renderFrame(parseFloat(params.get('t')));
  else if (params.has('play')) {
    const start = performance.now();
    const loop = () => { renderFrame(((performance.now() - start) / 1000) % DURATION); requestAnimationFrame(loop); };
    loop();
  }
}
window.renderFrame = renderFrame;
window.DURATION = DURATION;
init().catch(e => { window.ERROR = String(e); console.error(e); });
