'use strict';
// Reel v9 · BOFU — «Tu primer minuto» (20 s).
// Cronómetro sobre la partida real: 25 toques (1 moneda cada uno), contratar
// el segundo Fisura (25), arrastrar y fusionar → ¡NUEVO! El Trapito. Después,
// los 35 que faltan en silueta, y la placa de conversión.

const DURATION = 20;
const SW = 430, SH = 932, K = 1.72;
const T_PHONE = 2.6, T_OUT = 12.6, T_GRID = 13.2, T_CARD = 15.6;
const TAPS = Array.from({ length: 25 }, (_, k) => 3.3 + k * .16); // 25 toques a ~6 por segundo
const T_HIRE = 7.75, T_DRAG0 = 8.25, T_DRAG1 = 8.95, T_NEW = 9.0;

function assetList() {
  const U = n => RES + 'ui.atlas/' + n + '@3x.png';
  const L = commonAssets({
    coin_plus: U('ui_coin_plus'), elevator: U('ui_elevator'), face_homeless: U('homeless_face'), face_trapito: U('trapito_face'),
    tab_active: U('ui_tab_active'), tab_upgrades: U('ui_tab_upgrades'), tab_skins: U('ui_tab_skins'), tab_gifts: U('ui_tab_gifts'),
    tab_shop: U('ui_tab_shop'), tab_menu: U('ui_tab_menu'),
  });
  L.bg_alley = RES + 'Backgrounds/bg_alley@3x.png';
  for (const [id] of TIERS) if (!id.startsWith('junior_') && !id.startsWith('senior_') || id === 'junior_programmer' || id === 'senior_programmer') L[id] = charPath(id);
  return L;
}

// ── la partida (en puntos de iPhone) ──
function coinsAt(t) {
  let c = TAPS.filter(x => t >= x + .35).length;
  if (t >= T_HIRE) c -= 25;
  if (t >= 10.8) c += Math.floor((t - 10.8) * 5);
  return Math.max(0, c);
}
function hud(t) {
  rr(-4, -30, SW + 8, 158, 26); g.fillStyle = 'rgba(255,248,231,.86)'; g.fill();
  g.lineWidth = 1.5; g.strokeStyle = 'rgba(122,78,38,.35)'; g.stroke();
  g.drawImage(IMG.coin_plus, 14, 60, 54, 54 * IMG.coin_plus.height / IMG.coin_plus.width);
  const str = String(coinsAt(t));
  g.font = `900 30px ${FONT_N}`;
  const gw = 38 + g.measureText(str).width, gx = SW / 2 - gw / 2;
  let bump = 0; for (const x of TAPS) { const d = t - x - .35; if (d >= 0 && d < .12) bump = 1 - d / .12; }
  g.drawImage(IMG.coin, gx - bump * 2, 68 - bump * 2, 30 + bump * 4, 30 + bump * 4);
  g.textAlign = 'left'; g.textBaseline = 'middle'; g.fillStyle = C.ink; g.fillText(str, gx + 38, 84);
  text(t > 10.8 ? '1/s' : '0/s', SW / 2, 110, 13, '#8b8378');
  const eh = 60, ew = eh * IMG.elevator.width / IMG.elevator.height;
  g.drawImage(IMG.elevator, 392 - ew / 2, 88 - eh / 2, ew, eh);
  rr(SW / 2 - 34, 137, 68, 22, 11); g.fillStyle = '#fff'; g.fill();
  star4(SW / 2 - 19, 148, 7, C.pink); text('×1,0', SW / 2 + 6, 149, 12.5, C.ink);
}
function bottomBar() {
  rr(-4, 812, SW + 8, 140, 26); g.fillStyle = 'rgba(255,248,231,.94)'; g.fill();
  const tabs = [['Contratar', null], ['Mejoras', IMG.tab_upgrades], ['Vestimenta', IMG.tab_skins], ['Bonus', IMG.tab_gifts], ['Tienda', IMG.tab_shop], ['Menú', IMG.tab_menu]];
  [41, 110, 180, 249, 318, 388].forEach((x, i) => {
    if (i === 0) { g.drawImage(IMG.tab_active, x - 30, 824, 60, 56); g.save(); rr(x - 22, 828, 44, 44, 10); g.clip(); g.drawImage(IMG.face_homeless, x - 24, 826, 48, 48); g.restore(); }
    else g.drawImage(tabs[i][1], x - 25, 827, 50, 50);
    text(tabs[i][0], x, 892, 11, C.ink, { maxW: 68 });
  });
  rr(SW / 2 - 67, 916, 134, 5, 2.5); g.fillStyle = C.ink; g.fill();
}
function quickHire(t) {
  const pr = t >= T_HIRE && t < T_HIRE + .15 ? .92 : 1;
  const ready = coinsAt(t) >= 25 && t < T_HIRE;
  g.save(); g.translate(95, 777); g.scale(pr, pr);
  if (ready) glow('gold', 0, 0, 110, .55 + .25 * Math.sin(t * 12));
  rr(-83, -25, 166, 50, 25); g.fillStyle = '#fff'; g.fill(); g.lineWidth = ready ? 3 : 1.5; g.strokeStyle = ready ? C.green : 'rgba(0,0,0,.12)'; g.stroke();
  g.save(); g.beginPath(); g.arc(-56, 0, 19, 0, Math.PI * 2); g.clip(); g.drawImage(IMG.face_homeless, -76, -20, 40, 40); g.restore();
  text('El Fisura', -30, -8, 13, C.ink, { align: 'left' });
  g.drawImage(IMG.coin, -30, 4, 15, 15); text('25', -11, 12, 14, C.ink, { align: 'left' });
  g.restore();
}
function finger(t) {
  // posición: toques sobre el Fisura → pill de contratar → arrastre
  let x = 222, y = 680, press = 0, a = seg(t, 3.0, 3.2);
  for (const tt of TAPS) { const d = t - tt; if (d >= 0 && d < .1) press = 1 - d / .1; }
  if (t > 7.4 && t < T_HIRE + .3) { const p = E.cInOut(seg(t, 7.4, T_HIRE)); x = lerp(222, 95, p); y = lerp(680, 777, p); if (t >= T_HIRE) press = 1 - seg(t, T_HIRE, T_HIRE + .15); }
  if (t >= T_HIRE + .3 && t < T_DRAG0) { const p = E.cInOut(seg(t, T_HIRE + .3, T_DRAG0)); x = lerp(95, 330, p); y = lerp(777, 660, p); }
  if (t >= T_DRAG0) { const p = E.cInOut(seg(t, T_DRAG0, T_DRAG1)); x = lerp(330, 222, p); y = lerp(660, 680, p) - Math.sin(p * Math.PI) * 60; press = .6; a = 1 - seg(t, T_DRAG1 + .05, T_DRAG1 + .25); }
  if (a <= 0) return;
  g.save(); g.globalAlpha = a;
  g.beginPath(); g.arc(x, y, 20 * (1 - press * .18), 0, Math.PI * 2); g.fillStyle = 'rgba(255,255,255,.6)'; g.fill(); g.lineWidth = 3.5; g.strokeStyle = C.ink; g.stroke();
  g.restore();
}
function game(t) {
  const im = IMG.bg_alley, s = SH / im.height * 1.55;
  g.drawImage(im, SW / 2 - im.width * s / 2 - 40, SH / 2 - im.height * s / 2 - 40, im.width * s, im.height * s);
  // personajes
  let sq = 0; for (const tt of TAPS) { const d = t - tt; if (d >= 0 && d < .14) sq = Math.sin(d / .14 * Math.PI) * .09; }
  if (t < T_NEW) drawChar('homeless', 215, 742, 140, { sy: 1 - sq, sx: 1 + sq * .6 });
  if (t >= T_HIRE && t < T_DRAG0) { const p = E.expoIn(seg(t, T_HIRE + .05, T_HIRE + .3)); drawChar('homeless', 330, lerp(420, 722, p), 140, { flip: true, alpha: cl(p * 4) }); }
  if (t >= T_DRAG0 && t < T_NEW) { const p = E.cInOut(seg(t, T_DRAG0, T_DRAG1)); drawChar('homeless', lerp(330, 222, p), lerp(722, 742, p) - Math.sin(p * Math.PI) * 60, 150, { rot: Math.sin(t * 18) * .04, shadow: false }); }
  if (t >= T_NEW) drawChar('trapito', 215, 742, 146 * E.elasticOut(seg(t, 10.4, 10.9)), {});
  // toques y monedas volando al contador
  for (const tt of TAPS) {
    const d = t - tt;
    if (d >= 0 && d < .4) drawImg(IMG.fx_tap, 222, 680, 40 + 100 * E.expoOut(seg(d, 0, .35)), { alpha: 1 - seg(d, .1, .4) });
    if (d >= 0 && d < .4) {
      const p = E.cInOut(seg(d, 0, .35));
      drawImg(IMG.coin, lerp(230, 200, p), lerp(640, 82, p) - Math.sin(p * Math.PI) * 40, lerp(26, 20, p), { alpha: 1 - seg(p, .9, 1) });
    }
  }
  if (t > 10.9) { const ph = ((t - 10.9) % 1); drawImg(IMG.coin, 232, 580 - ph * 50, 20, { alpha: 1 - ph }); }
  const ui = 1 - win(t, T_NEW - .05, 10.7, .2, .3);
  g.save(); g.globalAlpha = ui; hud(t); quickHire(t); bottomBar(); g.restore();
  // ¡NUEVO! (la celebración esconde la UI)
  if (t > T_NEW && t < 10.7) {
    const a = win(t, T_NEW, 10.7, .15, .3);
    g.fillStyle = `rgba(20,12,4,${.55 * a})`; g.fillRect(0, 0, SW, SH);
    rays(SW / 2, 430, 16, t * .5, 420, 'rgba(255,217,61,1)', .35 * a);
    glow('gold', SW / 2, 430, 220, .6 * a);
    const pop = E.elasticOut(seg(t, T_NEW + .05, T_NEW + .7)), back = E.cInOut(seg(t, 10.3, 10.7));
    drawChar('trapito', lerp(SW / 2, 215, back), lerp(560, 742, back), lerp(300, 146, back) * pop, { shadow: false, white: 1 - seg(t, T_NEW, T_NEW + .3) });
    const rp = E.backOut(seg(t, T_NEW + .2, T_NEW + .5), 2) * (1 - back);
    if (rp > 0) {
      g.save(); g.translate(SW / 2, 230); g.scale(rp * .9, rp * .9);
      const w = 300, h = w * IMG.ribbon.height / IMG.ribbon.width; g.drawImage(IMG.ribbon, -w / 2, -h / 2, w, h);
      text('¡NUEVO!', 0, -4, 38, C.cream, { stroke: 7 }); g.restore();
      g.save(); g.globalAlpha = rp; pill(SW / 2, 610, 200, 44, { fill: C.cream }); text('El Trapito', SW / 2, 614, 22, C.ink); g.restore();
    }
  }
  finger(t);
}
function phone(t) {
  const inP = E.expoOut(seg(t, T_PHONE, T_PHONE + .7));
  const out = E.cInOut(seg(t, T_OUT, T_OUT + .7));
  const k = K * lerp(1, .55, out);
  const y = lerp(2600, 1080, inP) - out * 150;
  g.save(); g.globalAlpha = 1 - seg(t, T_OUT + .3, T_OUT + .8);
  g.translate(540, y); g.scale(k, k);
  rr(-SW / 2 - 12, -SH / 2 - 12 + 10, SW + 24, SH + 24, 62); g.fillStyle = 'rgba(0,0,0,.45)'; g.fill();
  rr(-SW / 2 - 12, -SH / 2 - 12, SW + 24, SH + 24, 62); g.fillStyle = '#121212'; g.fill();
  g.save(); rr(-SW / 2, -SH / 2, SW, SH, 52); g.clip(); g.translate(-SW / 2, -SH / 2);
  game(t);
  rr(SW / 2 - 62, 12, 124, 36, 18); g.fillStyle = '#000'; g.fill();
  g.restore(); g.restore();
}

// ── cronómetro ──
function clockTime(t) { return cl(t - 3.2, 0, T_NEW - 3.2 + .0001); } // corre del primer toque al ¡NUEVO!
function stopwatch(t) {
  const big = 1 - E.cInOut(seg(t, T_PHONE - .2, T_PHONE + .5));
  const x = 540, y = lerp(300, 960, big), s = lerp(.62, 1.6, big);
  const secs = clockTime(t);
  const stopped = t >= T_NEW;
  g.save(); g.translate(x, y); g.scale(s, s);
  rr(-230, -85, 460, 170, 60); g.fillStyle = 'rgba(0,0,0,.4)'; g.fill();
  rr(-230, -95, 460, 170, 60); g.fillStyle = stopped ? '#1F9A4B' : '#16121E'; g.fill(); g.lineWidth = 9; g.strokeStyle = stopped ? '#B8FFCB' : C.yellow; g.stroke();
  // corona del cronómetro
  rr(-26, -130, 52, 34, 8); g.fillStyle = stopped ? '#B8FFCB' : C.yellow; g.fill(); g.lineWidth = 6; g.strokeStyle = C.ink; g.stroke();
  const mm = Math.floor(secs / 60), ss = Math.floor(secs % 60), cs = Math.floor((secs * 10) % 10);
  text(`${String(mm).padStart(2, '0')}:${String(ss).padStart(2, '0')}.${cs}`, 0, -8, 96, '#fff', { font: FONT_T, weight: 800 });
  g.restore();
  if (stopped && t < T_OUT + .8) {
    const p = E.backOut(seg(t, T_NEW + .1, T_NEW + .4), 2.2);
    g.save(); g.translate(x + 270 * s / .62 * .62, y); g.scale(p, p);
    g.beginPath(); g.arc(0, 0, 44, 0, Math.PI * 2); g.fillStyle = '#2FB560'; g.fill(); g.lineWidth = 6; g.strokeStyle = C.ink; g.stroke();
    g.lineWidth = 10; g.strokeStyle = '#fff'; g.lineCap = 'round'; g.beginPath(); g.moveTo(-18, 2); g.lineTo(-5, 15); g.lineTo(20, -14); g.stroke();
    g.restore();
  }
}

// ── los que faltan ──
function grid(t) {
  // un personaje por nivel: los 37
  const seen = new Set(), ids = [];
  for (const [id, , n] of TIERS) if (!seen.has(n)) { seen.add(n); ids.push(id); }
  const cols = 8, cw = 126, chh = 168, x0 = 540 - (cols - 1) * cw / 2, y0 = 610;
  const d = t - T_GRID;
  ids.forEach((id, k) => {
    const c = k % cols, r = Math.floor(k / cols);
    const pin = E.backOut(seg(d, .05 + k * .022, .35 + k * .022), 1.8);
    if (pin <= 0) return;
    const x = x0 + c * cw, y = y0 + r * chh;
    const known = k < 2;
    if (k === ids.length - 1) glow('gold', x, y, 140 * pin, .6 + .25 * Math.sin(t * 5));
    g.save(); g.translate(x, y); g.scale(pin, pin);
    rr(-58, -76, 116, 152, 18); g.fillStyle = known ? C.parch : '#1C1626'; g.fill(); g.lineWidth = 5; g.strokeStyle = known ? C.brown : k === ids.length - 1 ? C.yellow : '#3A3050'; g.stroke();
    g.restore();
    if (known) drawChar(id, x, y + 68 * pin, 136 * pin, { shadow: false });
    else { sil(id, x, y + 68 * pin, 136 * pin, '#07050C', .95); if (pin > .5) text('?', x, y - 5, 50, 'rgba(255,248,231,.8)', { font: FONT_T, weight: 800 }); }
  });
  title('Y TE QUEDAN', 540, 320, 90, { tin: d - .2, anim: 'rise', dur: .4, stagger: .03 });
  title('35 POR DESCUBRIR.', 540, 430, 100, { tin: d - .45, anim: 'rise', dur: .4, stagger: .025, gold: true });
}

// ── placa de conversión ──
function card(t) {
  const d = t - T_CARD;
  sunburst(540, 700, 26, t * .25, C.orange, '#FF8A4C');
  glow('warm', 540, 700, 1000, .55);
  const gr = g.createRadialGradient(540, 900, 300, 540, 960, 1400);
  gr.addColorStop(0, 'rgba(0,0,0,0)'); gr.addColorStop(1, 'rgba(40,10,0,.6)');
  g.fillStyle = gr; g.fillRect(0, 0, W, H);
  const lw = 190, lh = lw * IMG.ader.height / IMG.ader.width;
  g.drawImage(IMG.ader, 540 - lw / 2, 205, lw, lh);
  const ip = E.backOut(seg(d, 0, .4), 1.8), is = 230 * ip;
  if (is > 1) { g.save(); g.translate(540, 480); rr(-is / 2, -is / 2, is, is, is * .22); g.save(); g.clip(); g.drawImage(IMG.app_icon, -is / 2, -is / 2, is, is); g.restore(); g.restore(); }
  title('TU PRÓXIMO MINUTO', 540, 690, 92, { tin: d - .1, anim: 'slam', dur: .25, stagger: .02, maxW: 1000 });
  title('EMPIEZA ACÁ 👇', 540, 810, 120, { tin: d - .3, anim: 'slam', dur: .25, stagger: .03, gold: true });
  [['GRATIS', .6], ['SIN CUENTA NI REGISTRO', .8], ['JUGÁ OFFLINE', 1.0]].forEach(([s, t0], i) => {
    const y = 960 + i * 92, p = E.backOut(seg(d, t0, t0 + .3), 2.2);
    if (p > 0) { g.save(); g.translate(250, y); g.scale(p, p); g.beginPath(); g.arc(0, 0, 38, 0, Math.PI * 2); g.fillStyle = '#2FB560'; g.fill(); g.lineWidth = 7; g.strokeStyle = C.ink; g.stroke(); g.lineWidth = 11; g.strokeStyle = '#fff'; g.lineCap = 'round'; g.beginPath(); g.moveTo(-16, 1); g.lineTo(-4, 13); g.lineTo(18, -12); g.stroke(); g.restore(); }
    title(s, 620, y + 4, 64, { tin: d - t0 - .05, anim: 'rise', dur: .3, stagger: .015, maxW: 600 });
  });
  const bp = E.backOut(seg(d, 1.3, 1.65), 2), pulse = d > 1.9 ? 1 + Math.max(0, Math.sin((d - 1.9) * Math.PI * 2)) * .04 : 1;
  appStoreBadge(540, 1330, 420, bp * pulse, cl(bp));
  const ap = E.cOut(seg(d, 1.7, 2.0));
  if (ap > 0) {
    const bounce = Math.abs(Math.sin((d - 1.7) * Math.PI * 2.2)) * 26;
    g.save(); g.globalAlpha = ap; g.translate(540, 1500 + bounce);
    g.beginPath(); g.moveTo(-50, -40); g.lineTo(50, -40); g.lineTo(50, 10); g.lineTo(90, 10); g.lineTo(0, 90); g.lineTo(-90, 10); g.lineTo(-50, 10); g.closePath();
    g.fillStyle = C.cream; g.fill(); g.lineWidth = 9; g.strokeStyle = C.ink; g.lineJoin = 'round'; g.stroke(); g.restore();
  }
  burst(t, { t0: T_CARD + .2, x: 540, y: 750, n: 60, seed: 9000, kind: 'confetti', spd: [800, 2000], grav: 1400, life: [1.4, 2], size: [22, 34], drag: 1.6 });
}

const BLUR = [];
function drawScene(t) {
  g.setTransform(SCALE, 0, 0, SCALE, 0, 0);
  g.globalAlpha = 1; g.globalCompositeOperation = 'source-over';
  if (t >= T_CARD) { card(t); flash(1 - seg(t, T_CARD, T_CARD + .2), '#FFF3D0'); return; }
  const gr = g.createRadialGradient(540, 900, 100, 540, 900, 1400);
  gr.addColorStop(0, '#2E1F14'); gr.addColorStop(1, '#0E0906');
  g.fillStyle = gr; g.fillRect(0, 0, W, H);
  g.save(); g.globalAlpha = .12; sunburst(540, 900, 28, t * .08, 'rgba(0,0,0,0)', C.orange, 2400); g.restore();
  glow('warm', 540, 1000, 900, .4);
  if (t < T_GRID + .2) { phone(t); stopwatch(t); }
  if (t < T_PHONE) {
    title('¿CUÁNTO TARDÁS EN', 540, 420, 84, { tin: t - .15, anim: 'rise', dur: .45, stagger: .02, tout: t > T_PHONE - .3 ? t - (T_PHONE - .3) : null });
    title('DESCUBRIR TU PRIMER', 540, 530, 84, { tin: t - .35, anim: 'rise', dur: .45, stagger: .02, tout: t > T_PHONE - .3 ? t - (T_PHONE - .3) : null });
    title('PERSONAJE?', 540, 650, 110, { tin: t - .55, anim: 'rise', dur: .45, stagger: .03, gold: true, tout: t > T_PHONE - .3 ? t - (T_PHONE - .3) : null });
    title('Te cronometramos.', 540, 1320, 60, { tin: t - 1.2, anim: 'rise', dur: .4, stagger: .015, tout: t > T_PHONE - .3 ? t - (T_PHONE - .3) : null });
  }
  // leyendas de la partida (sobre la pared, fuera de la UI)
  const cap = (s, t0, t1, gold) => title(s, 540, 1720, 76, { tin: t - t0, tout: t > t1 ? t - t1 : null, anim: 'rise', dur: .35, stagger: .02, gold, maxW: 1000 });
  if (t > 3.2 && t < 12.6) {
    g.save(); g.globalAlpha = win(t, 3.2, 12.6, .3, .3); rr(80, 1650, 920, 140, 44); g.fillStyle = 'rgba(12,10,20,.8)'; g.fill(); g.restore();
    cap('TOCÁ: 1 MONEDA POR TOQUE', 3.3, 7.3);
    cap('CONTRATÁ OTRO (25)', 7.45, 8.2);
    cap('ARRASTRALO Y FUSIONÁ', 8.25, 9.0);
    cap('¡MENOS DE UN MINUTO!', 9.1, 12.4, true);
  }
  if (t >= T_GRID) grid(t);
}
function sceneSetup() { impact(T_NEW, 8); }
window.DURATION = DURATION;
boot();
