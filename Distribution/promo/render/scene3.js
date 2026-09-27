'use strict';
// Reel v3 — «TOP 5 cosas demasiado argentinas de este juego» (34 s, cumbia 100 BPM).
// Ranking con cuenta regresiva: la economía, los especiales, los bonus, las
// pintas y, en el #1, Dios tomando mate y haciendo asado. Textos del juego.

const DURATION = 34;

function assetList() {
  const U = n => RES + 'ui.atlas/' + n + '@3x.png';
  const L = commonAssets({
    b_mate: U('ui_boost_mate'), b_asado: U('ui_boost_asado'), b_milanesa: U('ui_boost_milanesa'),
    face_homeless: U('homeless_face'), card: RES + 'ChestAnim/chest_card_still.png',
    sp_arbolito: RES + 'specials.atlas/sp_arbolito@3x.png', sp_demonio_arca: RES + 'specials.atlas/sp_demonio_arca@3x.png',
    sp_coach: RES + 'specials.atlas/sp_coach@3x.png',
    trapito_idle__naranjita: skinPath('trapito', 'naranjita'), chofer_app_idle__taxi_clasico: skinPath('chofer_app', 'taxi_clasico'),
    rentista_soles_idle__jubilado: skinPath('rentista_soles', 'jubilado'), homeless_idle__mundialista: skinPath('homeless', 'mundialista'),
    god_idle__parrillero: skinPath('god', 'parrillero'),
  });
  for (const b of ['alley', 'urban', 'luxury', 'god_realm']) L['bg_' + b] = RES + 'Backgrounds/bg_' + b + '@3x.png';
  for (const id of ['homeless', 'god']) L[id] = charPath(id);
  return L;
}

const SECTIONS = [ // [t, número, título]
  [2.7, 5, 'LA ECONOMÍA'], [8.2, 4, 'LOS ESPECIALES'], [13.6, 3, 'LOS BONUS'], [18.8, 2, 'LAS PINTAS'],
];
const ARG = ['#75AADB', '#FFFFFF', '#75AADB', '#FFFFFF', C.yellow];

// Sticker del número del ranking: golpea al centro y se acomoda arriba a la izquierda.
function rankSticker(t, t0, n, name, t1) {
  const d = t - t0;
  if (d < 0 || t > t1) return;
  const slam = E.expoOut(seg(d, 0, .3));
  const park = E.cInOut(seg(d, .55, 1.0));
  const x = lerp(540, 150, park), y = lerp(860, 330, park), s = lerp(lerp(3.2, 1.9, slam), .95, park);
  const out = seg(t, t1 - .2, t1);
  g.save(); g.translate(x, y); g.rotate(lerp(-.25, -.08, slam)); g.scale(s * (1 - out), s * (1 - out));
  rr(-95, -85, 190, 170, 42); g.fillStyle = 'rgba(0,0,0,.35)'; g.fill();
  rr(-95, -95, 190, 170, 42); g.fillStyle = C.yellow; g.fill(); g.lineWidth = 10; g.strokeStyle = C.ink; g.stroke();
  g.restore();
  title('#' + n, x, y - 12 * s * (1 - out), 130 * s * (1 - out), { rot: lerp(-.25, -.08, slam) });
  title(name, 620, 330, 96, { tin: d - .6, tout: t > t1 - .3 ? t - (t1 - .3) : null, anim: 'rise', dur: .45, stagger: .03, maxW: 760, gold: true });
}
function jokeCaption(t, str, t0, t1, y = 1390, size = 64) {
  if (t < t0 || t > t1 + .4) return;
  const a = win(t, t0, t1 + .35, .3, .35);
  const lines = str.split('\n');
  g.save(); g.globalAlpha = a;
  const h = lines.length * size * 1.25 + 50;
  rr(60, y - h / 2, 960, h, 36); g.fillStyle = 'rgba(20,14,10,.78)'; g.fill();
  g.restore();
  lines.forEach((l, i) => title(l, 540, y + (i - (lines.length - 1) / 2) * size * 1.25, size, { tin: t - t0 - i * .12, tout: t > t1 ? t - t1 : null, anim: 'rise', dur: .4, stagger: .012, maxW: 900, strokeK: .14, fill: C.cream }));
}
function banner(t, t0, t1, str, color, y = 760) {
  if (t < t0 || t > t1) return;
  const p = E.backOut(seg(t, t0, t0 + .35), 1.8), out = E.cIn(seg(t, t1 - .25, t1));
  g.save(); g.translate(540, y); g.scale(p * (1 - out), p * (1 - out)); g.rotate(-.03);
  rr(-420, -70, 840, 140, 30); g.fillStyle = 'rgba(0,0,0,.35)'; g.fill();
  rr(-420, -80, 840, 140, 30); g.fillStyle = color; g.fill(); g.lineWidth = 9; g.strokeStyle = C.ink; g.stroke();
  g.restore();
  title(str, 540, y - 10, 84, { tin: 99, rot: -.03, alpha: (1 - out) * cl(p), maxW: 780 * p });
}

// ── Hook: DEVALUACIÓN ──
function sceneHook(t) {
  const gr = g.createRadialGradient(540, 900, 100, 540, 900, 1300);
  gr.addColorStop(0, '#3B1E14'); gr.addColorStop(1, '#120906');
  g.fillStyle = gr; g.fillRect(0, 0, W, H);
  g.save(); g.globalAlpha = .15; sunburst(540, 900, 28, t * .2, 'rgba(0,0,0,0)', C.orange, 2400); g.restore();
  const sh = shakeAt(t);
  g.save(); g.translate(sh.x, sh.y);
  const v = t < .42 ? 1e6 : lerp(1e6, 5e5, E.cOut(seg(t, .42, .9)));
  const pin = 1 + Math.sin(Math.min(t, .42) * 18) * .03;
  coinHud(540, 760, v, { sc: 2.3 * pin });
  if (t > .42) {
    const rp = seg(t, .42, 1.2);
    g.save(); g.globalAlpha = (1 - rp) * .5; g.fillStyle = C.pink; g.fillRect(0, 0, W, H); g.restore();
    title('−50%', 860, 610, 110, { tin: t - .5, fill: C.pink, rot: .12 });
  }
  // el sello
  const sp = seg(t, .22, .42);
  if (sp > 0) {
    const s = lerp(3.2, 1, E.expoIn(sp));
    g.save(); g.translate(540, 1010); g.rotate(-.16); g.scale(s, s); g.globalAlpha = cl(sp * 3);
    rr(-430, -110, 860, 220, 26); g.fillStyle = 'rgba(255,248,231,.92)'; g.fill();
    g.lineWidth = 16; g.strokeStyle = '#D7263D';
    rr(-430, -110, 860, 220, 26); g.stroke();
    g.lineWidth = 6; rr(-405, -86, 810, 172, 18); g.stroke();
    g.restore();
    title('DEVALUACIÓN', 540, 1005, 128, { tin: 99, rot: -.16, fill: '#D7263D', stroke: '#D7263D', shadowColor: 'rgba(0,0,0,0)', strokeK: .02, alpha: cl(sp * 3), maxW: 780 * s });
  }
  burst(t, { t0: .42, x: 540, y: 1000, n: 30, seed: 3300, kind: 'spark', spd: [900, 2400], grav: 600, life: [.3, .6], size: [6, 12], drag: 3, color: 'rgba(255,90,90,1)' });
  if (t < .42) burst(t, { t0: 0, x: 540, y: 760, n: 24, seed: 3301, kind: 'star', spd: [200, 700], life: [.5, .8], size: [40, 80], drag: 2 });
  g.restore();
  title('ESTE JUEGO ES', 540, 330, 100, { tin: t - .95, anim: 'rise', dur: .45, stagger: .025 });
  title('DEMASIADO ARGENTINO 💀', 540, 450, 96, { tin: t - 1.15, anim: 'rise', dur: .45, stagger: .02, gold: true, maxW: 1000 });
  const cp = E.backOut(seg(t, 1.8, 2.1), 2);
  if (cp > 0) {
    g.save(); g.translate(540, 1420); g.scale(cp, cp);
    pill(0, 0, 700, 104, { fill: C.yellow, stroke: C.ink, lw: 7 });
    text('TOP 5 · EL #1 ES VERDAD', 0, 6, 52, C.ink, { font: FONT_T, weight: 800 });
    g.restore();
  }
  if (t >= .42) flash(1 - seg(t, .42, .5), '#FFFFFF');
}

// ── #5 La economía ──
function chains(cx, cy, w, a) {
  if (a <= 0) return;
  g.save(); g.globalAlpha = a;
  for (const dir of [-1, 1]) {
    g.save(); g.translate(cx, cy); g.rotate(dir * .32);
    for (let i = -7; i <= 7; i++) {
      g.save(); g.translate(i * 64, 0); if (i % 2) g.scale(1, .45);
      g.beginPath(); g.ellipse(0, 0, 40, 26, 0, 0, Math.PI * 2);
      g.lineWidth = 20; g.strokeStyle = C.ink; g.stroke();
      g.lineWidth = 11; g.strokeStyle = '#B8BCC4'; g.stroke();
      g.restore();
    }
    g.restore();
  }
  // candado
  g.translate(cx, cy + 20);
  g.lineWidth = 22; g.strokeStyle = C.ink; g.beginPath(); g.arc(0, -40, 50, Math.PI, 0); g.stroke();
  g.lineWidth = 12; g.strokeStyle = '#B8BCC4'; g.stroke();
  rr(-80, -40, 160, 130, 22); g.fillStyle = C.yellow; g.fill(); g.lineWidth = 8; g.strokeStyle = C.ink; g.stroke();
  g.fillStyle = C.ink; g.beginPath(); g.arc(0, 15, 16, 0, Math.PI * 2); g.fill(); g.fillRect(-6, 15, 12, 40);
  g.restore();
}
function sceneEconomy(t) {
  const sh = shakeAt(t);
  g.save(); g.translate(sh.x, sh.y);
  drawBg(IMG.bg_alley, { zoom: 1.2 + (t - 2.7) * .012, x: -30, y: 80 });
  shade(.35);
  // plata: sube con el aguinaldo y se va enseguida
  let v = 184000;
  if (t > 6.6) v = lerp(184000, 1.9e6, E.cOut(seg(t, 6.6, 7.3)));
  if (t > 7.75) v = lerp(1.9e6, 12, E.expoIn(seg(t, 7.75, 8.05)));
  coinHud(540, 560, v, { sc: 1.6 });
  // el Fisura toca el contador bloqueado
  let sq = 0;
  for (const tt of [3.55, 3.85, 4.1, 4.3]) { const d = t - tt; if (d >= 0 && d < .2) sq = Math.sin(d / .2 * Math.PI) * .1; }
  const happy = t > 6.6 && t < 7.75 ? Math.abs(Math.sin((t - 6.6) * 9)) * .06 : 0;
  drawChar('homeless', 540, 1330, 700, { sy: 1 - sq + happy, sx: 1 + sq * .6 });
  for (const tt of [3.55, 3.85, 4.1, 4.3]) {
    const d = t - tt;
    if (d >= 0 && d < .4) { drawImg(IMG.fx_tap, 640, 600, 120 + 200 * E.expoOut(seg(d, 0, .35)), { alpha: 1 - seg(d, .1, .4) }); title('✖', 760, 470 - d * 60, 80, { fill: C.pink, alpha: 1 - seg(d, .25, .4) }); }
  }
  chains(540, 560, 800, E.backOut(seg(t, 3.25, 3.55), 1.5) * (1 - seg(t, 4.7, 4.9)));
  // Mercado Pago: el precio se duplica
  if (t > 4.95 && t < 6.5) {
    const a = win(t, 4.95, 6.5, .25, .25);
    g.save(); g.globalAlpha = a; g.translate(540, 1000); g.rotate(.04);
    rr(-250, -70, 500, 140, 70); g.fillStyle = '#fff'; g.fill(); g.lineWidth = 7; g.strokeStyle = C.ink; g.stroke();
    g.save(); g.beginPath(); g.arc(-180, 0, 50, 0, Math.PI * 2); g.clip(); g.drawImage(IMG.face_homeless, -232, -52, 104, 104); g.restore();
    text('El Fisura', -110, -24, 40, C.ink, { align: 'left' });
    g.drawImage(IMG.coin, -110, 8, 48, 48);
    const dbl = seg(t, 5.45, 5.6);
    text('25', -50, 34, 48, dbl > 0 ? '#999' : C.ink, { align: 'left' });
    if (dbl > 0) { g.lineWidth = 7; g.strokeStyle = C.pink; g.beginPath(); g.moveTo(-56, 34); g.lineTo(-56 + 70 * dbl, 34); g.stroke(); }
    if (t > 5.6) title('50', 80, 30, 80 * E.backOut(seg(t, 5.6, 5.85), 2.5), { fill: C.pink });
    g.restore();
  }
  burst(t, { t0: 6.6, x: 540, y: -60, n: 70, seed: 3400, kind: 'coin', spd: [100, 300], ang: [Math.PI * .35, Math.PI * .65], grav: 1500, life: [1.3, 1.8], size: [60, 110], spread: 1100, delay: .7 });
  burst(t, { t0: 6.6, x: 540, y: -60, n: 20, seed: 3401, kind: 'bill', spd: [100, 250], ang: [Math.PI * .35, Math.PI * .65], grav: 700, life: [1.5, 2], size: [120, 170], spread: 1100, delay: .7 });
  g.restore();
  banner(t, 3.2, 4.9, '¡CORRALITO!', '#D7263D');
  banner(t, 4.9, 6.5, 'SE CAYÓ MERCADO PAGO', '#D7263D');
  banner(t, 6.5, 8.1, '¡LLEGÓ EL AGUINALDO!', '#E8A317');
  jokeCaption(t, 'Tus coins están ahí…\npero no las podés tocar. ¿Te suena?', 3.4, 4.85);
  jokeCaption(t, 'Nadie puede pagar nada.\nTodo sale el doble en efectivo.', 5.05, 6.45);
  jokeCaption(t, 'Disfrutalo: dura menos\nque un helado en enero.', 6.7, 7.7);
  if (t > 7.8 && t < 8.2) title('…ya se fue.', 540, 1000, 110, { tin: t - 7.8, fill: C.pink, anim: 'slam', dur: .2 });
}

// ── #4 Los especiales (frente al Obelisco) ──
const SPECIALS = [
  [9.3, 'sp_arbolito', 'El del Arbolito', '¡Cambio, cambio, cambiooo!', 'Te consigue todo 5% más barato.\nNo preguntes de dónde.'],
  [10.75, 'sp_demonio_arca', 'Demonio de ARCA', null, 'Vino a auditarte\ny se quedó a vivir.'],
  [12.15, 'sp_coach', 'Coach Ontológico', '¿Y si el sueldo era un límite que te ponías vos?', '+2% de income,\n−100% de paciencia.'],
];
function specialCard(id, name, x, y, s, flip, a, glowA) {
  if (s <= 0 || a <= 0) return;
  const cw = 800, ch = cw * IMG.card.height / IMG.card.width;
  g.save(); g.translate(x, y); g.scale(s * Math.max(.02, flip), s); g.globalAlpha = a;
  if (glowA > 0) glow('gold', 0, 0, 420, glowA);
  g.drawImage(IMG.card, -cw / 2, -ch / 2, cw, ch);
  if (flip > .5) drawChar(id, 0, ch * .19, ch * .37, { shadow: false });
  g.restore();
  if (flip > .5) {
    g.save(); g.globalAlpha = a;
    title(name.toUpperCase(), x, y + ch * s * .25, 70 * s, { maxW: 800 * s });
    g.restore();
  }
}
function sceneSpecials(t) {
  const d = t - 8.2;
  const sh = shakeAt(t);
  g.save(); g.translate(sh.x, sh.y);
  // la cámara baja por el Obelisco
  const tilt = E.cInOut(seg(d, 0, 1.1));
  drawBg(IMG.bg_urban, { zoom: lerp(2.3, 1.15, tilt), x: lerp(-260, 0, tilt), y: lerp(900, 60, tilt) });
  shade(lerp(0, .45, seg(d, .9, 1.2)));
  if (d < 1.1) {
    g.save(); g.globalAlpha = win(t, 8.25, 9.2, .2, .2);
    pill(540, 1450, 440, 90, { fill: C.cream, stroke: C.ink });
    text('📍 El Obelisco', 540, 1455, 46, C.ink, { font: `${FONT_T}, "Noto Color Emoji"`, weight: 800 });
    g.restore();
  }
  SPECIALS.forEach(([t0, id, name, bubble, flav], i) => {
    const next = SPECIALS[i + 1] ? SPECIALS[i + 1][0] : 13.55;
    if (t < t0) return;
    const flip = E.cOut(seg(t, t0, t0 + .4));
    const leave = E.cInOut(seg(t, next - .2, next + .2));
    const x = lerp(540, -300, leave), s = lerp(1, .55, leave);
    specialCard(id, name, x, 900, s, flip, 1 - seg(t, next + .05, next + .25), .5 * (1 - leave));
    burst(t, { t0: t0 + .2, x: 540, y: 900, n: 26, seed: 3500 + i, kind: 'star', spd: [300, 900], life: [.6, 1], size: [30, 60], drag: 2 });
    if (bubble) speech(540, 480, 900, bubble, 640, 640, { s: E.backOut(seg(t, t0 + .35, t0 + .6), 1.8) * (1 - seg(t, next - .25, next - .05)), size: 48 });
    jokeCaption(t, flav, t0 + .45, next - .15, 1480, 58);
  });
  g.restore();
}

// ── #3 Los bonus ──
const FOODS = [
  [13.9, 'b_mate', 'UNOS MATES', 'Ronda de mates y el equipo rinde.\nEl termo es de todos.'],
  [15.5, 'b_asado', 'ASADO DEL DOMINGO', 'El asador no se apura,\npero nunca falla.'],
  [17.1, 'b_milanesa', 'MILANESA', 'Napolitana con fritas. Dormís como\nun lirón y te despertás más rico.'],
];
function sceneBonus(t) {
  sunburst(540, 860, 24, t * .25, C.orange, '#FF8A4C');
  glow('warm', 540, 860, 900, .6);
  const gr = g.createRadialGradient(540, 900, 300, 540, 960, 1400);
  gr.addColorStop(0, 'rgba(0,0,0,0)'); gr.addColorStop(1, 'rgba(40,10,0,.6)');
  g.fillStyle = gr; g.fillRect(0, 0, W, H);
  FOODS.forEach(([t0, key, name, flav], i) => {
    const next = FOODS[i + 1] ? FOODS[i + 1][0] : 18.75;
    if (t < t0 - .05 || t > next + .1) return;
    const pin = E.backOut(seg(t, t0, t0 + .45), 1.7);
    const out = E.cIn(seg(t, next - .2, next + .05));
    const s = 720 * pin * (1 - out * .8);
    const rot = Math.sin((t - t0) * 2.2) * .05 + out * 1.5;
    drawImg(IMG[key], 540 + out * 700, 860, s, { rot, alpha: 1 - out });
    // humito
    for (let k = 0; k < 5; k++) {
      const ph = ((t - t0) * .7 + k / 5) % 1;
      glow('white', 470 + k * 35 + Math.sin(ph * 6 + k) * 30, 560 - ph * 260, 60 + ph * 50, (1 - ph) * .35 * (1 - out));
    }
    title(name, 540, 1220, 96, { tin: t - t0 - .15, tout: t > next - .2 ? t - (next - .2) : null, anim: 'rise', dur: .4, maxW: 960 });
    jokeCaption(t, flav, t0 + .3, next - .2, 1420, 56);
  });
}

// ── #2 Las pintas: desfile en Puerto Madero ──
const RUNWAY = [
  [19.3, 'trapito_idle__naranjita', 'NARANJITA'], [20.5, 'chofer_app_idle__taxi_clasico', 'TAXI CLÁSICO'],
  [21.7, 'rentista_soles_idle__jubilado', 'JUBILADO'], [22.9, 'homeless_idle__mundialista', 'MUNDIALISTA'],
];
function sceneSkins(t) {
  const d = t - 18.8;
  drawBg(IMG.bg_luxury, { zoom: 1.12 + d * .01, x: -d * 8, y: 40 });
  shade(.2);
  if (d < 1.3) {
    g.save(); g.globalAlpha = win(t, 18.85, 20.1, .2, .25);
    pill(540, 1520, 520, 90, { fill: C.cream, stroke: C.ink });
    text('📍 Puerto Madero', 540, 1525, 46, C.ink, { font: `${FONT_T}, "Noto Color Emoji"`, weight: 800 });
    g.restore();
  }
  RUNWAY.forEach(([t0, id, name], i) => {
    const last = i === RUNWAY.length - 1;
    const next = last ? 24.6 : RUNWAY[i + 1][0];
    if (t < t0 || t > next + .3) return;
    const inP = E.cOut(seg(t, t0, t0 + .5));
    const outP = last ? 0 : E.cIn(seg(t, next - .15, next + .3));
    const x = lerp(1300, 540, inP) + lerp(0, -900, outP);
    const walk = (inP < 1 || outP > 0) ? Math.abs(Math.sin((t - t0) * 11)) : 0;
    const pose = seg(t, t0 + .5, t0 + .65);
    const h = last ? 820 : 760;
    drawChar(id, x, 1400 - walk * 16, h * (1 + Math.sin(pose * Math.PI) * .05), { rot: (inP < 1 || outP > 0) ? Math.sin((t - t0) * 11) * .04 : 0 });
    // flashes de fotógrafos
    const r = rng(3600 + i);
    for (let k = 0; k < 6; k++) {
      const ft = t0 + .5 + r() * .6, fx = 120 + r() * 840, fy = 700 + r() * 700;
      const fd = t - ft;
      if (fd >= 0 && fd < .12) { glow('white', fx, fy, 160, 1 - fd / .12); star4(fx, fy, 50 * (1 - fd / .12), '#fff'); }
    }
    title(name, 540, 510, last ? 130 : 110, { tin: t - t0 - .45, tout: !last && t > next - .15 ? t - (next - .15) : null, anim: 'slam', dur: .3, gold: last, maxW: 980 });
  });
  burst(t, { t0: 23.4, x: 540, y: 300, n: 90, seed: 3700, kind: 'confetti', spd: [600, 1800], ang: [-Math.PI * .9, -Math.PI * .1], grav: 1300, life: [1.5, 2.2], size: [26, 40], drag: 1.4, colors: ARG });
  jokeCaption(t, 'Hay 45 pintas. ¿Cuál te falta?', 23.7, 24.45, 1560, 58);
}

// ── #1 Dios es argentino ──
function sceneGod(t) {
  if (t < 25.55) {
    g.fillStyle = '#050407'; g.fillRect(0, 0, W, H);
    title('Y EL #1…', 540, 900, 150, { tin: t - 24.75, anim: 'rise', dur: .5, stagger: .06 });
    return;
  }
  const sh = shakeAt(t);
  g.save(); g.translate(sh.x, sh.y);
  const rise = E.expoOut(seg(t, 25.6, 26.4));
  const zoomMate = E.cInOut(seg(t, 26.9, 27.4)) * (1 - E.cInOut(seg(t, 28.0, 28.5)));
  const z = 1 + zoomMate * 1.4;
  g.translate(540, 900); g.scale(z, z); g.translate(-540 - zoomMate * 150, -900 + zoomMate * 120);
  drawBg(IMG.bg_god_realm, { zoom: 1.2, y: lerp(600, 120, rise) });
  shade(.25, '#120A2E');
  const hp = E.expoOut(seg(t, 25.8, 26.6));
  rays(540, 700, 22, t * .25, 1500 * hp, 'rgba(255,225,120,1)', .3 * hp, .4);
  glow('gold', 540, 600, 700 * hp, .5 * hp);
  const gy = lerp(1900, 1450, rise) + Math.sin(t * 2.2) * 12;
  const swap = seg(t, 28.0, 28.15);
  drawChar('god', 540, gy, 1000, { shadow: false, alpha: 1 - swap });
  if (swap > 0) drawChar('god_idle__parrillero', 540, gy, 1000, { shadow: false, alpha: swap, white: 1 - seg(t, 28.0, 28.4) });
  if (t > 28.0) for (let k = 0; k < 7; k++) {
    const ph = ((t - 28) * .6 + k / 7) % 1;
    glow('white', 380 + k * 20 + Math.sin(ph * 5 + k) * 40, 950 - ph * 500, 70 + ph * 80, (1 - ph) * .35);
  }
  g.restore();
  burst(t, { t0: 29.0, x: 540, y: 250, n: 110, seed: 3800, kind: 'confetti', spd: [500, 1700], ang: [-Math.PI * .95, -Math.PI * .05], grav: 1200, life: [1.6, 2.2], size: [26, 40], drag: 1.3, colors: ARG });
  title('DIOS EXISTE.', 540, 330, 130, { tin: t - 25.85, tout: t > 26.85 ? t - 26.85 : null, anim: 'rise', dur: .45, stagger: .04 });
  title('Y TOMA MATE. 🧉', 540, 330, 118, { tin: t - 27.0, tout: t > 27.95 ? t - 27.95 : null, anim: 'rise', dur: .4, stagger: .03, maxW: 1000 });
  title('Y HACE ASADO. 🔥', 540, 330, 118, { tin: t - 28.2, tout: t > 28.95 ? t - 28.95 : null, anim: 'rise', dur: .4, stagger: .03, maxW: 1000 });
  title('DIOS ES', 540, 300, 150, { tin: t - 29.0, anim: 'slam', dur: .3, stagger: .05 });
  title('ARGENTINO.', 540, 450, 160, { tin: t - 29.2, anim: 'slam', dur: .3, stagger: .05, gold: true, maxW: 1000 });
  flash(seg(t, 30.3, 30.5), '#FFF3D0');
}

// ───────────────────────── compositor ─────────────────────────
const BLUR = [[2.55, 2.85, 5], [8.1, 8.35, 5], [13.5, 13.75, 5], [18.7, 18.95, 5], [26.9, 27.4, 4], [28.0, 28.5, 4]];
function sectionFrame(t, fn, t0, t1) {
  // entrada y salida con barrido lateral
  const inP = E.expoOut(seg(t, t0 - .12, t0 + .18)), outP = E.expoIn(seg(t, t1 - .15, t1 + .1));
  g.save(); g.translate((1 - inP) * W - outP * W, 0); fn(t); g.restore();
}
function drawScene(t) {
  g.setTransform(SCALE, 0, 0, SCALE, 0, 0);
  g.globalAlpha = 1; g.globalCompositeOperation = 'source-over';
  g.fillStyle = '#000'; g.fillRect(0, 0, W, H);
  if (t < 2.85) sectionFrame(t, sceneHook, -1, 2.7);
  if (t > 2.55 && t < 8.35) sectionFrame(t, sceneEconomy, 2.7, 8.2);
  if (t > 8.05 && t < 13.75) sectionFrame(t, sceneSpecials, 8.2, 13.6);
  if (t > 13.45 && t < 18.95) sectionFrame(t, sceneBonus, 13.6, 18.8);
  if (t > 18.65 && t < 24.7) sectionFrame(t, sceneSkins, 18.8, 99);
  if (t >= 24.6 && t < 30.5) { g.save(); g.globalAlpha = seg(t, 24.6, 24.75); sceneGod(t); g.restore(); }
  if (t >= 30.5) ctaEnd(t, 30.5, { lines: ['ESTÁ EN EL NIVEL 37.', '¿LLEGÁS?'], foot: 'Etiquetá al más fisura de tu grupo 👇' });
  for (const [t0, n, name] of SECTIONS) {
    const t1 = SECTIONS.find(s => s[0] > t0) ? SECTIONS.find(s => s[0] > t0)[0] - .05 : 24.55;
    rankSticker(t, t0, n, name, t1);
  }
  if (t >= 30.5) flash(1 - seg(t, 30.5, 30.75), '#FFF3D0');
}

function sceneSetup() {
  impact(.42, 40); impact(3.3, 14); impact(5.6, 8); impact(6.6, 10);
  for (const [t0] of SECTIONS) impact(t0 + .05, 16);
  impact(25.6, 18); impact(28.0, 12); impact(29.0, 24);
}
window.DURATION = DURATION;
boot();
