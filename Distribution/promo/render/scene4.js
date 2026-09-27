'use strict';
// Reel v4 — «De la calle a Puerto Madero: DÍA 1 → DÍA 365» (35 s, lofi 90 BPM).
// Vlog en primera persona: REC, contador de días, pin de ubicación, globos
// y los logros reales del juego. El día 365 es una silueta que no se revela.

const DURATION = 35;

function assetList() {
  const L = commonAssets({
    trapito_idle__naranjita: skinPath('trapito', 'naranjita'), chofer_app_idle__taxi_clasico: skinPath('chofer_app', 'taxi_clasico'),
    junior_lawyer_idle__tribunales: skinPath('junior_lawyer', 'tribunales'), millonario_idle__yate: skinPath('millonario', 'yate'),
    space_billionaire_idle__traje_presurizado: skinPath('space_billionaire', 'traje_presurizado'),
    face_homeless: RES + 'ui.atlas/homeless_face@3x.png',
  });
  for (const b of ['alley', 'urban', 'corporate', 'luxury', 'island', 'moon', 'god_realm']) L['bg_' + b] = RES + 'Backgrounds/bg_' + b + '@3x.png';
  for (const id of ['homeless', 'rey_ladrillo', 'god']) L[id] = charPath(id);
  return L;
}

// [inicio, día, fondo, personaje, lugar, globos [[t, texto]], logro [t0, t1, nombre]]
const DAYS = [
  [0.0, 1, 'alley', 'homeless', 'Callejón · CABA', [[2.05, 'Tengo un cartón y fe.']], null],
  [3.2, 3, 'alley', 'trapito_idle__naranjita', 'Callejón · CABA', [[3.5, '¿Te lo cuido, jefe?'], [4.85, 'Tranqui, no le va a pasar nada. Casi seguro.']], [4.3, 5.9, 'El primer junte']],
  [6.2, 9, 'urban', 'chofer_app_idle__taxi_clasico', 'El Obelisco', [[7.3, '¿Vamos por el Obelisco? Es más largo, pero más lindo.']], [8.4, 9.95, 'Chau, callejón']],
  [10.2, 21, 'corporate', 'junior_lawyer_idle__tribunales', 'Microcentro', [[10.55, 'Me recibí en la UBA.'], [11.8, 'No paga el alquiler, pero emociona.']], [12.0, 13.45, 'Papá, me recibí']],
  [13.6, 60, 'luxury', 'millonario_idle__yate', 'Puerto Madero', [[14.2, 'Me compré un yate.'], [16.0, 'Bueno… una foto con el yate.']], [16.4, 18.2, 'Cochera con tu nombre']],
  [18.4, 120, 'island', 'rey_ladrillo', 'Una isla (offshore)', [[18.8, 'Invierto offshore.'], [19.95, 'Todo en regla. Creeme.']], [20.2, 21.8, 'Offshore y todo en regla']],
  [22.0, 200, 'moon', 'space_billionaire_idle__traje_presurizado', 'La Luna', [[22.35, 'Me compré la Luna.'], [23.45, 'Acá no llega la inflación… todavía.']], [23.6, 25.05, 'Un pasito para el Fisura']],
];
const GLITCH0 = 25.2, D365 = 26.4, CTA = 30.6;

function dayAt(t) { let i = 0; for (let k = 0; k < DAYS.length; k++) if (t >= DAYS[k][0]) i = k; return i; }

// Cámara en mano: deriva suave, siempre viva.
function handheld(t) {
  return { x: noise(t * .9, 1) * 10, y: noise(t * .8, 7) * 8, r: noise(t * .6, 3) * .006 };
}

function drawDay(t, i) {
  const [t0, day, bg, id] = DAYS[i];
  const next = DAYS[i + 1] ? DAYS[i + 1][0] : GLITCH0;
  const d = t - t0;
  const hh = handheld(t);
  g.save();
  g.translate(540 + hh.x, 960 + hh.y); g.rotate(hh.r); g.translate(-540, -960);
  if (bg === 'urban') {
    // arranca arriba del Obelisco y baja hasta el taxi
    const tilt = E.cInOut(seg(d, .1, 1.3));
    drawBg(IMG.bg_urban, { zoom: lerp(2.4, 1.18, tilt), x: lerp(-280, 0, tilt), y: lerp(950, 70, tilt) });
  } else if (bg === 'luxury') {
    drawBg(IMG.bg_luxury, { zoom: 1.3 - d * .02, x: 160 - d * 55, y: 60 });
  } else if (bg === 'moon') {
    drawBg(IMG.bg_moon, { zoom: 1.2 + d * .015, y: 70 });
  } else {
    drawBg(IMG['bg_' + bg], { zoom: 1.18 + d * .015, x: -d * 10, y: 70 });
  }
  shade(i === 0 ? .42 : .22);
  // el personaje entra al día con un pequeño salto
  const inP = E.backOut(seg(d, .05, .45), 1.6);
  const talk = (DAYS[i][5].some(([bt]) => t > bt && t < bt + .9)) ? Math.abs(Math.sin(t * 16)) * .015 : 0;
  const shrug = i === 4 ? Math.sin(seg(t, 16.0, 16.5) * Math.PI) * .07 : 0;
  const h = id === 'rey_ladrillo' ? 740 : 700;
  drawChar(id, 540, 1400, h * inP, { sy: 1 + talk - shrug, sx: 1 + shrug * .5 });
  g.restore();
  // globos: uno a la vez
  const bubbles = DAYS[i][5];
  bubbles.forEach(([bt, str], k) => {
    const bend = bubbles[k + 1] ? bubbles[k + 1][0] - .05 : next - .2;
    if (t < bt || t > bend) return;
    const s = E.backOut(seg(t, bt, bt + .3), 2) * (1 - E.cIn(seg(t, bend - .15, bend)));
    speech(540, 590, 900, str, 600, 730, { s, size: 50 });
  });
  if (DAYS[i][6]) achievement(t, ...DAYS[i][6], 1480);
}

// Interfaz del vlog (siempre arriba).
function vlogUI(t, dayNum, place, a = 1) {
  if (a <= 0) return;
  g.save(); g.globalAlpha = a;
  // esquinas del visor
  g.strokeStyle = 'rgba(255,255,255,.85)'; g.lineWidth = 7; g.lineCap = 'round';
  for (const [x, y, sx, sy] of [[70, 225, 1, 1], [1010, 225, -1, 1], [70, 1575, 1, -1], [1010, 1575, -1, -1]]) {
    g.beginPath(); g.moveTo(x, y + sy * 70); g.lineTo(x, y); g.lineTo(x + sx * 70, y); g.stroke();
  }
  // progreso del año
  const p = cl(dayNum / 365);
  rr(110, 250, 860, 16, 8); g.fillStyle = 'rgba(255,255,255,.3)'; g.fill();
  rr(110, 250, Math.max(16, 860 * p), 16, 8); g.fillStyle = C.orange; g.fill();
  g.beginPath(); g.arc(110 + 860 * p, 258, 15, 0, Math.PI * 2); g.fillStyle = C.cream; g.fill(); g.lineWidth = 4; g.strokeStyle = C.ink; g.stroke();
  // REC
  if (Math.floor(t * 1.6) % 2 === 0) { g.beginPath(); g.arc(128, 350, 17, 0, Math.PI * 2); g.fillStyle = '#E3342F'; g.fill(); }
  text('REC', 200, 352, 40, '#fff', { stroke: 6 });
  text(`${dayNum}/365`, 950, 352, 34, 'rgba(255,255,255,.9)', { stroke: 6, align: 'right' });
  g.restore();
  title('DÍA ' + dayNum, 540, 360, 120, { tin: 99, gold: true, alpha: a });
  if (place) {
    g.save(); g.globalAlpha = a;
    g.font = `800 42px ${FONT_T}`;
    const w = g.measureText('📍 ' + place).width + 70;
    pill(540, 470, w, 76, { fill: C.cream, stroke: C.ink, alpha: a });
    text('📍 ' + place, 540, 475, 42, C.ink, { font: `${FONT_T}, "Noto Color Emoji"`, weight: 800 });
    g.restore();
  }
}

function sceneGlitch(t) {
  const d = t - GLITCH0, p = seg(t, GLITCH0, D365);
  // el último día visible, roto
  drawDay(t, DAYS.length - 1);
  const r = rng(Math.floor(t * 30) + 7);
  for (let k = 0; k < 14; k++) {
    const y = r() * H, h = 10 + r() * 90, off = (r() - .5) * 160 * (0.4 + p);
    g.drawImage(g.canvas, 0, y * SCALE, W * SCALE, h * SCALE, off, y, W, h);
  }
  g.save(); g.globalAlpha = .25 + p * .5;
  for (let k = 0; k < 400; k++) { g.fillStyle = r() < .5 ? '#fff' : '#000'; g.fillRect(r() * W, r() * H, 3 + r() * 6, 2 + r() * 4); }
  g.restore();
  g.save(); g.globalCompositeOperation = 'lighter'; g.globalAlpha = .18; g.fillStyle = r() < .5 ? '#ff004c' : '#00e5ff'; g.fillRect(0, 0, W, H); g.restore();
  shade(p * .8);
  if (d > .25) title('SEÑAL PERDIDA', 540, 960, 100, { tin: 99, fill: '#fff', alpha: Math.floor(t * 12) % 2 ? 1 : .5 });
}

function scene365(t) {
  const d = t - D365;
  drawBg(IMG.bg_god_realm, { zoom: 1.25 + d * .03, y: 120 });
  shade(.8, '#07040F');
  const lp = E.cOut(seg(d, 0, 1.2));
  rays(540, 820, 20, t * .15, 1400 * lp, 'rgba(255,220,130,1)', .32 * lp, .35);
  glow('gold', 540, 820, 700 * lp, .7 * lp);
  // silueta: nadie sabe quién es
  const im = IMG.god, bb = im.bb, h = 900, w = h * bb.w / bb.h;
  g.save(); g.globalAlpha = lp;
  g.drawImage(tint('god', '#FFE7A0'), 0, 0, bb.w, bb.h, 540 - w / 2 - 6, 1400 - h - 6, w + 12, h + 12);
  g.drawImage(tint('god', '#07040F'), 0, 0, bb.w, bb.h, 540 - w / 2, 1400 - h, w, h);
  g.restore();
  burst(t, { t0: D365, x: 540, y: 1500, n: 50, seed: 4100, kind: 'dust', spd: [60, 160], ang: [-Math.PI * .7, -Math.PI * .3], life: [2.5, 3.5], size: [12, 30], spread: 900, delay: 2, alpha: .6 });
  const bs = E.backOut(seg(t, D365 + .5, D365 + .8), 2) * (1 - seg(t, 27.9, 28.05));
  speech(540, 590, 300, '…', 560, 730, { s: bs, size: 60 });
  title('¿QUIÉN SOY?', 540, 620, 140, { tin: t - 28.0, tout: t > 30.2 ? t - 30.2 : null, anim: 'slam', dur: .35, stagger: .05, gold: true });
  // la tarjeta para compartir del juego
  const cp = E.backOut(seg(t, 28.7, 29.1), 1.6) * (1 - E.cIn(seg(t, 30.3, 30.55)));
  if (cp > 0) {
    g.save(); g.translate(540, 1480); g.rotate(-.03); g.scale(cp, cp);
    rr(-450, -95, 900, 190, 40); g.fillStyle = 'rgba(0,0,0,.35)'; g.fill();
    rr(-450, -105, 900, 190, 40); g.fillStyle = '#fff'; g.fill(); g.lineWidth = 6; g.strokeStyle = C.ink; g.stroke();
    g.save(); g.beginPath(); g.arc(-360, -10, 62, 0, Math.PI * 2); g.clip(); g.drawImage(IMG.face_homeless, -424, -74, 128, 128); g.restore();
    text('Llegué al nivel 37 y vos', 40, -42, 46, C.ink, { maxW: 640 });
    text('seguís de fisura 💀', 40, 22, 46, C.ink, { maxW: 640, font: `${FONT_N}, "Noto Color Emoji"` });
    g.restore();
  }
}

// ───────────────────────── compositor ─────────────────────────
const BLUR = DAYS.slice(1).map(([t0]) => [t0 - .14, t0 + .12, 6]).concat([[GLITCH0 - .05, D365 + .05, 3]]);
function drawScene(t) {
  g.setTransform(SCALE, 0, 0, SCALE, 0, 0);
  g.globalAlpha = 1; g.globalCompositeOperation = 'source-over';
  g.fillStyle = '#000'; g.fillRect(0, 0, W, H);
  if (t < GLITCH0) {
    const i = dayAt(t);
    const t0 = DAYS[i][0];
    // whip entre días
    const nxt = DAYS[i + 1] ? DAYS[i + 1][0] : null;
    if (i > 0 && t - t0 < .14) {
      const p = E.expoOut(seg(t, t0, t0 + .14));
      g.save(); g.translate(-W * (.5 + p * .6), 0); drawDay(t, i - 1); g.restore();
      g.save(); g.translate(W * (1 - p) * .9, 0); drawDay(t, i); g.restore();
    } else if (nxt && nxt - t < .14) {
      const p = E.expoIn(seg(t, nxt - .14, nxt));
      g.save(); g.translate(-W * p * .5, 0); drawDay(t, i); g.restore();
    } else drawDay(t, i);
    // número del día rodando en el salto
    let dn = DAYS[i][1];
    if (i > 0 && t - t0 < .5) dn = Math.round(lerp(DAYS[i - 1][1], DAYS[i][1], E.cOut(seg(t, t0, t0 + .5))));
    vlogUI(t, dn, DAYS[i][4]);
    // hook sobre el día 1
    if (t < 2.1) {
      const a = 1 - seg(t, 1.8, 2.05);
      g.save(); g.globalAlpha = a * .8; rr(40, 1000, 1000, 470, 44); g.fillStyle = 'rgba(15,10,6,.8)'; g.fill(); g.restore();
      title('ME FUI DE LA CALLE', 540, 1080, 92, { tin: t + .1, alpha: a, stagger: .018, dur: .35, maxW: 960 });
      title('A PUERTO MADERO', 540, 1195, 104, { tin: t - .1, alpha: a, stagger: .018, dur: .35, gold: true, maxW: 960 });
      title('EN UN AÑO', 540, 1310, 92, { tin: t - .3, alpha: a, stagger: .02, dur: .35 });
      title('(el día 365 no me lo creo ni yo)', 540, 1415, 44, { tin: t - .6, alpha: a, stagger: .008, dur: .3, strokeK: .15, maxW: 900 });
    }
  } else if (t < D365) {
    sceneGlitch(t);
    const dn = Math.round(lerp(200, 365, E.expoIn(seg(t, GLITCH0 + .2, D365 - .1))));
    vlogUI(t, dn, null, Math.floor(t * 14) % 3 ? 1 : .3);
  } else if (t < CTA) {
    scene365(t);
    vlogUI(t, 365, '???', 1 - seg(t, 30.3, 30.55));
  } else {
    ctaEnd(t, CTA, { lines: ['37 NIVELES.', '¿HASTA DÓNDE LLEGÁS?'], foot: 'Etiquetá al que sigue de fisura 👇' });
    flash(1 - seg(t, CTA, CTA + .25), '#FFF3D0');
  }
}

function sceneSetup() {
  for (const [t0] of DAYS.slice(1)) impact(t0, 8);
  impact(GLITCH0, 14); impact(D365 + .02, 10);
}
window.DURATION = DURATION;
boot();
