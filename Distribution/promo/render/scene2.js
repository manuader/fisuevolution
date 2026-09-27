'use strict';
// Reel v2 — «¿Qué hay en el último piso?» (45 s). Motor en lib.js.
// Misterio + simulación de partida: la UI se reconstruye desde las capturas
// reales del juego (HUD, barra inferior, paneles) con los textos de
// Localizable.xcstrings. Personajes: sólo los primeros; el resto, siluetas.

const DURATION = 45;
const BPM2 = 100, B2 = 60 / BPM2; // 0,6 s

const ASSETS2 = '/Distribution/promo/render/assets/';
function assetList() {
  const U = n => RES + 'ui.atlas/' + n + '@3x.png';
  const L = {
    coin: U('ui_coin'), coin_plus: U('ui_coin_plus'), elevator: U('ui_elevator'),
    fx_merge: U('fx_merge'), fx_tap: U('fx_tap'), fx_evo: U('fx_evolution_flash'), star: U('fx_unlock'),
    dollar: U('ui_dollar'), oro: U('ui_oro'), bow: U('ui_gift_bow'), ribbon: U('ui_header_ribbon'),
    chest: U('ui_chest_closed'), calendar: U('ui_daily_calendar'), reincarnate: U('ui_btn_reincarnate'),
    tab_active: U('ui_tab_active'), tab_upgrades: U('ui_tab_upgrades'), tab_skins: U('ui_tab_skins'),
    tab_gifts: U('ui_tab_gifts'), tab_shop: U('ui_tab_shop'), tab_menu: U('ui_tab_menu'),
    b_mate: U('ui_boost_mate'), b_cafe: U('ui_boost_cafe'), b_asado: U('ui_boost_asado'),
    b_milanesa: U('ui_boost_milanesa'), b_turbo: U('ui_boost_turbo'),
    up_income: U('ui_up_income'), up_tap: U('ui_up_tap'), up_crit: U('ui_up_crit'), up_offline: U('ui_up_offline'),
    up_spawn: U('ui_up_spawn'), up_golden: U('ui_up_golden'),
    panel_prestige: U('panel_prestige'), panel_upgrades: U('panel_upgrades'),
    face_homeless: U('homeless_face'), face_trapito: U('trapito_face'),
    face_junior_programmer: U('junior_programmer_face'), face_junior_architect: U('junior_architect_face'),
    face_junior_doctor: U('junior_doctor_face'), face_junior_lawyer: U('junior_lawyer_face'),
    card: RES + 'ChestAnim/chest_card_still.png',
    app_icon: ASSETS2 + 'app_icon.png', ader: ASSETS2 + 'adergames_logo.png',
    sp_cryptobro: RES + 'specials.atlas/sp_cryptobro@3x.png',
    homeless_idle__oro: RES + 'earth.atlas/homeless_idle__oro@3x.png',
    homeless_idle__second_life: RES + 'earth.atlas/homeless_idle__second_life@3x.png',
  };
  for (const f of [0, ...Array.from({ length: 27 }, (_, i) => 23 + i)]) L['chest_f' + f] = RES + 'ChestAnim/chest_f' + String(f).padStart(3, '0') + '.png';
  for (const b of ['alley', 'urban', 'corporate', 'luxury', 'island', 'moon', 'mars', 'solar', 'galaxy', 'god_realm'])
    L['bg_' + b] = RES + 'Backgrounds/bg_' + b + '@3x.png';
  // personajes: los que se ven + los que sólo aparecen como silueta
  for (const id of ['homeless', 'trapito', 'limpiavidrios', 'cartonero', 'mantero', 'repartidor', 'ceo', 'rey_ladrillo',
    'multimillonario', 'dueno_luna', 'dueno_marte', 'magnate_solar', 'senor_galaxia', 'god']) L[id] = charPath(id);
  return L;
}

// ───────────────────────── la torre (fuera del teléfono) ─────────────────────────
const FLOORS = [ // de abajo hacia arriba (economy.json → floors)
  { bg: 'alley', name: 'CALLEJÓN', sil: 'homeless' }, { bg: 'urban', name: 'CIUDAD', sil: 'repartidor' },
  { bg: 'corporate', sil: 'ceo' }, { bg: 'luxury', sil: 'rey_ladrillo' }, { bg: 'island', sil: 'multimillonario' },
  { bg: 'moon', sil: 'dueno_luna' }, { bg: 'mars', sil: 'dueno_marte' }, { bg: 'solar', sil: 'magnate_solar' },
  { bg: 'galaxy', sil: 'senor_galaxia' }, { bg: 'god_realm', sil: 'god' },
];
const FW = 820, FH = 330, SLAB = 40, TX = (W - FW) / 2;
const floorTop = i => (9 - i) * (FH + SLAB);
const floorCY = i => floorTop(i) + FH / 2;
function drawFloorRoom(i, t, lit) {
  const f = FLOORS[i], y = floorTop(i);
  const im = IMG['bg_' + f.bg];
  g.save();
  rr(TX, y, FW, FH, 18); g.clip();
  const s = FW / im.width * 1.02;
  // banda del fondo con el piso del escenario alineado abajo
  g.drawImage(im, TX - FW * .01, y + FH - im.height * s * .8, im.width * s, im.height * s);
  if (i === 9) {
    // el último piso: sólo luz
    g.fillStyle = 'rgba(12,8,24,.86)'; g.fillRect(TX, y, FW, FH);
    glow('gold', W / 2, y + FH * .55, 360 + 20 * Math.sin(t * 2), .9);
    rays(W / 2, y + FH * .55, 16, t * .25, 520, 'rgba(255,220,120,1)', .35);
    sil('god', W / 2, y + FH - 14, FH * .86, '#140c02', 1);
    title('?', W / 2 + 4, y + FH * .45, 150, { gold: true, strokeK: .14 });
  } else if (!lit(i)) {
    g.fillStyle = 'rgba(10,8,20,.8)'; g.fillRect(TX, y, FW, FH);
    sil(f.sil, W / 2, y + FH - 16, FH * .8, '#07060d', .95);
    text('?', W / 2, y + FH * .42, 120, 'rgba(255,248,231,.9)', { stroke: 14 });
    lockIcon(TX + 60, y + 58, .8);
  } else {
    // pisos abiertos: el personaje que conocemos
    if (i === 0) drawChar('homeless', W / 2, y + FH - 22, FH * .72);
    if (i === 1) drawChar('mantero', W / 2, y + FH - 22, FH * .72);
  }
  g.restore();
  // marco de la torre
  g.save();
  rr(TX, y, FW, FH, 18); g.lineWidth = 10; g.strokeStyle = C.ink; g.stroke();
  g.restore();
  // chapa del piso
  const label = i === 9 ? '???' : (lit(i) ? `PISO ${i + 1} · ${f.name}` : `PISO ${i + 1} · ???`);
  g.save();
  g.font = `900 30px ${FONT_N}`;
  const w = g.measureText(label).width + 44;
  rr(TX + FW - w - 16, y + 16, w, 50, 25); g.fillStyle = lit(i) ? C.cream : 'rgba(40,34,50,.95)'; g.fill();
  g.lineWidth = 4; g.strokeStyle = C.ink; g.stroke();
  text(label, TX + FW - w / 2 - 16, y + 43, 30, lit(i) ? C.ink : 'rgba(255,248,231,.75)');
  g.restore();
}
function drawTower(t, camY, z, lit) {
  // cielo
  const gr = g.createLinearGradient(0, 0, 0, H);
  gr.addColorStop(0, '#0B0718'); gr.addColorStop(1, '#1D1226');
  g.fillStyle = gr; g.fillRect(0, 0, W, H);
  starfield2(t, 3, 220);
  g.save();
  g.translate(W / 2, H / 2); g.scale(z, z); g.translate(-W / 2, -camY);
  // columna de la torre
  g.fillStyle = '#2A2233';
  g.fillRect(TX - 30, floorTop(9) - 60, FW + 60, floorTop(0) + FH + 120 - floorTop(9));
  g.lineWidth = 10; g.strokeStyle = C.ink;
  g.strokeRect(TX - 30, floorTop(9) - 60, FW + 60, floorTop(0) + FH + 120 - floorTop(9));
  // losas entre pisos
  for (let i = 0; i < 10; i++) {
    const y = floorTop(i) + FH;
    g.fillStyle = '#5B4A3A'; g.fillRect(TX - 30, y + 4, FW + 60, SLAB - 8);
    g.fillStyle = 'rgba(0,0,0,.35)'; g.fillRect(TX - 30, y + SLAB - 12, FW + 60, 6);
  }
  // techo con la luz del último piso escapando
  glow('gold', W / 2, floorTop(9) - 60, 520 + 30 * Math.sin(t * 1.7), .55);
  for (let i = 0; i < 10; i++) {
    const cy = floorCY(i);
    const sy = (cy - camY) * z + H / 2;
    if (sy < -FH * z || sy > H + FH * z) continue;
    drawFloorRoom(i, t, lit);
  }
  g.restore();
}
function starfield2(t, seed, n) {
  const r = rng(seed);
  g.save(); g.fillStyle = '#fff';
  for (let i = 0; i < n; i++) {
    const x = r() * W, y = r() * H, s = lerp(1.5, 4.5, r()), ph = r() * 6.28;
    g.globalAlpha = .25 + .55 * Math.abs(Math.sin(ph + t * .9));
    g.fillRect(x, y, s, s);
  }
  g.restore();
}

// ───────────────────────── el teléfono y la partida ─────────────────────────
// La pantalla se dibuja en puntos de iPhone (430×932, como las capturas reales).
const SW = 430, SH = 932;
const K0 = 1.86; // escala base puntos → video
const PHONE = [
  [4.9, { x: 540, y: -140, k: 4.2, r: 0 }],
  [6.5, { x: 540, y: 1010, k: K0, r: 0 }, E.expoOut],
  [11.3, { x: 540, y: 1010, k: K0, r: 0 }],
  [11.9, { x: 540, y: 1060, k: 2.0, r: 0 }],
  [12.9, { x: 540, y: 1060, k: 2.0, r: 0 }],
  [13.6, { x: 540, y: 1010, k: K0, r: 0 }],
  [16.8, { x: 540, y: 1010, k: K0, r: 0 }],
  [17.5, { x: 540, y: 1040, k: 2.12, r: 0 }],
  [19.6, { x: 540, y: 1040, k: 2.12, r: 0 }],
  [20.3, { x: 540, y: 1010, k: K0, r: 0 }],
  [23.1, { x: 540, y: 1010, k: K0, r: 0 }],
  [23.7, { x: 540, y: 1000, k: 2.1, r: 0 }],
  [24.95, { x: 540, y: 1000, k: 2.1, r: 0 }],
  [25.5, { x: 540, y: 1010, k: K0, r: 0 }],
  [29.2, { x: 540, y: 1010, k: K0, r: 0 }],
  [29.9, { x: 540, y: 1060, k: 2.08, r: 0 }],
  [31.4, { x: 540, y: 1060, k: 2.08, r: 0 }],
  [32.0, { x: 540, y: 1010, k: K0, r: 0 }],
  [33.4, { x: 540, y: 1010, k: K0, r: 0 }],
  [34.1, { x: 540, y: 1030, k: 2.12, r: 0 }],
  [35.0, { x: 540, y: 1030, k: 2.12, r: 0 }],
  [35.6, { x: 540, y: 1010, k: K0, r: 0 }],
  [38.0, { x: 540, y: 1010, k: K0, r: 0 }],
  [38.9, { x: 540, y: 960, k: .9, r: 0 }, E.cIn],
];

// Pisos del tablero (puntos): pies de cada lugar.
const SLOTS = [[215, 742], [330, 722], [100, 726], [272, 656], [158, 648], [372, 664], [54, 662], [318, 800]];
const CHARH = 138;

// Acciones del dedo: tap o drag, en puntos de pantalla.
const QH = [95, 777]; // pill de contratación rápida
const ACTIONS = [
  ...[6.4, 6.85, 7.25, 7.55, 7.8, 8.0, 8.2].map(t => ({ t, x: 222, y: 680 })),
  { t: 8.55, x: 222, y: 680, crit: true },
  { t: 9.55, x: QH[0], y: QH[1] },
  { t: 10.35, x: SLOTS[1][0], y: SLOTS[1][1] - 60, t2: 11.15, x2: SLOTS[0][0], y2: SLOTS[0][1] - 60 },
  { t: 14.45, x: SLOTS[7][0], y: SLOTS[7][1] - 60, t2: 15.0, x2: SLOTS[5][0], y2: SLOTS[5][1] - 60 },
  { t: 16.2, x: 392, y: 88 },
  { t: 18.9, x: 215, y: 426 },
  { t: 19.95, x: 392, y: 88 },
  { t: 20.75, x: 249, y: 856 },
  { t: 21.75, x: 90, y: 505 },
  { t: 22.95, x: 330, y: 716 },
  { t: 23.25, x: 215, y: 520 },
  { t: 24.75, x: 215, y: 728 },
  { t: 28.55, x: 215, y: 690 },
  { t: 29.35, x: 110, y: 856 },
  ...[30.1, 30.5, 30.9].map(t => ({ t, x: 356, y: 318 })),
  { t: 32.6, x: 215, y: 610 },
  { t: 33.5, x: 330, y: 172 },
  { t: 34.95, x: 290, y: 690 },
  ...[36.55, 36.8, 37.05, 37.3, 37.55].map(t => ({ t, x: 222, y: 680 })),
];
function fingerAt(t) {
  let best = null;
  for (let i = 0; i < ACTIONS.length; i++) {
    const a = ACTIONS[i], end = (a.t2 || a.t) + .3;
    if (t >= a.t - .7 && t <= end) best = i;
  }
  if (best == null) return null;
  const a = ACTIONS[best], prev = ACTIONS[best - 1];
  const chained = prev && a.t - (prev.t2 || prev.t) < .75;
  let x, y, alpha = 1, press = 0;
  if (t < a.t) {
    const p = E.cInOut(seg(t, a.t - (chained ? a.t - (prev.t2 || prev.t) : .6), a.t));
    const fx = chained ? (prev.x2 || prev.x) : a.x + 60, fy = chained ? (prev.y2 || prev.y) : a.y + 150;
    x = lerp(fx, a.x, p); y = lerp(fy, a.y, p);
    if (!chained) alpha = seg(t, a.t - .6, a.t - .35);
  } else if (a.t2 && t <= a.t2) {
    const p = E.cInOut(seg(t, a.t, a.t2));
    x = lerp(a.x, a.x2, p); y = lerp(a.y, a.y2, p) - Math.sin(p * Math.PI) * 60; press = .6;
  } else {
    x = a.x2 || a.x; y = a.y2 || a.y;
    const next = ACTIONS[best + 1];
    const stays = next && next.t - (a.t2 || a.t) < .75;
    alpha = stays ? 1 : 1 - seg(t, (a.t2 || a.t) + .12, (a.t2 || a.t) + .3);
    if (!a.t2) press = 1 - seg(t, a.t, a.t + .16);
  }
  return { x, y, press, alpha, a };
}
function drawFinger(t) {
  const f = fingerAt(t); if (!f) return;
  g.save(); g.globalAlpha = f.alpha;
  const r = 20 * (1 - f.press * .18);
  g.beginPath(); g.arc(f.x, f.y, r, 0, Math.PI * 2);
  g.fillStyle = 'rgba(255,255,255,.6)'; g.fill();
  g.lineWidth = 3.5; g.strokeStyle = C.ink; g.stroke();
  if (f.press > 0 && !f.a.t2) {
    g.beginPath(); g.arc(f.x, f.y, r + 16 * (1 - f.press), 0, Math.PI * 2);
    g.lineWidth = 3; g.strokeStyle = `rgba(255,255,255,${.9 * f.press})`; g.stroke();
  }
  g.restore();
}

// Valores del HUD (plata, /s, multiplicador global).
const COIN_KEYS = [
  [6.3, 0], [8.9, 25], [9.55, 25], [9.85, 0, E.cOut], [13.0, 0], [14.3, 1240, E.cOut], [16.0, 2380], [20.5, 3100],
  [25.3, 3100], [26.9, 18600, E.cOut], [29.3, 19800], [32.55, 21400], [32.95, 69600, E.cOut], [35.05, 70200], [35.3, 0, E.cOut],
  [36.4, 0], [38.2, 2400, E.cIn],
];
const PS_KEYS = [[13.0, 0], [14.3, 48, E.cOut], [15.1, 96], [25.3, 96], [25.6, 288], [26.9, 288], [27.1, 96], [35.05, 140], [35.3, 0], [36.4, 0], [38, 22]];
function multAt(t) { return t < 36.2 ? '×1,0' : '×1,6'; }

function drawBgPts(img, zoom, ox = 0, oy = 0) {
  const s = SH / img.height * zoom;
  const w = img.width * s, h = img.height * s;
  g.drawImage(img, SW / 2 - w / 2 + ox, SH / 2 - h / 2 + oy, w, h);
}
// El mundo (fondo + personajes) según el piso visible.
function worldFloorOffset(t) {
  // elevador: callejón → ciudad (16.3) y vuelta (19.95)
  const up = E.cInOut(seg(t, 16.3, 16.95)), down = E.cInOut(seg(t, 20.0, 20.6));
  return up - down; // 0 = callejón, 1 = ciudad
}
function boardChars(t) {
  const L = [];
  const add = (id, s, t0, t1 = 99, o = {}) => { if (t >= t0 && t < t1) L.push({ id, x: SLOTS[s][0], y: SLOTS[s][1], t0, ...o }); };
  if (t < 35.1) {
    add('homeless', 0, 0, 11.2);
    add('homeless', 1, 9.85, 10.35, { drop: true });
    add('trapito', 0, 12.9);
    add('homeless', 1, 13.05); add('trapito', 2, 13.2); add('limpiavidrios', 3, 13.35); add('homeless', 4, 13.5);
    add('cartonero', 5, 13.65, 15.0); add('limpiavidrios', 6, 13.8); add('cartonero', 7, 13.95, 14.45);
  } else {
    // nueva vida
    add('homeless_idle__second_life', 0, 36.15);
    add('homeless_idle__second_life', 1, 36.95); add('homeless_idle__second_life', 2, 37.35); add('homeless_idle__second_life', 3, 37.75);
  }
  return L;
}
function drawBoard(t) {
  let tapSq = 0;
  for (const a of ACTIONS) if (!a.t2 && a.y > 600 && a.y < 700 && a.x > 200 && a.x < 240) {
    const d = t - a.t; if (d >= 0 && d < .2) tapSq = Math.max(tapSq, Math.sin(d / .2 * Math.PI) * (a.crit ? .16 : .09));
  }
  for (const c of boardChars(t)) {
    const age = t - c.t0;
    let sx = 1, sy = 1, y = c.y, a = 1;
    const popIn = c.t0 > 12.95 && c.t0 !== 36.15;
    if (c.drop) { const p = E.expoIn(seg(age, 0, .28)); y = lerp(c.y - 300, c.y, p); a = cl(age * 6); if (age > .28) { const q = seg(age, .28, .5); sy = 1 - Math.sin(q * Math.PI) * .14; sx = 1 / sy; } }
    else if (popIn && age < .5) { const p = E.elasticOut(seg(age, 0, .5)); sx = sy = p; }
    let id = c.id, x = c.x;
    if (c.id === 'homeless' && c.x === SLOTS[0][0] && c.y === SLOTS[0][1] && t < 9.5) { sy *= 1 - tapSq; sx *= 1 + tapSq * .6; }
    const bob = 1 + Math.sin(t * 3 + c.x) * .012;
    drawChar(id, x, y, CHARH * (id === 'trapito' && c.x === SLOTS[0][0] ? 1.04 : 1), { sx, sy: sy * bob, alpha: a });
    // ingreso pasivo: una moneda sube cada tanto
    if (t > 13.1 && t < 35) {
      const per = 1.35, ph = ((t + c.x * .013) % per) / per;
      if (ph < .55) drawImg(IMG.coin, x + 16, y - CHARH - 10 - ph * 50, 20, { alpha: 1 - ph / .55 });
    }
  }
  // arrastre 1: el Fisura nuevo viaja al original
  const drag = (a, id) => {
    if (t < a.t || t > a.t2) return;
    const p = E.cInOut(seg(t, a.t, a.t2));
    const x = lerp(a.x, a.x2, p), y = lerp(a.y, a.y2, p) - Math.sin(p * Math.PI) * 60 + 60;
    drawChar(id, x, y, CHARH * 1.08, { rot: Math.sin(t * 18) * .04, shadow: false });
  };
  drag(ACTIONS.find(a => a.t === 10.35), 'homeless');
  drag(ACTIONS.find(a => a.t === 14.45), 'cartonero');
  // fusión 1: remolino y luz
  const m = t - 11.15;
  if (m >= 0 && m < .4) {
    const p = E.cIn(seg(m, 0, .35));
    for (const s of [-1, 1]) {
      const ang = p * Math.PI * 1.5 * s;
      drawChar('homeless', SLOTS[0][0] + Math.cos(ang) * 40 * (1 - p) * s, SLOTS[0][1] - Math.sin(ang) * 20, CHARH * (1 - p * .7), { white: p, shadow: false, alpha: 1 - p * .5 });
    }
    glow('white', SLOTS[0][0], SLOTS[0][1] - 70, 60 + 200 * p, p);
  }
  // fusión 2 (cartoneros → El Mantero, que sube al piso de arriba)
  const m2 = t - 15.0;
  if (m2 >= 0 && m2 < 1.0) {
    const [sx5, sy5] = SLOTS[5];
    drawImg(IMG.fx_merge, sx5, sy5 - 70, 60 + 260 * E.expoOut(seg(m2, 0, .5)), { alpha: 1 - seg(m2, .2, .7), rot: m2 * 1.5 });
    const fly = E.cIn(seg(m2, .45, .95));
    drawChar('mantero', sx5, sy5 - fly * 900, CHARH * E.elasticOut(seg(m2, 0, .4)), { white: 1 - seg(m2, 0, .2), shadow: fly < .05 });
    if (m2 < .6) ribbonNew(sx5, sy5 - CHARH - 26, .55, seg(m2, .05, .3), 1 - seg(m2, .45, .6));
    burst(t, { t0: 15.0, x: sx5, y: sy5 - 70, n: 26, seed: 2001, kind: 'spark', spd: [300, 800], grav: 200, life: [.3, .6], size: [3, 5], drag: 3 });
  }
  burst(t, { t0: 11.5, x: SLOTS[0][0], y: SLOTS[0][1] - 70, n: 30, seed: 2000, kind: 'spark', spd: [300, 900], grav: 200, life: [.3, .6], size: [3, 6], drag: 3 });
}
function ribbonNew(x, y, s, pin, a = 1) {
  if (pin <= 0 || a <= 0) return;
  g.save(); g.translate(x, y); g.scale(s * E.backOut(pin, 2), s * E.backOut(pin, 2)); g.globalAlpha = a;
  const w = 300, h = w * IMG.ribbon.height / IMG.ribbon.width;
  g.drawImage(IMG.ribbon, -w / 2, -h / 2, w, h);
  text('¡NUEVO!', 0, -4, 38, C.cream, { stroke: 7 });
  g.restore();
}
function drawTapFx(t) {
  for (const a of ACTIONS) {
    if (a.t2 || !(a.y > 600 && a.y < 700)) continue;
    const d = t - a.t;
    if (d >= 0 && d < .45) drawImg(IMG.fx_tap, a.x, a.y, 50 + 110 * E.expoOut(seg(d, 0, .4)), { alpha: 1 - seg(d, .12, .45) });
    // la moneda vuela al contador
    if (d >= 0 && d < .6 && !(t > 35 && t < 36.2)) {
      const p = E.cInOut(seg(d, .05, .55));
      const x0 = a.x + 10, y0 = a.y - 40, x1 = 200, y1 = 82;
      const cx = lerp(x0, x1, .5) + 60, cy = Math.min(y0, y1) - 20;
      const bx = (1 - p) * (1 - p) * x0 + 2 * (1 - p) * p * cx + p * p * x1;
      const by = (1 - p) * (1 - p) * y0 + 2 * (1 - p) * p * cy + p * p * y1;
      drawImg(IMG.coin, bx, by, lerp(30, 22, p) * (a.crit ? 1.5 : 1), { alpha: 1 - seg(p, .92, 1) });
    }
    if (a.crit) {
      if (d >= 0 && d < .9) {
        glow('gold', a.x, a.y - 30, 80 + 120 * E.expoOut(seg(d, 0, .3)), 1 - seg(d, .2, .9));
        g.save(); const s = E.backOut(seg(d, 0, .3), 2.4);
        g.translate(a.x, a.y - 120 - d * 40); g.scale(s, s); g.globalAlpha = 1 - seg(d, .6, .9);
        text('¡PEGARLA! ×5', 0, 0, 30, C.yellow, { stroke: 7 });
        g.restore();
      }
      burst(t, { t0: a.t, x: a.x, y: a.y - 40, n: 16, seed: 2100, kind: 'coin', spd: [200, 500], ang: [-Math.PI * .9, -Math.PI * .1], grav: 900, life: [.6, .9], size: [16, 26] });
    }
  }
}

function drawHud(t, a) {
  if (a <= 0) return;
  g.save(); g.globalAlpha = a;
  const slide = (1 - a) * -40;
  g.translate(0, slide);
  // panel superior
  rr(-4, -30, SW + 8, 158, 26); g.fillStyle = 'rgba(255,248,231,.84)'; g.fill();
  g.lineWidth = 1.5; g.strokeStyle = 'rgba(122,78,38,.35)'; g.stroke();
  g.drawImage(IMG.coin_plus, 14, 60, 54, 54 * IMG.coin_plus.height / IMG.coin_plus.width);
  const v = track(t, COIN_KEYS), ps = track(t, PS_KEYS);
  const str = coinFmt(Math.max(0, v));
  g.font = `900 30px ${FONT_N}`;
  const tw = g.measureText(str).width, gw = 30 + 8 + tw;
  const gx = SW / 2 - gw / 2;
  let bump = 0;
  for (const ac of ACTIONS) { const d = t - ac.t - .5; if (!ac.t2 && ac.y > 600 && ac.y < 700 && d >= 0 && d < .15) bump = 1 - d / .15; }
  g.drawImage(IMG.coin, gx - bump * 2, 68 - bump * 2, 30 + bump * 4, 30 + bump * 4);
  g.textAlign = 'left'; g.textBaseline = 'middle'; g.fillStyle = C.ink;
  g.fillText(str, gx + 38, 84);
  text(`${coinFmt(ps)}/s`, SW / 2, 110, 13, '#8b8378', { weight: 900 });
  // ascensor (late cuando hay piso nuevo)
  const ep = t > 15.6 && t < 16.3 ? 1 + Math.sin((t - 15.6) * 14) * .06 : 1;
  const eh = 60 * ep, ew = eh * IMG.elevator.width / IMG.elevator.height;
  g.drawImage(IMG.elevator, 392 - ew / 2, 88 - eh / 2, ew, eh);
  // multiplicador global
  const mp = t > 36.2 && t < 36.8 ? 1 + Math.sin((t - 36.2) / .6 * Math.PI) * .25 : 1;
  g.save(); g.translate(SW / 2, 148); g.scale(mp, mp);
  rr(-34, -11, 68, 22, 11); g.fillStyle = '#fff'; g.fill(); g.lineWidth = 1; g.strokeStyle = 'rgba(0,0,0,.12)'; g.stroke();
  star4(-19, 0, 7, C.pink);
  text(multAt(t), 6, 1, 12.5, C.ink);
  g.restore();
  // bonus activo (chip bajo el multiplicador)
  const chips = [];
  if (t > 21.85 && t < 29.2) chips.push({ icon: IMG.b_mate, txt: '−30% contratar', t0: 21.85 });
  if (t > 25.35 && t < 27.0) chips.push({ icon: IMG.coin, txt: '×3 ingresos', t0: 25.35 });
  chips.forEach((c, i) => {
    const pin = E.backOut(seg(t, c.t0, c.t0 + .35));
    g.save(); g.translate(SW / 2, 178 + i * 28); g.scale(pin, pin);
    rr(-70, -11, 140, 22, 11); g.fillStyle = 'rgba(255,248,231,.95)'; g.fill(); g.lineWidth = 1.5; g.strokeStyle = C.orange; g.stroke();
    g.drawImage(c.icon, -64, -9, 18, 18);
    text(c.txt, 8, 1, 11.5, C.ink);
    g.restore();
  });
  // botón de reencarnar (aparece al final de la vida)
  if (t > 33.0 && t < 35.1) {
    const pin = E.backOut(seg(t, 33.0, 33.4), 2);
    const press = ACTIONS.find(x => x.t === 33.5);
    const pr = t > 33.5 && t < 33.65 ? .93 : 1;
    g.save(); g.translate(330, 172); g.scale(pin * pr, pin * pr);
    rr(-80, -17, 160, 34, 17); g.fillStyle = C.yellow; g.fill(); g.lineWidth = 3; g.strokeStyle = C.brown; g.stroke();
    g.drawImage(IMG.oro, -74, -13, 26, 26);
    text('Reencarnar +3', 12, 1, 14, C.ink);
    g.restore();
    void press;
  }
  g.restore();
}
function drawBottomBar(t, a) {
  if (a <= 0) return;
  g.save(); g.globalAlpha = a; g.translate(0, (1 - a) * 60);
  rr(-4, 812, SW + 8, 140, 26); g.fillStyle = 'rgba(255,248,231,.94)'; g.fill();
  g.lineWidth = 1.5; g.strokeStyle = 'rgba(122,78,38,.3)'; g.stroke();
  const tabs = [
    ['Contratar', null], ['Mejoras', IMG.tab_upgrades], ['Vestimenta', IMG.tab_skins],
    ['Bonus', IMG.tab_gifts], ['Tienda', IMG.tab_shop], ['Menú', IMG.tab_menu],
  ];
  const xs = [41, 110, 180, 249, 318, 388];
  tabs.forEach(([label, im], i) => {
    const x = xs[i];
    let pr = 1;
    for (const ac of ACTIONS) if (ac.y === 856 && ac.x === x) { const d = t - ac.t; if (d >= 0 && d < .15) pr = .9; }
    g.save(); g.translate(x, 852); g.scale(pr, pr);
    if (i === 0) {
      g.drawImage(IMG.tab_active, -30, -28, 60, 56);
      const face = t > 12.9 && t < 35.1 ? IMG.face_trapito : IMG.face_homeless;
      g.save(); rr(-22, -24, 44, 44, 10); g.clip(); g.drawImage(face, -24, -26, 48, 48); g.restore();
    } else g.drawImage(im, -25, -25, 50, 50);
    g.restore();
    text(label, x, 892, 11, C.ink, { maxW: 68 });
  });
  rr(SW / 2 - 67, 916, 134, 5, 2.5); g.fillStyle = C.ink; g.fill();
  g.restore();
}
function drawQuickHire(t, a) {
  if (a <= 0) return;
  let pr = 1; const d = t - 9.55; if (d >= 0 && d < .15) pr = .92;
  g.save(); g.globalAlpha = a; g.translate(QH[0], QH[1]); g.scale(pr, pr);
  rr(-83, -25, 166, 50, 25); g.fillStyle = 'rgba(255,255,255,.96)'; g.fill(); g.lineWidth = 1.5; g.strokeStyle = 'rgba(0,0,0,.12)'; g.stroke();
  g.save(); g.beginPath(); g.arc(-56, 0, 19, 0, Math.PI * 2); g.clip(); g.drawImage(IMG.face_homeless, -76, -20, 40, 40); g.restore();
  text('El Fisura', -30, -8, 13, C.ink, { align: 'left', weight: 900 });
  g.drawImage(IMG.coin, -30, 4, 15, 15);
  text(t > 30 ? '19' : '25', -11, 12, 14, C.ink, { align: 'left' });
  g.restore();
  if (d >= 0 && d < .7) {
    g.save(); g.globalAlpha = a * (1 - seg(d, .4, .7));
    text('−25', QH[0] + 40, QH[1] - 44 - d * 50, 20, C.pink, { stroke: 4, strokeColor: C.cream });
    g.restore();
  }
}

// Panel de juego: marco de madera (v3), pergamino, moño, cápsula de título.
function gamePanel(cx, cy, w, h, o = {}) {
  const frame = o.frame || 'wood';
  g.save();
  g.translate(cx, cy);
  g.scale(o.s || 1, o.s || 1);
  g.globalAlpha *= o.alpha == null ? 1 : o.alpha;
  if (frame === 'machine' || frame === 'gold') {
    const im = frame === 'machine' ? IMG.panel_upgrades : IMG.panel_prestige;
    g.drawImage(im, -w / 2 - 12, -h / 2 - 12, w + 24, h + 24);
    rr(-w / 2 + 14, -h / 2 + 14, w - 28, h - 28, 14); g.fillStyle = C.parch; g.fill();
  } else {
    rr(-w / 2, -h / 2 + 6, w, h, 24); g.fillStyle = 'rgba(0,0,0,.3)'; g.fill();
    rr(-w / 2, -h / 2, w, h, 24); g.fillStyle = '#8B5A2B'; g.fill(); g.lineWidth = 3; g.strokeStyle = '#4A2E14'; g.stroke();
    rr(-w / 2 + 10, -h / 2 + 10, w - 20, h - 20, 16); g.fillStyle = C.parch; g.fill();
    g.lineWidth = 2; g.strokeStyle = 'rgba(122,78,38,.35)'; g.stroke();
  }
  if (o.bow) g.drawImage(IMG.bow, -34, -h / 2 - 34, 68, 68 * IMG.bow.height / IMG.bow.width);
  if (o.title) {
    g.font = `900 19px ${FONT_N}`;
    const tw = Math.min(g.measureText(o.title).width + 40, w - 40);
    rr(-tw / 2, -h / 2 + 28, tw, 38, 19); g.fillStyle = C.cream; g.fill(); g.lineWidth = 3; g.strokeStyle = C.brown; g.stroke();
    text(o.title, 0, -h / 2 + 48, 19, C.ink, { maxW: tw - 20 });
  }
  if (o.close !== false) {
    g.beginPath(); g.arc(w / 2 - 22, -h / 2 + 22, 11, 0, Math.PI * 2); g.fillStyle = '#E0473A'; g.fill();
    g.lineWidth = 2; g.strokeStyle = '#fff'; g.stroke();
    g.beginPath(); g.moveTo(w / 2 - 26, -h / 2 + 18); g.lineTo(w / 2 - 18, -h / 2 + 26); g.moveTo(w / 2 - 18, -h / 2 + 18); g.lineTo(w / 2 - 26, -h / 2 + 26); g.stroke();
  }
  g.restore();
}
function greenBtn(x, y, w, label, o = {}) {
  let pr = 1;
  if (o.pressT != null) { const d = o.t - o.pressT; if (d >= 0 && d < .15) pr = .92; }
  g.save(); g.translate(x, y); g.scale(pr, pr);
  const h = o.h || 34;
  rr(-w / 2, -h / 2 + 3, w, h, h / 2); g.fillStyle = '#2E7D3A'; g.fill();
  rr(-w / 2, -h / 2, w, h, h / 2); g.fillStyle = o.color || '#4CB85C'; g.fill(); g.lineWidth = 2; g.strokeStyle = o.stroke || '#2E7D3A'; g.stroke();
  text(label, 0, 1, o.size || 15, '#fff', { maxW: w - 16 });
  g.restore();
}
function panelAnim(t, t0, t1) {
  const pin = seg(t, t0, t0 + .45), pout = seg(t, t1 - .3, t1);
  return { s: lerp(.86, 1, E.backOut(pin, 1.4)) * (1 - E.expoIn(pout) * .08), alpha: cl(pin * 3) * (1 - pout), on: t >= t0 && t <= t1 };
}
function dim(a) { if (a > 0) { g.fillStyle = `rgba(20,12,4,${.5 * a})`; g.fillRect(0, 0, SW, SH); } }

// ── popups de la partida ──
function popupReveal(t) { // ¡NUEVO! El Trapito — la celebración esconde la UI
  const t0 = 11.45, t1 = 12.95;
  if (t < t0 || t > t1) return;
  const a = win(t, t0, t1, .25, .3);
  dim(a * 1.2);
  rays(SW / 2, 430, 16, t * .5, 420, 'rgba(255,217,61,1)', .35 * a);
  glow('gold', SW / 2, 430, 220, .6 * a);
  const back = E.cInOut(seg(t, 12.55, 12.95));
  const pop = E.elasticOut(seg(t, t0 + .05, t0 + .75));
  const x = lerp(SW / 2, SLOTS[0][0], back), y = lerp(560, SLOTS[0][1], back), h = lerp(300, CHARH, back) * pop;
  drawChar('trapito', x, y, h, { shadow: false, white: 1 - seg(t, t0, t0 + .3) });
  ribbonNew(SW / 2, 230, .9, seg(t, t0 + .2, t0 + .6), 1 - back);
  g.save(); g.globalAlpha = (1 - back) * seg(t, t0 + .4, t0 + .7);
  pill(SW / 2, 610, 200, 44, { fill: C.cream });
  text('El Trapito', SW / 2, 614, 22, C.ink);
  g.restore();
  burst(t, { t0: t0 + .05, x: SW / 2, y: 430, n: 40, seed: 2200, kind: 'confetti', spd: [300, 700], grav: 500, life: [1, 1.4], size: [8, 13], drag: 1.6 });
}
function bannerNewFloor(t) {
  const t0 = 15.55, t1 = 16.4;
  if (t < t0 || t > t1) return;
  const p = E.backOut(seg(t, t0, t0 + .4), 1.6), out = E.cIn(seg(t, t1 - .25, t1));
  g.save(); g.translate(SW / 2, 230 - out * 60); g.scale(p, p); g.globalAlpha = 1 - out;
  rr(-150, -40, 300, 80, 22); g.fillStyle = C.yellow; g.fill(); g.lineWidth = 3; g.strokeStyle = C.brown; g.stroke();
  text('¡PISO NUEVO!', 0, -10, 26, C.ink);
  text('Subí a visitarlo', 0, 20, 14, C.brown);
  g.restore();
}
function popupCareer(t) {
  const P = panelAnim(t, 16.95, 19.55);
  if (!P.on) return;
  dim(P.alpha);
  g.save(); g.globalAlpha = P.alpha;
  g.translate(SW / 2, 440); g.scale(P.s, P.s); g.translate(-SW / 2, -440);
  gamePanel(SW / 2, 440, 390, 520, { bow: true, title: '¡Te recibiste en la UBA!' });
  text('¿Y ahora qué?', SW / 2, 262, 16, C.brown);
  wrap('Elegí tu carrera. Dura hasta la próxima reencarnación.', SW / 2, 284, 11, 320, 14, '#7d6a55', { weight: 700 });
  const rows = [
    ['junior_programmer', 'Programador Jr.', 'Bienvenida: 45K de plata'],
    ['junior_architect', 'Arquitecto Jr.', 'Skin exclusiva: Pie de Obra'],
    ['junior_doctor', 'Médico Jr.', 'Café Cargado gratis, sin cooldown'],
    ['junior_lawyer', 'Abogado Jr.', '−50% al costo de contratar, 10 min'],
  ];
  const sel = seg(t, 18.9, 19.05);
  rows.forEach(([id, name, rew], i) => {
    const y = 336 + i * 90;
    const pin = E.backOut(seg(t, 17.2 + i * .12, 17.6 + i * .12), 1.6);
    g.save(); g.translate(SW / 2, y); g.scale(pin, pin);
    const isSel = i === 0;
    rr(-170, -38, 340, 76, 14); g.fillStyle = isSel && sel > 0 ? '#FFE3B8' : '#FFF8E7'; g.fill();
    g.lineWidth = isSel && sel > 0 ? 3.5 : 2; g.strokeStyle = isSel && sel > 0 ? C.orange : 'rgba(122,78,38,.45)'; g.stroke();
    g.save(); g.beginPath(); g.arc(-128, 0, 27, 0, Math.PI * 2); g.fillStyle = C.parch; g.fill(); g.clip();
    g.drawImage(IMG['face_' + id], -156, -28, 56, 56); g.restore();
    g.beginPath(); g.arc(-128, 0, 27, 0, Math.PI * 2); g.lineWidth = 2; g.strokeStyle = C.brown; g.stroke();
    text(name, -90, -11, 16, C.ink, { align: 'left' });
    text(rew, -90, 13, 11.5, '#6f5b44', { align: 'left', weight: 700, maxW: 250 });
    g.restore();
  });
  g.restore();
}
const BOOSTS = [
  ['b_mate', 'Unos Mates', null], ['b_cafe', 'Café Cargado', 'Corporativo'], ['b_asado', 'Asado del Domingo', 'Marte'],
  ['b_milanesa', 'Milanesa', 'Galaxia'], ['b_turbo', 'Modo Enfocado', 'Reino divino'],
];
function panelGifts(t) {
  const P = panelAnim(t, 20.85, 23.15);
  if (!P.on) return;
  dim(P.alpha);
  g.save(); g.globalAlpha = P.alpha;
  g.translate(SW / 2, 480); g.scale(P.s, P.s); g.translate(-SW / 2, -480);
  gamePanel(SW / 2, 480, 400, 620, { bow: true, title: 'Regalos' });
  // racha diaria
  text('Racha diaria', 38, 248, 14, C.brown, { align: 'left' });
  for (let d = 0; d < 7; d++) {
    const x = 50 + d * 55, y = 290;
    const today = d === 3, done = d < 3;
    const pulse = today ? 1 + Math.sin(t * 6) * .04 : 1;
    g.save(); g.translate(x, y); g.scale(pulse, pulse);
    rr(-24, -28, 48, 56, 10); g.fillStyle = done ? '#E4F5E1' : today ? '#FFE3B8' : '#FFF8E7'; g.fill();
    g.lineWidth = today ? 3 : 1.5; g.strokeStyle = today ? C.orange : 'rgba(122,78,38,.4)'; g.stroke();
    text(String(d + 1), 0, -14, 12, C.brown);
    if (d === 6) g.drawImage(IMG.chest, -14, -4, 28, 28 * IMG.chest.height / IMG.chest.width);
    else g.drawImage(IMG.coin, -10, -2, 20, 20);
    if (done) { g.strokeStyle = '#2E9A48'; g.lineWidth = 3; g.beginPath(); g.moveTo(8, 12); g.lineTo(13, 18); g.lineTo(22, 6); g.stroke(); }
    g.restore();
  }
  // boosts
  text('Boosts', 38, 350, 14, C.brown, { align: 'left' });
  const act = seg(t, 21.75, 21.9);
  BOOSTS.forEach(([key, name, lock], i) => {
    const col = i % 3, row = Math.floor(i / 3);
    const x = 82 + col * 133 + (row ? 66 : 0), y = 430 + row * 138;
    const pin = E.backOut(seg(t, 21.0 + i * .08, 21.4 + i * .08), 1.6);
    g.save(); g.translate(x, y); g.scale(pin, pin);
    const on = i === 0 && act > 0;
    if (on) glow('gold', 0, 0, 90, .5 + .2 * Math.sin(t * 5));
    rr(-58, -60, 116, 124, 14); g.fillStyle = lock ? '#EDE3CF' : on ? '#FFF1C9' : '#FFF8E7'; g.fill();
    g.lineWidth = on ? 3 : 1.5; g.strokeStyle = on ? C.orange : 'rgba(122,78,38,.4)'; g.stroke();
    g.save(); if (lock) g.globalAlpha *= .45;
    g.drawImage(IMG[key], -30, -52, 60, 60);
    g.restore();
    text(name, 0, 20, 11.5, lock ? '#8e8170' : C.ink, { maxW: 108 });
    if (lock) { lockIcon(22, -40, .32, '#8e8170'); text('Se desbloquea en', 0, 38, 9, '#8e8170', { weight: 700 }); text(lock, 0, 50, 9.5, '#8e8170'); }
    else if (on) text('Activo · 0:59', 0, 44, 11, C.orange);
    else greenBtn(0, 44, 80, 'Activar', { h: 24, size: 12, t, pressT: 21.75 });
    g.restore();
  });
  // cofres
  text('Cofres de pintas', 38, 660, 14, C.brown, { align: 'left' });
  g.save();
  rr(38, 682, 354, 70, 14); g.fillStyle = '#FFF8E7'; g.fill(); g.lineWidth = 1.5; g.strokeStyle = 'rgba(122,78,38,.4)'; g.stroke();
  const shake = t > 22.4 && t < 22.95 ? Math.sin(t * 40) * 2 : 0;
  g.drawImage(IMG.chest, 52 + shake, 690, 64, 54);
  text('1 sin abrir', 130, 717, 14, C.ink, { align: 'left' });
  greenBtn(330, 717, 90, 'Abrir', { h: 30, size: 14, t, pressT: 22.95 });
  g.restore();
  g.restore();
}
function chestOverlay(t) {
  const t0 = 23.1, t1 = 25.2;
  if (t < t0 || t > t1) return;
  const a = win(t, t0, t1, .25, .35);
  g.fillStyle = `rgba(16,10,4,${.82 * a})`; g.fillRect(0, 0, SW, SH);
  rays(SW / 2, 470, 18, t * .4, 500, 'rgba(255,217,61,1)', .25 * a * seg(t, 24.0, 24.3));
  // animación real del cofre (frames 23–49 a 36 fps)
  if (t < 24.05) {
    const idx = t < 23.3 ? 0 : 23 + Math.min(26, Math.floor((t - 23.3) * 36));
    const im = IMG['chest_f' + idx];
    const s = 340 / im.width * (1 + seg(t, 23.95, 24.05) * .1);
    g.save(); g.globalAlpha = a; g.drawImage(im, SW / 2 - im.width * s / 2, 470 - im.height * s / 2, im.width * s, im.height * s); g.restore();
    if (t < 23.3) text('Tocá para abrir el cofre', SW / 2, 600, 14, C.cream, { alpha: a });
  }
  const fl = seg(t, 24.0, 24.08) * (1 - seg(t, 24.08, 24.3));
  if (fl > 0) { g.fillStyle = `rgba(255,250,230,${fl})`; g.fillRect(0, 0, SW, SH); }
  if (t >= 24.05) {
    // la carta gira y muestra la pinta
    const flip = E.cOut(seg(t, 24.05, 24.45));
    const cw = 320, ch = cw * IMG.card.height / IMG.card.width;
    g.save(); g.globalAlpha = a; g.translate(SW / 2, 460); g.scale(Math.max(.02, flip), 1);
    g.drawImage(IMG.card, -cw / 2, -ch / 2, cw, ch);
    if (flip > .5) {
      glow('gold', 0, 10, 130, .35);
      drawChar('homeless_idle__oro', 0, 128, 240, { shadow: false });
      g.save(); rr(-40, -182, 80, 24, 12); g.fillStyle = '#9B59D0'; g.fill(); g.lineWidth = 2; g.strokeStyle = '#fff'; g.stroke(); g.restore();
      text('Épica', 0, -169, 13, '#fff');
    }
    g.restore();
    if (flip > .5) {
      g.save(); g.globalAlpha = a * seg(t, 24.25, 24.45);
      text('¡Pinta nueva!', SW / 2, 250, 30, C.yellow, { stroke: 7 });
      text('De Oro', SW / 2, 645, 26, C.cream, { stroke: 6 });
      text('Para El Fisura.', SW / 2, 672, 15, C.cream, { stroke: 4 });
      g.restore();
    }
    g.save(); g.globalAlpha = a * seg(t, 24.4, 24.6);
    greenBtn(SW / 2, 728, 150, 'Ponérsela', { t, pressT: 24.75, h: 38, size: 16 });
    g.restore();
    burst(t, { t0: 24.08, x: SW / 2, y: 460, n: 36, seed: 2300, kind: 'confetti', spd: [300, 750], grav: 500, life: [1, 1.5], size: [8, 13], drag: 1.5 });
  }
}
function eventBanner(t, t0, t1, title, body, color, icon) {
  if (t < t0 || t > t1) return;
  const p = E.backOut(seg(t, t0, t0 + .45), 1.5), out = E.cIn(seg(t, t1 - .3, t1));
  g.save(); g.translate(SW / 2, 222 - out * 40); g.scale(p, p); g.globalAlpha = 1 - out;
  rr(-190, -40, 380, 80, 18); g.fillStyle = color; g.fill(); g.lineWidth = 3; g.strokeStyle = C.ink; g.stroke();
  if (icon) g.drawImage(icon, -178, -26, 52, 52);
  text(title, 22, -14, 17, '#fff', { stroke: 4, maxW: 300 });
  text(body, 22, 14, 12, '#fff', { weight: 700, maxW: 300 });
  g.restore();
}
function popupSpecial(t) {
  const P = panelAnim(t, 27.65, 28.9);
  if (!P.on) return;
  dim(P.alpha);
  g.save(); g.globalAlpha = P.alpha;
  g.translate(SW / 2, 470); g.scale(P.s, P.s); g.translate(-SW / 2, -470);
  gamePanel(SW / 2, 470, 370, 470, { bow: true, title: '¡Apareció un personaje especial!' });
  rr(SW / 2 - 150, 300, 300, 290, 16); g.fillStyle = '#FFF3C4'; g.fill(); g.lineWidth = 3; g.strokeStyle = C.yellow; g.stroke();
  rr(SW / 2 - 70, 316, 140, 150, 12); g.fillStyle = '#FBE39A'; g.fill(); g.lineWidth = 2; g.strokeStyle = 'rgba(122,78,38,.5)'; g.stroke();
  drawChar('sp_cryptobro', SW / 2, 458, 132, { shadow: false });
  text('Crypto Bro', SW / 2, 492, 20, C.ink);
  wrap('Te dice "hacé tu propia investigación" y te muestra un JPG de un mono. +3% de income, DYOR.', SW / 2, 540, 12, 260, 15, '#6f5b44');
  greenBtn(SW / 2, 650, 130, '¡Es mío!', { t, pressT: 28.55, h: 36, size: 16 });
  g.restore();
}
const UPGRADES = [
  ['up_income', 'Más Platita', 'Todo lo que genera la torre entra más gordo.', 3],
  ['up_tap', 'Dedos Curtidos', 'Cada dedazo tuyo vale más.', 5],
  ['up_crit', 'Pegarla', 'Cada tanto un toque sale premiado.', 2],
  ['up_offline', 'Modo Siesta', 'Mientras dormís, la torre sigue laburando.', 4],
  ['up_spawn', 'Precios Cuidados', 'Contratar sale más barato.', 1],
];
function panelUpgrades(t) {
  const P = panelAnim(t, 29.5, 31.55);
  if (!P.on) return;
  dim(P.alpha);
  g.save(); g.globalAlpha = P.alpha;
  g.translate(SW / 2, 470); g.scale(P.s, P.s); g.translate(-SW / 2, -470);
  gamePanel(SW / 2, 470, 400, 600, { frame: 'machine', title: 'Mejoras' });
  // pestañas
  rr(40, 230, 170, 34, 17); g.fillStyle = '#E6DCC6'; g.fill(); text('Personajes', 125, 248, 14, '#7d6a55');
  rr(220, 230, 170, 34, 17); g.fillStyle = C.orange; g.fill(); g.lineWidth = 2; g.strokeStyle = C.brown; g.stroke(); text('Permanentes', 305, 248, 14, '#fff');
  const bought = [30.1, 30.5, 30.9].filter(x => t >= x + .05).length;
  g.drawImage(IMG.oro, 150, 272, 22, 22); text(`ORO: ${12 - bought * 2}`, 215, 284, 14, C.brown);
  UPGRADES.forEach(([ic, name, flav, lv], i) => {
    const y = 336 + i * 84;
    const pin = E.backOut(seg(t, 29.7 + i * .08, 30.05 + i * .08), 1.5);
    g.save(); g.translate(SW / 2, y); g.scale(pin, pin);
    const hot = i === 0 && t > 30.05 && t < 31.3;
    if (hot) glow('gold', 0, 0, 160, .25);
    rr(-178, -36, 356, 72, 14); g.fillStyle = hot ? '#FFF1C9' : '#FFF8E7'; g.fill();
    g.lineWidth = hot ? 3 : 1.5; g.strokeStyle = hot ? C.orange : 'rgba(122,78,38,.4)'; g.stroke();
    g.drawImage(IMG[ic], -170, -28, 56, 56);
    text(name, -106, -18, 15, C.ink, { align: 'left' });
    text(flav, -106, 2, 10, '#7d6a55', { align: 'left', weight: 700, maxW: 180 });
    const lvl = lv + (i === 0 ? bought : 0);
    for (let k = 0; k < 10; k++) {
      rr(-106 + k * 16, 16, 13, 8, 3);
      const fresh = i === 0 && k === lvl - 1 && bought > 0;
      g.fillStyle = k < lvl ? (fresh ? C.yellow : C.green) : '#DDD2BC'; g.fill();
    }
    let pr = 1; for (const x of [30.1, 30.5, 30.9]) { const d = t - x; if (i === 0 && d >= 0 && d < .15) pr = .9; }
    g.save(); g.translate(141, 0); g.scale(pr, pr);
    rr(-30, -18, 60, 36, 18); g.fillStyle = C.yellow; g.fill(); g.lineWidth = 2; g.strokeStyle = C.brown; g.stroke();
    g.drawImage(IMG.oro, -24, -10, 20, 20); text(String(i === 0 ? 2 : [0, 2, 3, 3, 1][i]), 8, 1, 15, C.ink);
    g.restore();
    text(`Nivel ${lvl} / 10`, 60, 20, 10, '#7d6a55', { align: 'left' });
    g.restore();
    if (i === 0) for (const x of [30.1, 30.5, 30.9]) {
      const d = t - x;
      if (d >= 0 && d < .6) text('+20%', SW / 2 + 130, y - 30 - d * 50, 16, C.green, { stroke: 4, strokeColor: C.cream, alpha: 1 - seg(d, .35, .6) });
    }
  });
  g.restore();
}
function popupOffline(t) {
  const P = panelAnim(t, 31.75, 32.95);
  if (!P.on) return;
  dim(P.alpha);
  g.save(); g.globalAlpha = P.alpha;
  g.translate(SW / 2, 470); g.scale(P.s, P.s); g.translate(-SW / 2, -470);
  gamePanel(SW / 2, 470, 340, 330, { bow: true, title: 'Mientras no estabas…', close: false });
  // luna y zzz
  const mz = t - 31.75;
  g.drawImage(IMG.up_offline, SW / 2 - 40, 380, 80, 80);
  for (let k = 0; k < 3; k++) { const ph = (mz * .8 + k / 3) % 1; text('z', SW / 2 + 40 + ph * 30, 400 - ph * 40, 14 + k * 3, C.brown, { alpha: 1 - ph }); }
  g.drawImage(IMG.coin, SW / 2 - 90, 482, 36, 36);
  text('+48,2K', SW / 2 + 16, 501, 34, C.ink);
  greenBtn(SW / 2, 578, 140, 'Cobrar', { t, pressT: 32.6, h: 38, size: 17 });
  g.restore();
  burst(t, { t0: 32.62, x: SW / 2, y: 501, n: 22, seed: 2400, kind: 'coin', spd: [300, 700], ang: [-Math.PI * .95, -Math.PI * .05], grav: 900, life: [.6, 1], size: [18, 28] });
}
function popupPrestige(t) {
  const P = panelAnim(t, 33.7, 35.1);
  if (!P.on) return;
  dim(P.alpha);
  g.save(); g.globalAlpha = P.alpha;
  g.translate(SW / 2, 470); g.scale(P.s, P.s); g.translate(-SW / 2, -470);
  gamePanel(SW / 2, 470, 380, 480, { frame: 'gold', title: '¿Reencarnar?' });
  g.drawImage(IMG.oro, SW / 2 - 96, 300, 60, 60);
  text('+3 ORO', SW / 2 + 30, 332, 36, C.ink);
  wrap('Tu multiplicador global pasa de ×1,0 a ×1,6', SW / 2, 398, 14, 300, 18, C.brown);
  wrap('Conservás: tu ORO, el multiplicador, las mejoras permanentes y las skins', SW / 2, 450, 11.5, 300, 15, '#6f5b44', { weight: 700 });
  wrap('Cada vida arranca más rápido.', SW / 2, 500, 13, 300, 16, C.orange);
  // botones
  g.save(); rr(SW / 2 - 160, 572, 130, 40, 20); g.fillStyle = '#E3D9C4'; g.fill(); g.restore();
  text('Todavía no', SW / 2 - 95, 593, 14, '#7d6a55');
  let pr = 1; const d = t - 34.95; if (d >= 0 && d < .15) pr = .92;
  g.save(); g.translate(SW / 2 + 70, 592); g.scale(pr, pr);
  rr(-86, -22, 172, 44, 22); g.fillStyle = '#3F7FE0'; g.fill(); g.lineWidth = 2.5; g.strokeStyle = '#214C94'; g.stroke();
  g.drawImage(IMG.reincarnate, -80, -17, 34, 34);
  text('Reencarnar ahora', 16, 1, 13.5, '#fff', { maxW: 124 });
  g.restore();
  g.restore();
}

// Reencarnación: la pantalla se enrosca en una espiral de luz y renace.
function rebirthFx(t) {
  const d = t - 35.1;
  if (d < 0 || d > 1.6) return;
  const a = seg(d, 0, .5) * (1 - seg(d, .9, 1.5));
  g.save();
  g.globalCompositeOperation = 'lighter';
  const r = rng(77);
  for (let i = 0; i < 260; i++) {
    const arm = i % 4, dd = r();
    const ang = arm * Math.PI / 2 + dd * 5 + d * 5;
    const rad = (1 - dd) * 320 * (1 - E.cIn(seg(d, 0, .9)) * .85);
    g.globalAlpha = a * (.4 + .6 * r());
    g.fillStyle = r() < .6 ? '#FFE9A8' : '#FFFFFF';
    const s = 2 + r() * 4;
    g.fillRect(SW / 2 + Math.cos(ang) * rad, 460 + Math.sin(ang) * rad, s, s);
  }
  g.restore();
  const wf = seg(d, .7, .95) * (1 - seg(d, 1.0, 1.5));
  if (wf > 0) { g.fillStyle = `rgba(255,248,220,${wf})`; g.fillRect(0, 0, SW, SH); }
  if (d > 1.0) {
    glow('gold', SLOTS[0][0], SLOTS[0][1] - 70, 120, (1 - seg(d, 1.0, 1.6)) * .9);
  }
}
function drawGameScreen(t) {
  // mundo con la cámara del ascensor y la espiral de la reencarnación
  const f = worldFloorOffset(t);
  const tw = t > 35.1 && t < 36.1 ? E.cIn(seg(t, 35.1, 36.0)) : 0;
  g.save();
  if (tw > 0) { g.translate(SW / 2, 460); g.rotate(tw * 2.2); g.scale(1 - tw * .75, 1 - tw * .75); g.translate(-SW / 2, -460); }
  const ali = IMG.bg_alley, urb = IMG.bg_urban;
  g.save(); g.translate(0, f * SH); drawBgPts(ali, 1.55, -40, -40); g.restore();
  if (f > 0) { g.save(); g.translate(0, (f - 1) * SH); drawBgPts(urb, 1.55, 0, -40);
    const land = seg(t, 16.8, 17.1);
    drawChar('mantero', SW / 2, 742, CHARH * (1 + Math.sin(land * Math.PI) * .06), {});
    g.restore();
    g.fillStyle = '#4A3A2C'; g.fillRect(0, f * SH - 14, SW, 14);
  }
  if (f < 1) { g.save(); g.translate(0, f * SH); drawBoard(t); drawTapFx(t); g.restore(); }
  // lluvia del Plan Platita
  burst(t, { t0: 25.4, x: SW / 2, y: -40, n: 50, seed: 2500, kind: 'coin', spd: [60, 160], ang: [Math.PI * .35, Math.PI * .65], grav: 700, life: [1.4, 1.8], size: [18, 30], spread: 440, delay: 1.1 });
  g.restore();
  // UI (la celebración de personaje nuevo y el cofre la esconden)
  const hideA = 1 - win(t, 11.35, 13.0, .25, .35) - win(t, 23.05, 25.3, .25, .3) - win(t, 35.1, 36.3, .3, .4);
  const uiIn = E.cOut(seg(t, 5.9, 6.6));
  const uia = cl(uiIn * cl(hideA));
  drawHud(t, uia);
  eventBanner(t, 25.3, 26.85, '¡Cayó el Plan Platita!', 'Imprimimos alegría x3. No preguntes de dónde sale.', '#E8A317', IMG.coin);
  eventBanner(t, 26.95, 27.75, 'Se cayó Mercado Pago', 'Nadie puede pagar nada. Todo sale el doble.', '#D9443A', null);
  bannerNewFloor(t);
  drawQuickHire(t, uia * (1 - seg(t, 16.2, 16.4) + seg(t, 20.3, 20.6)));
  drawBottomBar(t, uia);
  popupReveal(t);
  popupCareer(t);
  panelGifts(t);
  chestOverlay(t);
  popupSpecial(t);
  panelUpgrades(t);
  popupOffline(t);
  popupPrestige(t);
  rebirthFx(t);
  drawFinger(t);
}
function drawPhone(t, a = 1) {
  const p = track(t, PHONE);
  g.save();
  g.globalAlpha = a;
  g.translate(p.x, p.y); g.rotate(p.r); g.scale(p.k, p.k);
  // carcasa
  rr(-SW / 2 - 12, -SH / 2 - 12 + 10, SW + 24, SH + 24, 62); g.fillStyle = 'rgba(0,0,0,.45)'; g.fill();
  rr(-SW / 2 - 12, -SH / 2 - 12, SW + 24, SH + 24, 62); g.fillStyle = '#121212'; g.fill();
  g.lineWidth = 2.5; g.strokeStyle = '#3a3a3a'; g.stroke();
  g.save();
  rr(-SW / 2, -SH / 2, SW, SH, 52); g.clip();
  g.translate(-SW / 2, -SH / 2);
  drawGameScreen(t);
  rr(SW / 2 - 62, 12, 124, 36, 18); g.fillStyle = '#000'; g.fill(); // isla dinámica
  g.restore();
  g.restore();
}

// ───────────────────────── fondo del video, CTA ─────────────────────────
function ambient(t) {
  const gr = g.createLinearGradient(0, 0, 0, H);
  gr.addColorStop(0, '#1E1410'); gr.addColorStop(1, '#2B1B12');
  g.fillStyle = gr; g.fillRect(0, 0, W, H);
  g.save(); g.globalAlpha = .12; sunburst(540, 900, 28, t * .06, 'rgba(0,0,0,0)', C.orange, 2400); g.restore();
  glow('warm', 540, 1000, 1000, .45);
  burst(t, { t0: 0, x: 540, y: 2000, n: 60, seed: 3000, kind: 'dust', spd: [40, 110], ang: [-Math.PI * .62, -Math.PI * .38], life: [6, 9], size: [10, 26], spread: 1200, delay: 45, alpha: .35 });
}
function sceneCTA(t) {
  const d = t - 42.2;
  const gr = g.createRadialGradient(540, 700, 100, 540, 900, 1400);
  gr.addColorStop(0, '#3A2414'); gr.addColorStop(1, '#140C08');
  g.fillStyle = gr; g.fillRect(0, 0, W, H);
  g.save(); g.globalAlpha = .18; sunburst(540, 620, 28, t * .08, 'rgba(0,0,0,0)', C.orange, 2400); g.restore();
  glow('warm', 540, 620, 800, .6);
  burst(t, { t0: 42.2, x: 540, y: 2000, n: 50, seed: 3100, kind: 'dust', spd: [80, 200], ang: [-Math.PI * .65, -Math.PI * .35], life: [2.5, 3.2], size: [12, 30], spread: 1100, delay: 2.4, alpha: .55 });
  // ícono de la app
  const ip = E.backOut(seg(t, 42.3, 42.8), 1.7);
  const is = 380 * ip;
  g.save(); g.translate(540, 560 + Math.sin(d * 2) * 6);
  rr(-is / 2, -is / 2 + 14, is, is, is * .22); g.fillStyle = 'rgba(0,0,0,.45)'; g.fill();
  rr(-is / 2, -is / 2, is, is, is * .22); g.save(); g.clip(); g.drawImage(IMG.app_icon, -is / 2, -is / 2, is, is); g.restore();
  g.restore();
  rays(540, 560, 16, t * .3, 620 * ip, 'rgba(255,217,61,1)', .12);
  title('FISUEVOLUTION', 540, 850, 104, { tin: t - 42.55, stagger: .025, anim: 'rise', dur: .55 });
  title('DESCARGALO GRATIS', 540, 985, 104, { tin: t - 42.8, stagger: .025, anim: 'rise', dur: .55, gold: true, maxW: 980 });
  const bp = E.backOut(seg(t, 43.2, 43.6), 2);
  const pulse = t > 43.9 ? 1 + Math.max(0, Math.sin((t - 43.9) * Math.PI * 1.6)) * .025 : 1;
  appStoreBadge(540, 1140, 430, bp * pulse, cl(bp));
  // firma del estudio
  const ap = E.cOut(seg(t, 43.4, 43.9));
  g.save(); g.globalAlpha = ap;
  text('UN JUEGO DE', 540, 1300, 30, 'rgba(255,248,231,.75)');
  const lw = 380, lh = lw * IMG.ader.height / IMG.ader.width;
  g.drawImage(IMG.ader, 540 - lw / 2, 1340 + (1 - ap) * 20, lw, lh);
  g.restore();
  flash(1 - seg(t, 42.2, 42.45), '#FFF3D0');
}

// ───────────────────────── compositor v2 ─────────────────────────
const BLUR = [
  [2.2, 3.6, 4],
  [4.9, 5.7, 5],
  [16.3, 16.95, 4], [20.0, 20.6, 4],
  [35.4, 36.1, 4],
  [38.0, 38.9, 5],
  [39.2, 40.8, 4],
];
function towerCam(t) {
  if (t < 5.6) {
    const camY = track(t, [[0, floorCY(9) + 40], [1.3, floorCY(9) + 20], [4.4, floorCY(0)], [5.6, floorCY(0) + 60, E.cIn]]);
    const z = track(t, [[0, 1.3], [1.3, 1.22], [4.4, 1.02], [5.6, 2.9, E.cIn]]);
    return { camY, z };
  }
  const camY = track(t, [[38.0, floorCY(0) + 40], [38.9, floorCY(0)], [39.2, floorCY(0)], [41.4, floorCY(9) + 30], [42.3, floorCY(9) + 60]]);
  const z = track(t, [[38.0, 2.2], [38.9, 1.0, E.cOut], [39.2, 1.0], [41.4, 1.15], [42.3, 2.4, E.cIn]]);
  return { camY, z };
}
function drawScene(t) {
  g.setTransform(SCALE, 0, 0, SCALE, 0, 0);
  g.globalAlpha = 1; g.globalCompositeOperation = 'source-over';
  g.fillStyle = '#000'; g.fillRect(0, 0, W, H);
  const sh = shakeAt(t);
  g.save(); g.translate(sh.x, sh.y);
  if (t < 5.6) {
    const c = towerCam(t);
    drawTower(t, c.camY, c.z, i => i === 0);
    if (t > 4.9) { g.save(); g.globalAlpha = seg(t, 5.1, 5.6); ambient(t); drawPhone(t); g.restore(); }
  } else if (t < 38.0) {
    ambient(t);
    drawPhone(t);
  } else if (t < 42.2) {
    const c = towerCam(t);
    drawTower(t, c.camY, c.z, i => i <= 1);
    if (t < 38.9) { g.save(); g.globalAlpha = 1 - seg(t, 38.3, 38.9); ambient(t); drawPhone(t); g.restore(); }
    flash(seg(t, 41.9, 42.2), '#FFF3D0');
  } else sceneCTA(t);
  g.restore();

  // leyendas (fuera del teléfono)
  caption(t, '¿QUÉ HAY EN', .3, 1.6, 330, 108);
  caption(t, 'EL ÚLTIMO PISO?', .5, 1.6, 450, 118, { gold: true });
  caption(t, 'VOS ARRANCÁS ACÁ.', 3.9, 5.2, 330, 110);
  caption(t, 'TOCÁ. JUNTÁ PLATA.', 6.5, 8.95, 700, 92);
  caption(t, 'CONTRATÁ.', 9.2, 10.2, 700, 110);
  caption(t, 'FUSIONÁ.', 10.4, 11.3, 700, 120, { gold: true });
  caption(t, 'LABURAN SOLOS.', 13.2, 14.35, 700, 104);
  caption(t, 'CADA PISO,', 14.6, 16.5, 760, 100);
  caption(t, 'ALGUIEN NUEVO.', 14.75, 16.5, 880, 104, { gold: true });
  caption(t, 'ELEGÍ TU CARRERA.', 17.0, 19.4, 260, 96);
  caption(t, 'ACTIVÁ BONUS.', 20.8, 22.5, 290, 100);
  caption(t, 'ABRÍ COFRES. GANÁ PINTAS.', 22.9, 25.0, 290, 84, { gold: true });
  caption(t, 'SOBREVIVÍ A LA', 25.4, 27.4, 290, 92);
  caption(t, 'ECONOMÍA ARGENTINA.', 25.55, 27.4, 395, 88, { gold: true });
  caption(t, 'ENCONTRÁ ESPECIALES.', 27.7, 28.9, 290, 88);
  caption(t, 'MEJORÁ TODO.', 29.5, 31.3, 270, 104);
  caption(t, 'GANÁ HASTA DURMIENDO.', 31.7, 33.0, 290, 86, { gold: true });
  caption(t, 'REENCARNÁ.', 33.6, 35.0, 260, 112, { gold: true });
  caption(t, 'CADA VIDA,', 36.3, 37.9, 640, 104);
  caption(t, 'MÁS RÁPIDO.', 36.45, 37.9, 760, 110, { gold: true });
  caption(t, '+30 PERSONAJES', 39.0, 40.9, 330, 110, { gold: true });
  caption(t, 'DESCUBRILOS UNO POR UNO.', 39.4, 40.9, 450, 80);
  caption(t, '¿QUÉ HAY EN EL', 41.1, 42.0, 330, 104);
  caption(t, 'ÚLTIMO PISO?', 41.25, 42.0, 450, 118, { gold: true });
}

function sceneSetup() {
  impact(11.2, 6); impact(15.0, 5); impact(24.08, 8); impact(36.1, 10); impact(42.2, 14);
  for (const a of ACTIONS) if (a.crit) impact(a.t, 6);
}
window.DURATION = DURATION;
boot();
