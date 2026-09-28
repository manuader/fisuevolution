'use strict';
// Reel v5 — «QUIZ: ¿en qué se convierte?» (33 s, música de programa, 120 BPM).
// Programa de TV: dos personajes iguales, tres respuestas (las falsas son el
// chiste), reloj de 3 segundos y la fusión real de tiers.json como respuesta.
// La pregunta final se corta: sólo lo saben los que llegan al nivel 37.

const DURATION = 33;

function assetList() {
  const L = commonAssets({});
  for (const id of ['homeless', 'trapito', 'chofer_app', 'fast_food', 'rey_ladrillo', 'magnate_petrolero', 'deidad', 'god']) L[id] = charPath(id);
  return L;
}

// [t0, a, resultado, respuestas, correcta, chiste]
const ROUNDS = EN ? [
  [2.5, 'homeless', 'trapito', ['A congressman', 'The Fake Valet', 'An influencer'], 1, 'EASY. 😎'],
  [8.5, 'chofer_app', 'fast_food', ['A limo driver', 'Burger Flipper', 'A city bus'], 1, "(yep, that's the economy)"],
  [14.5, 'rey_ladrillo', 'magnate_petrolero', ['Oil Baron', 'A happy tenant', 'A timeshare'], 0, "A happy tenant doesn't exist."],
] : [
  [2.5, 'homeless', 'trapito', ['Un diputado', 'El Trapito', 'Un influencer'], 1, 'FÁCIL. 😎'],
  [8.5, 'chofer_app', 'fast_food', ['Un Uber Black', 'Empleado de Fast Food', 'El colectivo 140'], 1, '(sí, así está la economía)'],
  [14.5, 'rey_ladrillo', 'magnate_petrolero', ['Magnate Petrolero', 'Un inquilino feliz', 'El Obelisco'], 0, 'Un inquilino feliz no existe.'],
];
const FINAL = 20.5, BLACKOUT = 25.1, CTA = 29.0;
const NAMES = EN ? { homeless: 'THE HOBO', chofer_app: 'RIDESHARE DRIVER', rey_ladrillo: 'REAL ESTATE KING', deidad: 'DEITY' } : { homeless: 'EL FISURA', chofer_app: 'CHOFER DE APP', rey_ladrillo: 'REY DEL LADRILLO', deidad: 'DEIDAD' };
const TICK = .8; // un segundo del reloj, a tempo

function roundAt(t) {
  if (t >= FINAL) return 3;
  let r = 0; for (let i = 0; i < ROUNDS.length; i++) if (t >= ROUNDS[i][0]) r = i; return r;
}

function stage(t, red = 0) {
  const gr = g.createRadialGradient(540, 820, 100, 540, 900, 1400);
  gr.addColorStop(0, red ? '#3A0A1A' : '#1B1A5E'); gr.addColorStop(1, red ? '#0C0206' : '#06061A');
  g.fillStyle = gr; g.fillRect(0, 0, W, H);
  // reflectores que barren
  for (const [x0, ph] of [[80, 0], [1000, 1.7], [300, 3.1], [780, 4.4]]) {
    const ang = Math.PI / 2 + Math.sin(t * .9 + ph) * .35;
    g.save(); g.translate(x0, -40); g.rotate(ang - Math.PI / 2);
    const lg = g.createLinearGradient(0, 0, 0, 1700);
    lg.addColorStop(0, red ? 'rgba(255,80,110,.35)' : 'rgba(170,190,255,.32)'); lg.addColorStop(1, 'rgba(255,255,255,0)');
    g.globalCompositeOperation = 'lighter'; g.fillStyle = lg;
    g.beginPath(); g.moveTo(-18, 0); g.lineTo(18, 0); g.lineTo(230, 1700); g.lineTo(-230, 1700); g.closePath(); g.fill();
    g.restore();
  }
  // piso del escenario
  g.save();
  const fg = g.createRadialGradient(540, 1060, 40, 540, 1060, 520);
  fg.addColorStop(0, red ? 'rgba(255,90,120,.5)' : 'rgba(120,150,255,.5)'); fg.addColorStop(1, 'rgba(0,0,0,0)');
  g.fillStyle = fg; g.beginPath(); g.ellipse(540, 1060, 520, 90, 0, 0, Math.PI * 2); g.fill();
  g.lineWidth = 6; g.strokeStyle = red ? 'rgba(255,120,140,.8)' : 'rgba(160,190,255,.8)';
  g.beginPath(); g.ellipse(540, 1060, 470, 70, 0, 0, Math.PI * 2); g.stroke();
  g.restore();
  // guirnalda de lamparitas
  for (let i = 0; i < 24; i++) {
    const on = (Math.floor(t * 6) + i) % 3 === 0;
    const x = 60 + i * 41.7;
    g.beginPath(); g.arc(x, 1640, 9, 0, Math.PI * 2); g.fillStyle = on ? C.yellow : 'rgba(255,217,61,.25)'; g.fill();
    if (on) glow('gold', x, 1640, 30, .5);
  }
}
function logoPlate(t, t0, red) {
  const p = E.backOut(seg(t, t0, t0 + .4), 1.8);
  if (p <= 0) return;
  g.save(); g.translate(540, 280); g.scale(p, p);
  rr(-470, -70, 940, 140, 36); g.fillStyle = 'rgba(0,0,0,.45)'; g.fill();
  rr(-470, -80, 940, 140, 36); g.fillStyle = red ? '#5A0E24' : '#16145A'; g.fill(); g.lineWidth = 8; g.strokeStyle = C.yellow; g.stroke();
  for (let i = 0; i < 18; i++) {
    const on = (Math.floor(t * 8) + i) % 2 === 0;
    g.beginPath(); g.arc(-440 + i * 51.7, -80, 7, 0, Math.PI * 2); g.fillStyle = on ? '#fff' : C.yellow; g.fill();
    g.beginPath(); g.arc(-440 + i * 51.7, 60, 7, 0, Math.PI * 2); g.fill();
  }
  g.restore();
  title(tr('¿EN QUÉ SE CONVIERTE?', 'WHAT DOES IT BECOME?'), 540, 272, 74 * p, { tin: 99, gold: true, maxW: 860 * p });
}
function answerBar(y, letter, str, state, pin, hidden, t) {
  if (pin <= 0) return;
  // state: 0 normal, 1 correcta, -1 incorrecta
  g.save(); g.translate(520, y); g.scale(pin, pin);
  g.globalAlpha = state === -1 ? .45 : 1;
  const w = 800, h = 100;
  const path = () => { g.beginPath(); g.moveTo(-w / 2, 0); g.lineTo(-w / 2 + 40, -h / 2); g.lineTo(w / 2 - 40, -h / 2); g.lineTo(w / 2, 0); g.lineTo(w / 2 - 40, h / 2); g.lineTo(-w / 2 + 40, h / 2); g.closePath(); };
  g.lineWidth = 5; g.strokeStyle = C.yellow;
  g.beginPath(); g.moveTo(-520, 0); g.lineTo(520, 0); g.stroke();
  path(); g.fillStyle = state === 1 ? '#1F9A4B' : '#0E0D3A'; g.fill(); g.lineWidth = 6; g.strokeStyle = state === 1 ? '#B8FFCB' : C.yellow; g.stroke();
  if (state === 1) glow('white', 0, 0, 380, .25 + .15 * Math.sin(t * 12));
  text(letter + ':', -w / 2 + 80, 3, 48, C.yellow, { font: FONT_T, weight: 800 });
  if (hidden) {
    // respuesta tapada
    for (let k = 0; k < 3; k++) text('?', -80 + k * 80, 3, 60, 'rgba(255,255,255,.85)', { font: FONT_T, weight: 800 });
    g.save(); g.globalAlpha *= .5; g.fillStyle = '#fff';
    const r = rng(Math.floor(t * 20) + y);
    for (let k = 0; k < 40; k++) g.fillRect(-250 + r() * 560, -30 + r() * 60, 4 + r() * 12, 3);
    g.restore();
  } else text(str, 40, 3, str.length > 18 ? 44 : 50, '#fff', { font: FONT_T, weight: 800, maxW: 600 });
  if (state === 1) { g.lineWidth = 12; g.strokeStyle = '#fff'; g.lineCap = 'round'; g.beginPath(); g.moveTo(w / 2 - 110, 0); g.lineTo(w / 2 - 88, 22); g.lineTo(w / 2 - 52, -22); g.stroke(); }
  g.restore();
}
function timer(t, t0, n = 3) {
  const d = t - t0;
  if (d < -.3 || d > n * TICK + .4) return;
  const a = win(t, t0 - .3, t0 + n * TICK + .4, .2, .3);
  const left = Math.max(0, n - d / TICK);
  const num = Math.max(1, Math.ceil(left));
  g.save(); g.globalAlpha = a; g.translate(540, 1150);
  g.beginPath(); g.arc(0, 0, 66, 0, Math.PI * 2); g.fillStyle = '#0E0D3A'; g.fill(); g.lineWidth = 6; g.strokeStyle = C.ink; g.stroke();
  const frac = left / n;
  g.beginPath(); g.arc(0, 0, 56, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * frac); g.lineWidth = 12;
  g.strokeStyle = frac > .34 ? C.yellow : C.pink; g.lineCap = 'round'; g.stroke();
  const bump = 1 + (1 - ((d % TICK) / TICK)) * .25;
  g.scale(bump, bump);
  text(String(num), 0, 4, 64, '#fff', { font: FONT_T, weight: 800 });
  g.restore();
}
function pair(t, id, t0, mergeT, st = {}) {
  // dos iguales entran por los costados; en la respuesta se fusionan al centro
  const inP = E.backOut(seg(t, t0, t0 + .45), 1.5);
  const m = mergeT ? E.cIn(seg(t, mergeT, mergeT + .3)) : 0;
  if (m >= 1) return;
  const bob = Math.sin(t * 5) * 6;
  for (const s of [-1, 1]) {
    const x = lerp(540 + s * 900, 540 + s * 250, inP);
    drawChar(id, lerp(x, 540, m), 1050 + (s > 0 ? bob : -bob), 500 * (1 - m * .4), { flip: s > 0, white: m, sx: 1 + m * .2, sy: 1 - m * .2, alpha: st.alpha == null ? 1 : st.alpha });
  }
  if (m <= 0) {
    const pp = E.backOut(seg(t, t0 + .3, t0 + .6), 2);
    title('+', 540, 800, 150 * pp, { tin: 99, gold: true });
    const np = E.backOut(seg(t, t0 + .35, t0 + .7), 1.8);
    if (np > 0) {
      g.save(); g.globalAlpha = st.alpha == null ? 1 : st.alpha;
      for (const s of [-1, 1]) {
        g.save(); g.translate(540 + s * 250, 1095); g.scale(np, np);
        g.font = `800 34px ${FONT_T}`; const w = g.measureText(NAMES[id]).width + 44;
        rr(-w / 2, -26, w, 52, 26); g.fillStyle = C.cream; g.fill(); g.lineWidth = 4; g.strokeStyle = C.ink; g.stroke();
        text(NAMES[id], 0, 3, 34, C.ink, { font: FONT_T, weight: 800 });
        g.restore();
      }
      g.restore();
    }
  }
}

function sceneRound(t, i) {
  const [t0, id, res, answers, correct, joke] = ROUNDS[i];
  const reveal = t0 + 1.3 + 3 * TICK; // tras el reloj
  stage(t);
  logoPlate(t, i === 0 ? 1.9 : -9, false);
  const chip = `${tr('PREGUNTA', 'QUESTION')} ${i + 1}/4`;
  title(chip, 540, 410, 58, { tin: t - t0 - .1, stagger: .02, anim: 'rise', dur: .3, strokeK: .14 });
  pair(t, id, i === 0 ? -1 : t0, reveal + .15);
  // resultado
  const rp = t - (reveal + .45);
  if (rp >= 0) {
    rays(540, 760, 16, t * .6, 900 * E.expoOut(seg(rp, 0, .4)), 'rgba(255,217,61,1)', .3);
    drawImg(IMG.fx_merge, 540, 760, 300 + 900 * E.expoOut(seg(rp, 0, .4)), { alpha: 1 - seg(rp, .1, .5), rot: rp * 2 });
    drawChar(res, 540, 1060, 600 * E.elasticOut(seg(rp, 0, .6)), { white: 1 - seg(rp, 0, .25) });
    title(TIER[res].name.toUpperCase(), 540, 520, 76, { tin: rp - .15, anim: 'slam', dur: .25, gold: true, maxW: 900 });
  }
  burst(t, { t0: reveal + .45, x: 540, y: 760, n: 60, seed: 5000 + i, kind: 'confetti', spd: [700, 1800], grav: 1300, life: [1.2, 1.7], size: [24, 36], drag: 1.6 });
  // respuestas
  answers.forEach((a, k) => {
    const pin = E.backOut(seg(t, t0 + .6 + k * .12, t0 + .9 + k * .12), 1.6);
    const st = t >= reveal ? (k === correct ? 1 : -1) : 0;
    answerBar(1250 + k * 118, 'ABC'[k], a, st, pin, false, t);
  });
  timer(t, t0 + 1.3);
  // el chiste
  if (t > reveal + .9) {
    const jp = E.backOut(seg(t, reveal + .9, reveal + 1.15), 2);
    g.save(); g.translate(540, 1150); g.rotate(-.03); g.scale(jp, jp);
    g.font = `800 50px ${FONT_T}`; const w = Math.min(980, g.measureText(joke).width + 70);
    rr(-w / 2, -48, w, 96, 48); g.fillStyle = C.yellow; g.fill(); g.lineWidth = 6; g.strokeStyle = C.ink; g.stroke();
    text(joke, 0, 5, 50, C.ink, { font: `${FONT_T}, "Noto Color Emoji"`, weight: 800, maxW: w - 50 });
    g.restore();
  }
}

function sceneHook(t) {
  stage(t);
  pair(t, 'homeless', -1, null);
  const a = 1 - seg(t, 1.8, 2.1);
  g.save(); g.globalAlpha = a * .75; rr(40, 1110, 1000, 430, 44); g.fillStyle = 'rgba(6,6,26,.85)'; g.fill(); g.restore();
  title(tr('EL 97% NO ADIVINA', 'NOBODY GETS'), 540, 1210, 100, { tin: t + .15, alpha: a, stagger: .018, dur: .3, maxW: 960 });
  title(tr('LA ÚLTIMA 👀', 'THE LAST ONE 👀'), 540, 1340, 120, { tin: t - .1, alpha: a, stagger: .03, dur: .3, gold: true });
  title(tr('¿VOS SÍ?', 'CAN YOU?'), 540, 1460, 70, { tin: t - 1.0, alpha: a, stagger: .03, dur: .3, fill: C.pink });
  logoPlate(t, 1.9, false);
}

function sceneFinal(t) {
  const d = t - FINAL;
  if (t < BLACKOUT) {
    stage(t, 1);
    logoPlate(t, -9, true);
    title(tr('PREGUNTA FINAL', 'FINAL QUESTION'), 540, 420, 84, { tin: d - .05, anim: 'slam', dur: .3, stagger: .03, fill: C.pink });
    pair(t, 'deidad', FINAL + 1.0, null);
    for (let k = 0; k < 3; k++) answerBar(1250 + k * 118, 'ABC'[k], '', 0, E.backOut(seg(t, FINAL + 1.6 + k * .12, FINAL + 1.9 + k * .12), 1.6), true, t);
    timer(t, FINAL + 2.2);
    // latido rojo
    const hb = Math.max(0, Math.sin((t - FINAL) * Math.PI * 2.5)) ** 6;
    g.save(); g.globalAlpha = hb * .18; g.fillStyle = '#FF2244'; g.fillRect(0, 0, W, H); g.restore();
    return;
  }
  // apagón
  g.fillStyle = '#030208'; g.fillRect(0, 0, W, H);
  const b = t - BLACKOUT;
  if (b < .12) { g.fillStyle = '#fff'; g.globalAlpha = 1 - b / .12; g.fillRect(0, 0, W, H); g.globalAlpha = 1; }
  title(tr('SÓLO LO SABEN', 'ONLY PLAYERS WHO'), 540, 330, 100, { tin: b - .3, anim: 'rise', dur: .4, stagger: .03 });
  title(tr('LOS QUE LLEGAN AL NIVEL 37.', 'REACH LEVEL 37 KNOW.'), 540, 450, 80, { tin: b - .7, anim: 'rise', dur: .4, stagger: .015, gold: true, maxW: 1000 });
  const lp = E.cOut(seg(b, 1.4, 2.4));
  if (lp > 0) {
    rays(540, 900, 20, t * .2, 1200 * lp, 'rgba(255,220,130,1)', .3 * lp, .35);
    glow('gold', 540, 900, 600 * lp, .7 * lp);
    const im = IMG.god, bb = im.bb, h = 760, w = h * bb.w / bb.h;
    g.save(); g.globalAlpha = lp;
    g.drawImage(tint('god', '#FFE7A0'), 0, 0, bb.w, bb.h, 540 - w / 2 - 6, 1300 - h - 6, w + 12, h + 12);
    g.drawImage(tint('god', '#07040F'), 0, 0, bb.w, bb.h, 540 - w / 2, 1300 - h, w, h);
    g.restore();
    title('?', 540, 880, 220 * lp, { tin: 99, gold: true });
  }
  title(tr('COMENTÁ TU RESPUESTA 👇', 'COMMENT YOUR ANSWER 👇'), 540, 1470, 76, { tin: b - 2.5, anim: 'slam', dur: .3, stagger: .02, maxW: 1000 });
}

// ───────────────────────── compositor ─────────────────────────
const BLUR = [[8.35, 8.6, 5], [14.35, 14.6, 5], [20.35, 20.6, 5]];
function drawScene(t) {
  g.setTransform(SCALE, 0, 0, SCALE, 0, 0);
  g.globalAlpha = 1; g.globalCompositeOperation = 'source-over';
  g.fillStyle = '#000'; g.fillRect(0, 0, W, H);
  const sh = shakeAt(t);
  g.save(); g.translate(sh.x, sh.y);
  const wipe = (fn, t0) => {
    // barrido entre rondas
    const p = E.expoInOut(seg(t, t0 - .15, t0 + .15));
    if (p > 0 && p < 1) {
      g.save(); g.translate(-p * W, 0); fn(t - .0001); g.restore();
      return p;
    }
    return 1;
  };
  if (t < 2.5) sceneHook(t);
  else if (t < FINAL) {
    const i = roundAt(t);
    const t0 = ROUNDS[i][0];
    if (i > 0 && t - t0 < .15) {
      const p = E.expoInOut(seg(t, t0 - .15, t0 + .15));
      g.save(); g.translate(-p * W, 0); sceneRound(t, i - 1); g.restore();
      g.save(); g.translate((1 - p) * W, 0); sceneRound(t, i); g.restore();
    } else if ((i < ROUNDS.length - 1 ? ROUNDS[i + 1][0] : FINAL) - t < .15) {
      const nx = i < ROUNDS.length - 1 ? ROUNDS[i + 1][0] : FINAL;
      const p = E.expoInOut(seg(t, nx - .15, nx + .15));
      g.save(); g.translate(-p * W, 0); sceneRound(t, i); g.restore();
      if (i === ROUNDS.length - 1) { g.save(); g.translate((1 - p) * W, 0); sceneFinal(t); g.restore(); }
    } else sceneRound(t, i);
  } else if (t < CTA) {
    if (t - FINAL < .15) {
      const p = E.expoInOut(seg(t, FINAL - .15, FINAL + .15));
      g.save(); g.translate(-p * W, 0); sceneRound(t, 2); g.restore();
      g.save(); g.translate((1 - p) * W, 0); sceneFinal(t); g.restore();
    } else sceneFinal(t);
  } else {
    ctaEnd(t, CTA, EN
      ? { lines: ['DID YOU KNOW IT?', 'FIND OUT BY PLAYING.'], foot: 'Send this to the friend who thinks they know 👇' }
      : { lines: ['¿LA SABÍAS?', 'DESCUBRILA JUGANDO.'], foot: 'Mandáselo al que se cree que sabe 👇' });
    flash(1 - seg(t, CTA, CTA + .25), '#FFF3D0');
  }
  void wipe;
  g.restore();
}

function sceneSetup() {
  for (const [t0] of ROUNDS) impact(t0 + 1.3 + 3 * TICK + .45, 16);
  impact(FINAL + .05, 18); impact(BLACKOUT, 22);
}
window.DURATION = DURATION;
boot();
