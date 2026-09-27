'use strict';
// FisuEvolution — motor compartido de los reels (v1 = scene.js, v2 = scene2.js).
// Todo es determinístico: la escena expone drawScene(t) sin estado, así
// cualquier worker puede renderizar cualquier rango de frames.
// Unidades lógicas 1080×1920; ?scale=2 renderiza 2160×3840.

const W = 1080, H = 1920;
const BEAT = 0.5; // 120 BPM
const params = new URLSearchParams(location.search);
const SCALE = parseFloat(params.get('scale') || '1');
const FPS = parseFloat(params.get('fps') || '60');
// Idioma: ?lang=en localiza al inglés (EE. UU.). Sin el parámetro, todo queda en español.
const LANG = params.get('lang') === 'en' ? 'en' : 'es';
const EN = LANG === 'en';
const tr = (es, en) => (EN ? en : es);

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
// Nombres oficiales en inglés (Localizable.xcstrings, tier.name.*).
const TIER_EN = {
  homeless: 'The Hobo', trapito: 'The Fake Valet', limpiavidrios: 'Squeegee Guy', cartonero: 'Cardboard Collector',
  mantero: 'The Bootleg Vendor', repartidor: 'Delivery Guy', chofer_app: 'Rideshare Driver', fast_food: 'Burger Flipper',
  oficinista: 'Office Drone', administrativo: 'Paper Pusher', junior_programmer: 'Junior Developer',
  junior_architect: 'Junior Architect', junior_doctor: 'Medical Resident', junior_lawyer: 'Junior Associate',
  senior_programmer: 'Senior Developer', director: 'Director', fundador_startup: 'Startup Founder',
  dueno_pyme: 'Small Business Owner', emprendedor: 'Hustle Guru', ceo: 'CEO', millonario: 'Millionaire',
  multimillonario: 'Multimillionaire', rey_ladrillo: 'Real Estate King', magnate_petrolero: 'Oil Baron',
  space_billionaire: 'Space Billionaire', trillonario: 'Trillionaire', dueno_luna: 'Owner of the Moon',
  dueno_marte: 'Owner of Mars', rey_asteroides: 'King of the Asteroids', magnate_solar: 'Solar System Tycoon',
  fondo_buitre: 'Stellar Vulture Fund', rentista_soles: 'Landlord of Suns', estanciero_estelar: 'Star Rancher',
  senor_galaxia: 'Lord of the Galaxy', coleccionista_galaxias: 'Galaxy Collector', emperador_cosmico: 'Cosmic Emperor',
  ser_ascendido: 'Ascended Being', semidios: 'Demigod', deidad: 'Deity', god: 'God',
};
const TIER = Object.fromEntries(TIERS.map(([id, name, n]) => [id, { name: EN ? TIER_EN[id] : name, n }]));
const FACE_IDS = TIERS.map(t => t[0]).filter(id => !id.startsWith('junior_') && !id.startsWith('senior_') || id === 'junior_programmer');

const IMG = {};
function charPath(id) {
  return RES + (COSMIC.includes(id) ? 'cosmic.atlas/' : 'earth.atlas/') + id + '_idle@3x.png';
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
  r = Math.max(0, Math.min(r, Math.abs(w) / 2, Math.abs(h) / 2));
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
  if (a <= 0 || !(len > 0)) return;
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
const EMOJI = /\p{Extended_Pictographic}/u;
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
    if (EMOJI.test(ch)) {
      g.font = `${size * .8}px "Noto Color Emoji"`;
      g.fillText(ch, 0, size * .04);
      g.restore();
      return;
    }
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
  const s = v >= 100 ? Math.floor(v).toString() : (Math.floor(v * 10) / 10).toString().replace('.', EN ? '.' : ',');
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
  const lv = tr('NIVEL ', 'LEVEL ') + t.n;
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
  g.fillText(tr('Descárgalo en el', 'Download on the'), -w / 2 + h * .98, -h * .06);
  g.font = `600 ${h * .38}px Inter`;
  g.fillText('App Store', -w / 2 + h * .94, h * .3, w - h * 1.1);
  g.restore();
}

// ───────────────────────────── utilidades de escena (v2+) ─────────────────────────────
// Interpolación por keyframes: [[t, valor|objeto, ease?], ...]
function track(t, keys) {
  if (t <= keys[0][0]) return keys[0][1];
  for (let i = 1; i < keys.length; i++) {
    const [t1, v1, ez] = keys[i];
    if (t <= t1) {
      const [t0, v0] = keys[i - 1];
      const p = (ez || E.cInOut)(seg(t, t0, t1));
      if (typeof v0 === 'number') return lerp(v0, v1, p);
      const o = {};
      for (const k in v0) o[k] = lerp(v0[k], v1[k], p);
      return o;
    }
  }
  return keys[keys.length - 1][1];
}
function win(t, a, b, fin = .35, fout = .35) { return seg(t, a, a + fin) * (1 - seg(t, b - fout, b)); }

function shadowBlob(x, y, rx, ry, a) {
  if (a <= 0) return;
  g.save();
  g.translate(x, y); g.scale(rx, ry);
  const gr = g.createRadialGradient(0, 0, 0, 0, 0, 1);
  gr.addColorStop(0, `rgba(10,6,2,${.62 * a})`); gr.addColorStop(1, 'rgba(10,6,2,0)');
  g.fillStyle = gr; g.beginPath(); g.arc(0, 0, 1, 0, Math.PI * 2); g.fill();
  g.restore();
}
// Leyenda del reel: sube con fundido, lenta. Sombra suave detrás para leerse sobre la UI.
function caption(t, str, t0, t1, y, size = 104, o = {}) {
  if (t < t0 - .05 || t > t1 + .6) return;
  const a = win(t, t0, t1 + .45, .5, .45);
  shadowBlob(540, y, 560, size * 1.1, a);
  title(str, 540, y, size, { tin: t - t0, tout: t > t1 ? t - t1 : null, anim: 'rise', dur: .6, stagger: .028, maxW: 980, ...o });
}
function sil(id, x, y, h, color, a) {
  const im = IMG[id]; if (!im || a <= 0) return;
  const bb = im.bb, w = h * bb.w / bb.h;
  g.save(); g.globalAlpha = a;
  g.drawImage(tint(id, color), 0, 0, bb.w, bb.h, x - w / 2, y - h, w, h);
  g.restore();
}
function text(str, x, y, size, color = C.ink, o = {}) {
  g.save();
  g.font = `${o.weight || 900} ${size}px ${o.font || FONT_N}`;
  g.textAlign = o.align || 'center'; g.textBaseline = 'middle';
  g.globalAlpha *= o.alpha == null ? 1 : o.alpha;
  if (o.stroke) { g.lineJoin = 'round'; g.lineWidth = o.stroke; g.strokeStyle = o.strokeColor || C.ink; g.strokeText(str, x, y, o.maxW); }
  g.fillStyle = color; g.fillText(str, x, y, o.maxW);
  g.restore();
}
function wrap(str, x, y, size, maxW, lh, color, o = {}) {
  g.save();
  g.font = `${o.weight || 700} ${size}px ${o.font || FONT_N}`;
  const words = str.split(' '); const lines = []; let cur = '';
  for (const w of words) { const tt = cur ? cur + ' ' + w : w; if (g.measureText(tt).width > maxW && cur) { lines.push(cur); cur = w; } else cur = tt; }
  lines.push(cur);
  g.restore();
  lines.forEach((l, i) => text(l, x, y + (i - (lines.length - 1) / 2) * lh, size, color, o));
}
function star4(x, y, r, color) {
  g.save(); g.translate(x, y); g.fillStyle = color; g.beginPath();
  for (let i = 0; i < 8; i++) { const a = i * Math.PI / 4 - Math.PI / 2, rr_ = i % 2 ? r * .38 : r; g.lineTo(Math.cos(a) * rr_, Math.sin(a) * rr_); }
  g.closePath(); g.fill(); g.restore();
}
function lockIcon(x, y, s, color = C.cream) {
  g.save(); g.translate(x, y); g.scale(s, s);
  g.lineWidth = 7; g.strokeStyle = color; g.lineCap = 'round';
  g.beginPath(); g.arc(0, -14, 16, Math.PI, 0); g.stroke();
  rr(-24, -14, 48, 38, 8); g.fillStyle = color; g.fill();
  g.fillStyle = C.ink; g.beginPath(); g.arc(0, 2, 5, 0, Math.PI * 2); g.fill(); g.fillRect(-2, 2, 4, 12);
  g.restore();
}

// ───────────────────────────── piezas de los reels v3–v5 ─────────────────────────────
// Globo de diálogo (lenguaje de ui_speech_bubble): crema, trazo de tinta, cola hacia (tx, ty).
function speech(x, y, w, str, tx, ty, o = {}) {
  const s = o.s == null ? 1 : o.s;
  if (s <= 0) return;
  const size = o.size || 46, lh = size * 1.18;
  g.save();
  g.font = `900 ${size}px ${FONT_N}`;
  const words = str.split(' '); const lines = []; let cur = '';
  for (const wd of words) { const tt = cur ? cur + ' ' + wd : wd; if (g.measureText(tt).width > w - 60 && cur) { lines.push(cur); cur = wd; } else cur = tt; }
  lines.push(cur);
  const h = lines.length * lh + 44;
  g.translate(tx, ty); g.scale(s, s); g.translate(-tx, -ty);
  g.globalAlpha *= o.alpha == null ? 1 : o.alpha;
  const bx = x - w / 2, by = y - h / 2;
  const tail = () => {
    const cx = cl(tx, bx + 50, bx + w - 50), base = ty > y ? by + h - 4 : by + 4;
    g.moveTo(cx - 26, base); g.lineTo(tx, ty); g.lineTo(cx + 26, base);
  };
  g.fillStyle = 'rgba(0,0,0,.3)'; rr(bx, by + 10, w, h, 34); g.fill();
  g.beginPath(); tail(); g.fillStyle = C.cream; g.fill(); g.lineWidth = 7; g.strokeStyle = C.ink; g.lineJoin = 'round'; g.stroke();
  rr(bx, by, w, h, 34); g.fillStyle = C.cream; g.fill(); g.stroke();
  g.beginPath(); tail(); g.fillStyle = C.cream; g.fill();
  lines.forEach((l, i) => text(l, x, by + 22 + lh / 2 + i * lh, size, o.color || C.ink));
  g.restore();
}
// Toast de logro del juego ("¡Logro desbloqueado!").
function achievement(t, t0, t1, name, y = 1500) {
  if (t < t0 || t > t1) return;
  const p = E.backOut(seg(t, t0, t0 + .45), 1.6), out = E.cIn(seg(t, t1 - .3, t1));
  g.save(); g.translate(540, y + out * 60); g.scale(p, p); g.globalAlpha = 1 - out;
  rr(-360, -62, 720, 124, 62); g.fillStyle = 'rgba(28,20,14,.94)'; g.fill(); g.lineWidth = 5; g.strokeStyle = C.yellow; g.stroke();
  g.drawImage(IMG.trophy, -340, -48, 96, 96);
  text(tr('¡Logro desbloqueado!', 'Achievement unlocked!'), 55, -22, 34, C.yellow, { maxW: 560 });
  text(name, 55, 24, 42, C.cream, { maxW: 560 });
  g.restore();
}
// Cierre común: ícono real, nombre, descarga, badge y firma de Ader Games.
function ctaEnd(t, t0, o = {}) {
  const d = t - t0;
  const gr = g.createRadialGradient(540, 700, 100, 540, 900, 1400);
  gr.addColorStop(0, '#3A2414'); gr.addColorStop(1, '#140C08');
  g.fillStyle = gr; g.fillRect(0, 0, W, H);
  g.save(); g.globalAlpha = .18; sunburst(540, 620, 28, t * .08, 'rgba(0,0,0,0)', C.orange, 2400); g.restore();
  glow('warm', 540, 620, 800, .6);
  burst(t, { t0, x: 540, y: 2000, n: 50, seed: 3100, kind: 'dust', spd: [80, 200], ang: [-Math.PI * .65, -Math.PI * .35], life: [2.5, 3.2], size: [12, 30], spread: 1100, delay: 2.4, alpha: .55 });
  if (o.lines) o.lines.forEach((ln, i) => title(ln, 540, 250 + i * 110, i ? 100 : 84, { tin: d - .05 - i * .15, stagger: .025, anim: 'rise', dur: .5, gold: i === 1, maxW: 980 }));
  const top = o.lines ? 120 : 0;
  const ip = E.backOut(seg(t, t0 + .1, t0 + .6), 1.7);
  const is = 340 * ip;
  if (is > 1) {
    g.save(); g.translate(540, 560 + top + Math.sin(d * 2) * 6);
    rr(-is / 2, -is / 2 + 14, is, is, is * .22); g.fillStyle = 'rgba(0,0,0,.45)'; g.fill();
    rr(-is / 2, -is / 2, is, is, is * .22); g.save(); g.clip(); g.drawImage(IMG.app_icon, -is / 2, -is / 2, is, is); g.restore();
    g.restore();
  }
  rays(540, 560 + top, 16, t * .3, 600 * ip, 'rgba(255,217,61,1)', .12);
  title('FISUEVOLUTION', 540, 830 + top, 100, { tin: d - .35, stagger: .025, anim: 'rise', dur: .5 });
  title(tr('DESCARGALO GRATIS', 'DOWNLOAD FREE'), 540, 955 + top, 100, { tin: d - .55, stagger: .025, anim: 'rise', dur: .5, gold: true, maxW: 980 });
  const bp = E.backOut(seg(t, t0 + .9, t0 + 1.3), 2);
  const pulse = d > 1.6 ? 1 + Math.max(0, Math.sin((d - 1.6) * Math.PI * 1.6)) * .025 : 1;
  appStoreBadge(540, 1100 + top, 420, bp * pulse, cl(bp));
  const ap = E.cOut(seg(t, t0 + 1.1, t0 + 1.6));
  g.save(); g.globalAlpha = ap;
  text(tr('UN JUEGO DE', 'A GAME BY'), 540, 1250 + top, 28, 'rgba(255,248,231,.75)');
  const lw = 300, lh = lw * IMG.ader.height / IMG.ader.width;
  g.drawImage(IMG.ader, 540 - lw / 2, 1285 + top + (1 - ap) * 20, lw, lh);
  g.restore();
  if (o.foot) title(o.foot, 540, 1300 + top + lh + 30, 46, { tin: d - 1.4, stagger: .012, anim: 'rise', dur: .4, maxW: 960, strokeK: .14 });
}
// Assets comunes de los reels v3–v5.
function commonAssets(L) {
  const U = n => RES + 'ui.atlas/' + n + '@3x.png';
  Object.assign(L, {
    coin: U('ui_coin'), fx_merge: U('fx_merge'), fx_tap: U('fx_tap'), fx_evo: U('fx_evolution_flash'), star: U('fx_unlock'),
    dollar: U('ui_dollar'), bubble: U('ui_speech_bubble'), trophy: U('ui_menu_trophy'), ribbon: U('ui_header_ribbon'),
    app_icon: '/Distribution/promo/render/assets/app_icon.png', ader: '/Distribution/promo/render/assets/adergames_logo.png',
  });
  return L;
}
function skinPath(id, skin) {
  return RES + (COSMIC.includes(id) || id === 'dueno_luna' ? 'cosmic.atlas/' : 'earth.atlas/') + id + '_idle__' + skin + '@3x.png';
}

// ───────────────────────────── compositor ─────────────────────────────
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
  for (const k of Object.keys(IMG)) if (TIER[k] || k.includes('_idle') || k.startsWith('sp_')) IMG[k].bb = trimBox(IMG[k]);
  GLOW.gold = makeGlow('rgba(255,200,80,1)');
  GLOW.warm = makeGlow('rgba(255,140,60,1)');
  GLOW.white = makeGlow('rgba(255,255,255,1)');
  GLOW.violet = makeGlow('rgba(170,120,255,1)');
  makeOverlays();
  sceneSetup();
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
function boot() { init().catch(e => { window.ERROR = String(e); console.error(e); }); }
