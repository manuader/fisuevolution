'use strict';
// Reel v1 — «De fisura a Dios» (30 s). Motor en lib.js.
const DURATION = 30;
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
  };
  for (const b of ['alley', 'urban', 'corporate', 'luxury', 'moon', 'mars', 'solar', 'galaxy', 'god_realm'])
    L['bg_' + b] = RES + 'Backgrounds/bg_' + b + '@3x.png';
  for (const [id] of TIERS) L[id] = charPath(id);
  for (const id of FACE_IDS) L['face_' + id] = RES + 'ui.atlas/' + id + '_face@3x.png';
  return L;
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
const CAREER_NAMES = EN ? ['DEVELOPER', 'ARCHITECT', 'DOCTOR', 'LAWYER'] : ['PROGRAMADOR', 'ARQUITECTO', 'MÉDICO', 'ABOGADO'];

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
  title(tr('DE FISURA…', 'FROM BROKE…'), CX, 360, 170, { tin: t - .12, tout: t - 2.72, stagger: .045, maxW: 960 });
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
  title(tr('TAPEÁ', 'TAP.'), CX, 420, 150, { tin: t - 3.0, tout: t - 3.85, stagger: .03 });
  title(tr('FUSIONÁ.', 'MERGE.'), CX, 420, 185, { tin: t - 4.72, tout: t - 6.1, stagger: .03, anim: 'slam', dur: .3 });
  title(tr('EVOLUCIONÁ.', 'EVOLVE.'), CX, 420, 185, { tin: t - 6.22, tout: t - 7.9, stagger: .025, anim: 'slam', dur: .3, gold: true, maxW: 1000 });
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
  title(tr('ELEGÍ TU', 'PICK YOUR'), CX, 290, 120, { tin: t - 10.5, tout: t - 11.6, stagger: .03 });
  title(tr('CARRERA', 'CAREER'), CX, 410, 150, { tin: t - 10.62, tout: t - 11.62, stagger: .03, gold: true });
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
  title(tr('…A DIOS.', '…TO GOD.'), CX, 330, 200, { tin: t - 19.0, stagger: .06, anim: 'slam', dur: .35, gold: true, maxW: 980 });
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
  title(tr('FISUEVOLUTION', 'HOBOEVOLUTION'), CX, 1250 - out * 900, 132, { tin: t - 23.2, stagger: .028, maxW: 1000 });
  g.save(); const pa = E.expoOut(seg(t, 23.6, 23.9)) * (1 - out); g.globalAlpha = pa;
  pill(CX, 1385 - out * 900, 560, 84, { fill: C.yellow, stroke: C.ink, alpha: pa });
  g.font = `900 44px ${FONT_N}`; g.textAlign = 'center'; g.textBaseline = 'middle'; g.fillStyle = C.ink;
  g.fillText(tr('DE FISURA A DIOS', 'FROM BROKE TO GOD'), CX, 1389 - out * 900);
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
      g.fillText(tr('¡NIVEL 2!', 'LEVEL 2!'), 0, 2);
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
  title(tr('¿HASTA DÓNDE', 'HOW FAR'), CX, 225, 110, { tin: t - 24.35, tout: t - 26.62, stagger: .03 });
  title(tr('VAS A LLEGAR?', 'WILL YOU GO?'), CX, 345, 118, { tin: t - 24.5, tout: t - 26.64, stagger: .03, gold: true });
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
  title(tr('DESCARGALO', 'DOWNLOAD IT'), CX, 980, 140, { tin: t - 27.0, stagger: .03 });
  title(tr('GRATIS', 'FREE'), CX, 1120, 190, { tin: t - 27.2, stagger: .045, anim: 'slam', dur: .3, gold: true });
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


function sceneSetup() {
  makeClouds();
  setupImpacts();
}
window.DURATION = DURATION;
boot();
