'use strict';
// Reel v8 · MOFU — «Tomi vs. Sofi: ¿quién llega más lejos?» (36 s).
// Pantalla partida: dos estrategias sobre el mismo juego. Cada decisión tiene
// su consecuencia visible (fusionar, piso lleno, bonus/mejoras, reencarnar).
// Pisos y niveles según economy.json → floors y tiers.json.

const DURATION = 36;
const HW = 540;
const BLUE = '#3F7FE0', ORANGE = C.orange;

function assetList() {
  const U = n => RES + 'ui.atlas/' + n + '@3x.png';
  const L = commonAssets({
    b_mate: U('ui_boost_mate'), up_income: U('ui_up_income'), oro: U('ui_oro'), reincarnate: U('ui_btn_reincarnate'),
    homeless_idle__second_life: skinPath('homeless', 'second_life'),
  });
  for (const b of ['alley', 'urban', 'corporate', 'luxury', 'island', 'moon']) L['bg_' + b] = RES + 'Backgrounds/bg_' + b + '@3x.png';
  for (const id of ['homeless', 'trapito', 'limpiavidrios', 'cartonero', 'repartidor', 'chofer_app', 'oficinista', 'junior_lawyer',
    'director', 'emprendedor', 'millonario', 'dueno_luna']) L[id] = charPath(id);
  return L;
}

// Estados: [desde, fondo, personaje principal, nivel]
const TOMI = [
  [0, 'alley', 'homeless', 1],
  [17.3, 'alley', 'trapito', 2], [17.8, 'alley', 'limpiavidrios', 3], [18.3, 'alley', 'cartonero', 4],
  [20.8, 'urban', 'repartidor', 6], [22.4, 'corporate', 'oficinista', 9],
  [25.6, 'alley', 'homeless_idle__second_life', 1],
  [26.4, 'urban', 'repartidor', 6], [27.2, 'corporate', 'junior_lawyer', 11], [28.0, 'luxury', 'emprendedor', 16],
  [28.8, 'island', 'millonario', 18], [29.6, 'moon', 'dueno_luna', 24],
];
const SOFI = [
  [0, 'alley', 'homeless', 1],
  [6.3, 'alley', 'trapito', 2], [8.5, 'alley', 'limpiavidrios', 3],
  [11.6, 'urban', 'repartidor', 6], [14.5, 'urban', 'chofer_app', 7],
  [18.6, 'corporate', 'oficinista', 9], [21.6, 'luxury', 'director', 13], [23.2, 'luxury', 'emprendedor', 16],
];
const FLOOR_NAME = EN ? { alley: 'Alley', urban: 'City', corporate: 'Corporate', luxury: 'Luxury', island: 'Island', moon: 'Moon' } : { alley: 'Callejón', urban: 'Ciudad', corporate: 'Corporativo', luxury: 'Lujo', island: 'Isla', moon: 'Luna' };
const NAME = EN ? Object.assign(Object.fromEntries(Object.keys(TIER).map(id => [id, TIER[id].name])), { homeless_idle__second_life: 'The Hobo (Second Life)' }) : { homeless: 'El Fisura', homeless_idle__second_life: 'El Fisura (Segunda Vida)', trapito: 'El Trapito', limpiavidrios: 'Limpiavidrios', cartonero: 'Cartonero', repartidor: 'Repartidor', chofer_app: 'Chofer de App', oficinista: 'Oficinista', junior_lawyer: 'Abogado Jr.', director: 'Director', emprendedor: 'Emprendedor', millonario: 'Millonario', dueno_luna: 'Dueño de la Luna' };
const STAGES = [[3.5, tr('MINUTO 1', 'MINUTE 1')], [10.0, tr('DÍA 2', 'DAY 2')], [17.0, tr('DÍA 7', 'DAY 7')], [24.0, tr('DÍA 30', 'DAY 30')]];
const P1 = tr('TOMI', 'JAKE'), P2 = tr('SOFI', 'EMMA');

function stateAt(list, t) { let i = 0; for (let k = 0; k < list.length; k++) if (t >= list[k][0]) i = k; return i; }

function halfBg(name, cx, zoom = 1.25, dy = 0) {
  const im = IMG['bg_' + name];
  const s = H / im.height * zoom, w = im.width * s, h = im.height * s;
  g.drawImage(im, cx - w / 2, H / 2 - h / 2 + dy + 60, w, h);
}

function drawHalf(side, t) {
  const tomi = side === 0;
  const list = tomi ? TOMI : SOFI;
  const x0 = tomi ? 0 : HW, cx = x0 + HW / 2;
  const i = stateAt(list, t);
  const [ts, bg, id, lvl] = list[i];
  const prev = list[i - 1];
  const floorChange = prev && prev[1] !== bg;
  const d = t - ts;
  g.save();
  g.beginPath(); g.rect(x0, 0, HW, H); g.clip();
  // fondo: si cambia de piso, el piso nuevo baja como el ascensor
  const fast = t > 26;
  const slide = fast ? .3 : .5, pd = fast ? .1 : .3;
  if (floorChange && d < slide) {
    const p = E.cInOut(seg(d, 0, slide));
    const up = !(bg === 'alley');
    g.save(); g.translate(0, (up ? 1 : -1) * p * H); halfBg(prev[1], cx); g.restore();
    g.save(); g.translate(0, (up ? -1 : 1) * (1 - p) * H); halfBg(bg, cx); g.restore();
  } else halfBg(bg, cx);
  shade(.18);
  // Tomi, día 2: el piso se llena de Fisuras
  if (tomi && t >= 10.2 && t < 17.3) {
    const slots = [[150, 1150], [390, 1150], [210, 1050], [330, 1050], [90, 1070], [450, 1070], [270, 1270], [120, 1290], [420, 1290]];
    slots.forEach(([sx, sy], k) => {
      const t0 = 10.25 + k * .11;
      if (t < t0) return;
      const merged = t > 17.0 ? E.cIn(seg(t, 17.0, 17.3)) : 0;
      drawChar('homeless', lerp(x0 + sx, cx, merged), lerp(sy, 1300, merged), 230 * E.elasticOut(seg(t, t0, t0 + .45)) * (1 - merged * .6), { white: merged });
    });
  }
  // personaje principal
  // resultado: la luz va detrás del ganador
  if (t > 31 && tomi) { glow('gold', cx, 1100, 500, .6); rays(cx, 1000, 16, t * .5, 700, 'rgba(255,217,61,1)', .3); }
  const pop = floorChange || i > 0 ? E.elasticOut(seg(d, floorChange ? pd : 0, (floorChange ? pd : 0) + (fast ? .4 : .6))) : 1;
  let sq = 0;
  if (tomi && t > 3.6 && t < 10) sq = Math.abs(Math.sin(t * 14)) * .07; // toca sin parar
  const h = id === 'homeless' || id === 'homeless_idle__second_life' ? 400 : 440;
  drawChar(id, cx, 1330, h * pop, { sy: 1 - sq, sx: 1 + sq * .6, white: i > 0 ? 1 - seg(d, floorChange ? pd : 0, (floorChange ? pd : 0) + .25) : 0 });
  // ¡NUEVO!
  if (i > 0 && d < 1.1 && (lvl <= 3 || floorChange)) {
    const p = E.backOut(seg(d, .1, .4), 2) * (1 - seg(d, .9, 1.1));
    if (p > 0) {
      g.save(); g.translate(cx, 830); g.scale(p, p);
      const w = 300, hh = w * IMG.ribbon.height / IMG.ribbon.width;
      g.drawImage(IMG.ribbon, -w / 2, -hh / 2, w, hh);
      text(floorChange ? (bg === 'alley' ? tr('¡NUEVA VIDA!', 'NEW LIFE!') : tr('¡PISO NUEVO!', 'NEW FLOOR!')) : tr('¡NUEVO!', 'NEW!'), 0, -4, 36, C.cream, { stroke: 7, font: FONT_T, weight: 800 });
      g.restore();
    }
    burst(t, { t0: ts, x: cx, y: 1100, n: 22, seed: 8000 + i * 3 + side, kind: 'confetti', spd: [300, 800], grav: 800, life: [.8, 1.2], size: [14, 22], drag: 1.6 });
  }
  // toques de Tomi en el minuto 1
  if (tomi && t > 3.6 && t < 10) {
    for (let k = 0; k < 3; k++) {
      const ph = ((t * 2.2) + k / 3) % 1;
      drawImg(IMG.fx_tap, cx + (k - 1) * 60, 1060 - k * 30, 60 + 140 * ph, { alpha: 1 - ph });
    }
    const taps = Math.floor((t - 3.6) * 21);
    g.save(); rr(cx - 150, 1420, 300, 70, 35); g.fillStyle = 'rgba(0,0,0,.6)'; g.fill(); g.restore();
    text(`${tr('TOQUES', 'TAPS')}: ${taps}`, cx, 1457, 38, C.cream, { font: FONT_T, weight: 800 });
  }
  // Sofi: contratar y fusionar en el minuto 1
  if (!tomi && t > 4.6 && t < 6.3) {
    const drop = E.expoIn(seg(t, 4.8, 5.1));
    const mg = E.cIn(seg(t, 5.8, 6.3));
    drawChar('homeless', lerp(cx + 150, cx, mg), lerp(900, 1330, drop), 400 * (1 - mg * .5), { flip: true, white: mg });
  }
  // Tomi, piso lleno
  if (tomi && t > 11.3 && t < 17.0) {
    const p = E.backOut(seg(t, 11.3, 11.7), 1.6) * (1 - seg(t, 16.7, 17.0));
    g.save(); g.translate(cx, 700); g.scale(p, p);
    rr(-235, -80, 470, 160, 26); g.fillStyle = '#D7263D'; g.fill(); g.lineWidth = 7; g.strokeStyle = C.ink; g.stroke();
    text(tr('Este piso está lleno —', 'This floor is full —'), 0, -30, 36, '#fff', { font: FONT_T, weight: 800 });
    text(tr('fusioná para hacer lugar', 'merge to make room'), 0, 22, 36, '#fff', { font: FONT_T, weight: 800 });
    g.restore();
  }
  // Tomi descubre bonus y mejoras
  if (tomi && t > 19.0 && t < 23.8) {
    [[IMG.b_mate, tr('Unos Mates', 'A Round of Mate'), 19.0], [IMG.up_income, tr('Más Platita ↑', 'More Cash ↑'), 19.6]].forEach(([im, lab, t0], k) => {
      const p = E.backOut(seg(t, t0, t0 + .35), 2) * (1 - seg(t, 23.4, 23.8));
      if (p <= 0) return;
      g.save(); g.translate(cx, 640 + k * 110); g.scale(p, p);
      rr(-200, -45, 400, 90, 45); g.fillStyle = C.cream; g.fill(); g.lineWidth = 5; g.strokeStyle = C.orange; g.stroke();
      g.drawImage(im, -190, -38, 76, 76);
      text(lab, 30, 3, 36, C.ink, { font: FONT_T, weight: 800 });
      g.restore();
    });
  }
  // Tomi reencarna
  if (tomi && t > 24.1 && t < 25.7) {
    const P = E.backOut(seg(t, 24.1, 24.45), 1.5) * (1 - seg(t, 24.95, 25.15));
    if (P > 0) {
      g.save(); g.translate(cx, 780); g.scale(P, P);
      rr(-240, -150, 480, 300, 30); g.fillStyle = C.parch; g.fill(); g.lineWidth = 9; g.strokeStyle = '#C99A2E'; g.stroke();
      text(tr('¿Reencarnar?', 'Reincarnate?'), 0, -100, 40, C.ink, { font: FONT_T, weight: 800 });
      g.drawImage(IMG.oro, -150, -60, 64, 64); text('+3 ORO', 40, -28, 48, C.ink);
      text(tr('×1,0 → ×1,6', '×1.0 → ×1.6'), 0, 42, 40, C.brown);
      const pr = t > 24.85 && t < 25.0 ? .92 : 1;
      g.save(); g.translate(0, 105); g.scale(pr, pr);
      rr(-170, -32, 340, 64, 32); g.fillStyle = '#3F7FE0'; g.fill(); g.lineWidth = 4; g.strokeStyle = '#214C94'; g.stroke();
      g.drawImage(IMG.reincarnate, -160, -26, 52, 52);
      text(tr('Reencarnar', 'Reincarnate'), 30, 2, 34, '#fff', { font: FONT_T, weight: 800 });
      g.restore();
      g.restore();
    }
    const sw = seg(t, 25.0, 25.6);
    if (sw > 0) {
      g.save(); g.globalCompositeOperation = 'lighter';
      const r = rng(88);
      for (let k = 0; k < 160; k++) {
        const ang = r() * 6.28 + sw * 8, rad = (1 - sw) * 300 * r();
        g.globalAlpha = (1 - Math.abs(sw - .5) * 2) * .9; g.fillStyle = r() < .5 ? '#FFE9A8' : '#fff';
        g.fillRect(cx + Math.cos(ang) * rad, 950 + Math.sin(ang) * rad, 5, 5);
      }
      g.restore();
      g.save(); g.globalAlpha = Math.sin(sw * Math.PI) * .8; g.fillStyle = '#FFF6DC'; g.fillRect(x0, 0, HW, H); g.restore();
    }
  }
  // Tomi después: el aura de la nueva vida
  if (tomi && t > 25.6 && t < 31) glow('gold', cx, 1150, 260, .35 + .15 * Math.sin(t * 6));
  // resultado
  if (t > 31) {
    if (!tomi) { g.save(); g.globalAlpha = .45 * seg(t, 31, 31.4); g.fillStyle = '#000'; g.fillRect(x0, 0, HW, H); g.restore(); }
  }
  g.restore();
  // cabecera: nombre, nivel y piso
  const hp = E.backOut(seg(t, .3 + side * .15, .7 + side * .15), 1.8);
  g.save(); g.translate(cx, 300); g.scale(hp, hp);
  rr(-150, -48, 300, 96, 48); g.fillStyle = tomi ? BLUE : ORANGE; g.fill(); g.lineWidth = 7; g.strokeStyle = C.ink; g.stroke();
  g.restore();
  title(tomi ? P1 : P2, cx, 296, 64 * hp, { tin: 99 });
  if (t > 3.3) {
    const bump = i > 0 ? 1 + (1 - seg(d, 0, .3)) * .15 : 1;
    g.save(); g.translate(cx, 420); g.scale(bump, bump);
    rr(-235, -52, 470, 104, 24); g.fillStyle = 'rgba(20,14,10,.82)'; g.fill(); g.lineWidth = 4; g.strokeStyle = tomi ? BLUE : ORANGE; g.stroke();
    text(`${tr("NIVEL", "LEVEL")} ${lvl}`, 0, -18, 38, C.yellow, { font: FONT_T, weight: 800 });
    text(`${NAME[id]} · ${FLOOR_NAME[bg]}`, 0, 22, 26, C.cream, { maxW: 440 });
    g.restore();
  }
}

function caption(t, str, t0, t1, y = 1500) {
  if (t < t0 || t > t1 + .4) return;
  const a = win(t, t0, t1 + .35, .3, .35);
  const lines = str.split('\n');
  g.save(); g.globalAlpha = a;
  const h = lines.length * 72 + 44;
  rr(50, y - h / 2, 980, h, 36); g.fillStyle = 'rgba(12,10,20,.86)'; g.fill(); g.lineWidth = 5; g.strokeStyle = C.yellow; g.stroke();
  g.restore();
  lines.forEach((l, k) => title(l, 540, y + (k - (lines.length - 1) / 2) * 72, 58, { tin: t - t0 - k * .1, tout: t > t1 ? t - t1 : null, anim: 'rise', dur: .4, stagger: .012, maxW: 920, strokeK: .14 }));
}

const BLUR = [];
function drawScene(t) {
  g.setTransform(SCALE, 0, 0, SCALE, 0, 0);
  g.globalAlpha = 1; g.globalCompositeOperation = 'source-over';
  g.fillStyle = '#000'; g.fillRect(0, 0, W, H);
  if (t >= 33.5) {
    ctaEnd(t, 33.5, EN
      ? { lines: ['HOW WOULD YOU PLAY?', '37 LEVELS · 10 FLOORS'], foot: 'Comment: Team Jake or Team Emma? 👇' }
      : { lines: ['¿Y VOS CÓMO JUGARÍAS?', '37 NIVELES · 10 PISOS'], foot: 'Comentá: ¿Team Tomi o Team Sofi? 👇' });
    flash(1 - seg(t, 33.5, 33.75), '#FFF3D0');
    return;
  }
  const sh = shakeAt(t);
  g.save(); g.translate(sh.x, sh.y);
  // las dos mitades entran desde los costados
  const inP = E.expoOut(seg(t, 0, .7));
  g.save(); g.translate(-(1 - inP) * HW, 0); drawHalf(0, t); g.restore();
  g.save(); g.translate((1 - inP) * HW, 0); drawHalf(1, t); g.restore();
  // divisor y VS
  g.fillStyle = C.ink; g.fillRect(HW - 6, 0, 12, H);
  const vp = E.backOut(seg(t, .5, .9), 2);
  g.save(); g.translate(HW, 960); g.scale(vp, vp); g.rotate(-.08);
  g.beginPath(); g.arc(0, 0, 78, 0, Math.PI * 2); g.fillStyle = C.yellow; g.fill(); g.lineWidth = 9; g.strokeStyle = C.ink; g.stroke();
  g.restore();
  title('VS', HW, 955, 70 * vp, { tin: 99, rot: -.08 });
  // etapa del tiempo
  for (let k = 0; k < STAGES.length; k++) {
    const [s0, lab] = STAGES[k];
    const s1 = STAGES[k + 1] ? STAGES[k + 1][0] : 31.0;
    if (t < s0 || t > s1) continue;
    const p = E.backOut(seg(t, s0, s0 + .4), 2) * (1 - seg(t, s1 - .2, s1));
    g.save(); g.translate(HW, 560); g.scale(p, p);
    rr(-150, -42, 300, 84, 42); g.fillStyle = C.cream; g.fill(); g.lineWidth = 6; g.strokeStyle = C.ink; g.stroke();
    g.restore();
    title(lab, HW, 560, 52 * p, { tin: 99 });
  }
  g.restore();
  // hook
  if (t < 3.6) {
    const a = 1 - seg(t, 3.2, 3.6);
    g.save(); g.globalAlpha = a * .8; g.fillStyle = 'rgba(8,6,14,.7)'; g.fillRect(0, 1180, W, 520); g.restore();
    title(tr('DOS AMIGOS. EL MISMO JUEGO.', 'TWO FRIENDS. SAME GAME.'), 540, 1270, 70, { tin: t - .3, alpha: a, stagger: .012, dur: .4, anim: 'rise', maxW: 1000 });
    title(tr('¿QUIÉN LLEGA MÁS LEJOS?', 'WHO GETS FURTHER?'), 540, 1390, 86, { tin: t - .9, alpha: a, stagger: .018, dur: .4, anim: 'rise', gold: true, maxW: 1000 });
    const vp2 = E.backOut(seg(t, 1.8, 2.2), 2) * a;
    if (vp2 > 0) for (const [x, lab, col] of [[290, 'TEAM ' + P1, BLUE], [790, 'TEAM ' + P2, ORANGE]]) {
      g.save(); g.translate(x, 1520); g.scale(vp2, vp2);
      rr(-190, -44, 380, 88, 44); g.fillStyle = col; g.fill(); g.lineWidth = 6; g.strokeStyle = C.ink; g.stroke();
      g.restore();
      title(lab, x, 1518, 50 * vp2, { tin: 99 });
    }
    title(tr('Apostá en los comentarios 👇', 'Place your bets in the comments 👇'), 540, 1630, 50, { tin: t - 2.3, alpha: a, stagger: .01, dur: .3, strokeK: .15, maxW: 900 });
  }
  // six seven: Sofi pasa del nivel 6 al 7
  if (t > 14.5 && t < 16.3) {
    const p = E.backOut(seg(t, 14.55, 14.85), 2.2) * (1 - seg(t, 16.0, 16.3));
    g.save(); g.translate(810, 690); g.rotate(-.08); g.scale(p, p);
    rr(-220, -62, 440, 124, 34); g.fillStyle = C.pink; g.fill(); g.lineWidth = 8; g.strokeStyle = C.ink; g.stroke();
    g.restore();
    title('SIX SEVEN 🤷', 810, 685, 66 * p, { tin: 99, rot: -.08, maxW: 400 });
  }
  // Sofi se burla cuando Tomi vuelve a fisura
  if (t > 25.7 && t < 27.4) {
    const sp = E.backOut(seg(t, 25.7, 26.0), 2) * (1 - E.cIn(seg(t, 27.1, 27.4)));
    speech(810, 700, 500, tr('¿Volviste a fisura? ¿Quién sos, el Pepe? 😂', 'Back to broke?? Bro hit reset on his whole life 😂'), 810, 900, { s: sp, size: 38 });
  }
  caption(t, tr('Sofi fusiona. Tomi… toca.', 'Emma merges. Jake… taps.'), 4.4, 9.6);
  caption(t, tr('Piso lleno = hay que fusionar\npara hacer lugar.', 'Floor full = you have to merge\nto make room.'), 11.6, 16.6);
  caption(t, tr('Tomi descubrió los bonus\ny las mejoras.', 'Jake discovered boosts\nand upgrades.'), 19.2, 23.6);
  caption(t, tr('Reencarnar: volvés a cero,\npero con ORO que multiplica todo.', 'Reincarnate: back to zero,\nbut with ORO that multiplies everything.'), 24.3, 27.6);
  caption(t, tr('¡LA ALCANZÓ!', 'HE CAUGHT UP!'), 28.0, 28.7);
  caption(t, tr('¡LA PASÓ!', 'AND PASSED HER!'), 28.8, 30.8);
  if (t > 31) {
    const p = E.backOut(seg(t, 31.1, 31.5), 1.8);
    g.save(); g.translate(540, 1480); g.scale(p, p);
    rr(-360, -90, 720, 180, 50); g.fillStyle = C.yellow; g.fill(); g.lineWidth = 10; g.strokeStyle = C.ink; g.stroke();
    g.restore();
    title(tr('🏆 GANÓ TOMI', '🏆 JAKE WINS'), 540, 1478, 96 * p, { tin: 99 });
    burst(t, { t0: 31.1, x: 270, y: 800, n: 80, seed: 8100, kind: 'confetti', spd: [500, 1500], grav: 1200, life: [1.4, 2], size: [22, 34], drag: 1.5 });
  }
}
function sceneSetup() { impact(25.6, 8); impact(29.6, 8); impact(31.1, 12); }
window.DURATION = DURATION;
boot();
