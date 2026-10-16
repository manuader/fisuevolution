'use strict';
// Reel v7 · TOFU — «Pausá y descubrí qué fisura sos» (22 s).
// Ruleta de arquetipos argentinos: cada carta queda quieta 0,35 s para que al
// pausar se lea entera. Giro final: la carta que no sale en la ruleta (Dios).

const DURATION = 22;
const REEL0 = 3.0, REEL1 = 13.0, STEP = .45, HOLD = .35;

const CARDS_ES = [
  ['homeless', null, 'EL FISURA', 'Tenés un cartón y fe.', '#8B6B4A'],
  ['trapito', 'naranjita', 'EL TRAPITO', 'Cuidás autos ajenos como si fueran tuyos.', C.orange],
  ['repartidor', null, 'EL REPARTIDOR', 'Tu vida es un "está llegando".', '#E3342F'],
  ['repartidor|chofer_app', null, 'SIX SEVEN', 'Nivel 6… nivel 7… 🤷', C.pink],
  ['chofer_app', 'taxi_clasico', 'EL TAXISTA', 'Siempre por el camino más largo.', '#F2B705'],
  ['oficinista', 'home_office', 'EL OFICINISTA', 'Cámara apagada desde 2020.', '#6C7A89'],
  ['junior_programmer', 'hacker', 'EL PROGRAMADOR', 'En mi máquina anda.', '#2FB560'],
  ['junior_lawyer', null, 'EL ABOGADO', 'Depende.', '#3D3D6B'],
  ['emprendedor', null, 'EL EMPRENDEDOR', 'Vendés un curso para vender cursos.', C.blue],
  ['ceo', null, 'EL CEO', 'Reunión que pudo ser un mail.', '#2C2C2C'],
  ['millonario', 'yate', 'EL DEL YATE', 'Tu yate es una foto.', '#1E5AA8'],
  ['rey_ladrillo', null, 'EL REY DEL LADRILLO', 'Te aumenta el alquiler cada 3 meses.', '#B5452C'],
  ['sp_cryptobro', null, 'EL CRYPTO BRO', 'DYOR. Y te lo explica igual.', '#9B59D0'],
  ['sp_coach', null, 'EL DEBATE BRO', 'El sueldo es un límite mental. Cambiame de opinión.', '#5B6770', 'sign'],
  ['rentista_soles', 'jubilado', 'EL JUBILADO', 'Plaza, palomas y bronca.', '#7A8C5A'],
  ['homeless', 'mundialista', 'EL MUNDIALISTA', 'Todavía hablás de Qatar.', '#75AADB'],
  ['space_billionaire', null, 'EL SPACE BILLIONAIRE', 'Te querés ir del país. Del planeta.', '#12122E'],
];
// EE. UU.: los mismos personajes con arquetipos que un yanqui reconoce en un segundo.
const CARDS_EN = [
  ['homeless', null, 'THE HOBO', 'Cardboard sign. Unlimited faith.', '#8B6B4A'],
  ['trapito', 'naranjita', 'THE FAKE VALET', 'Charges you $20 to "watch" your car.', C.orange],
  ['repartidor', null, 'THE DELIVERY GUY', 'Your life is "driver is 2 min away."', '#E3342F'],
  ['repartidor|chofer_app', null, 'SIX SEVEN', 'Level 6… level 7… 🤷', C.pink],
  ['chofer_app', 'taxi_clasico', 'THE CAB DRIVER', 'Always takes the scenic route.', '#F2B705'],
  ['oficinista', 'home_office', 'THE OFFICE DRONE', 'Camera off since 2020.', '#6C7A89'],
  ['junior_programmer', null, 'THE DEV', 'Works on my machine.', '#2FB560'],
  ['junior_programmer', 'hacker', 'THE STREAMER', 'Chat, is this real? 💀', '#6441A5'],
  ['emprendedor', null, 'THE HUSTLE GURU', 'Sells a course on selling courses.', C.blue],
  ['ceo', null, 'THE CEO', 'This meeting could have been an email.', '#2C2C2C'],
  ['sp_influencer', null, 'THE INFLUENCER', 'Use code HOBO for 2% off. Link in bio.', '#E1306C'],
  ['millonario', 'yate', 'THE YACHT GUY', 'The yacht is a rental. For the pic.', '#1E5AA8'],
  ['rey_ladrillo', null, 'THE LANDLORD', 'Raised your rent. Again.', '#B5452C'],
  ['sp_cryptobro', null, 'THE CRYPTO BRO', 'DYOR. Then explains it anyway.', '#9B59D0'],
  ['sp_coach', null, 'THE DEBATE BRO', 'Your salary is a mindset. Change my mind.', '#5B6770', 'sign'],
  ['rentista_soles', 'jubilado', 'THE RETIREE', 'Park bench, pigeons, strong opinions.', '#7A8C5A'],
  ['homeless', 'mundialista', 'THE WORLD CUP GUY', 'Still not over the World Cup.', '#75AADB'],
  ['space_billionaire', null, 'THE SPACE BILLIONAIRE', "Can't fix Earth. Buying a new one.", '#12122E'],
];
const CARDS = EN ? CARDS_EN : CARDS_ES;
const key = c => c[1] ? `${c[0]}_idle__${c[1]}` : c[0];

function assetList() {
  const L = commonAssets({});
  for (const c of CARDS) {
    if (c[0].includes('|')) { for (const id of c[0].split('|')) L[id] = charPath(id); continue; }
    if (c[0].startsWith('sp_')) L[c[0]] = RES + 'specials.atlas/' + c[0] + '@3x.png';
    else L[key(c)] = c[1] ? skinPath(c[0], c[1]) : charPath(c[0]);
  }
  L.god = charPath('god');
  return L;
}

function bgWarm(t, a = 1) {
  const gr = g.createRadialGradient(540, 900, 100, 540, 900, 1400);
  gr.addColorStop(0, '#3A2414'); gr.addColorStop(1, '#120906');
  g.fillStyle = gr; g.fillRect(0, 0, W, H);
  g.save(); g.globalAlpha = .16 * a; sunburst(540, 960, 28, t * .12, 'rgba(0,0,0,0)', C.orange, 2400); g.restore();
  glow('warm', 540, 960, 900, .45);
  burst(t, { t0: 0, x: 540, y: 2000, n: 50, seed: 7000, kind: 'dust', spd: [40, 120], ang: [-Math.PI * .62, -Math.PI * .38], life: [6, 9], size: [10, 26], spread: 1200, delay: 22, alpha: .35 });
}

const CW = 740, CHh = 960;
function cardFront(c, x, y, s, a = 1) {
  if (s <= 0 || a <= 0) return;
  const [id, , name, joke, color] = c;
  g.save(); g.translate(x, y); g.scale(s, s); g.globalAlpha *= a;
  rr(-CW / 2, -CHh / 2 + 16, CW, CHh, 48); g.fillStyle = 'rgba(0,0,0,.45)'; g.fill();
  rr(-CW / 2, -CHh / 2, CW, CHh, 48); g.fillStyle = C.parch; g.fill(); g.lineWidth = 12; g.strokeStyle = C.ink; g.stroke();
  // cabecera de color
  g.save(); rr(-CW / 2, -CHh / 2, CW, CHh, 48); g.clip();
  g.fillStyle = color; g.fillRect(-CW / 2, -CHh / 2, CW, 500);
  g.save(); g.globalAlpha = .18; sunburst(0, -CHh / 2 + 260, 20, 0, 'rgba(0,0,0,0)', '#fff', 700); g.restore();
  g.restore();
  g.lineWidth = 6; g.strokeStyle = C.ink; g.beginPath(); g.moveTo(-CW / 2, -CHh / 2 + 500); g.lineTo(CW / 2, -CHh / 2 + 500); g.stroke();
  if (id.includes('|')) {
    const [a, b] = id.split('|');
    drawChar(a, -150, -CHh / 2 + 560, 470, { shadow: false });
    drawChar(b, 150, -CHh / 2 + 560, 470, { shadow: false, flip: true });
    text('6', -270, -CHh / 2 + 90, 110, C.cream, { font: FONT_T, weight: 800, stroke: 16 });
    text('7', 270, -CHh / 2 + 90, 110, C.cream, { font: FONT_T, weight: 800, stroke: 16 });
  } else drawChar(key(c), 0, -CHh / 2 + 560, 520, { shadow: false });
  if (c[5] === 'sign') {
    // el formato de meme de la mesa con el cartel, sin ninguna persona real
    g.save(); g.translate(170, -CHh / 2 + 420); g.rotate(-.06);
    rr(-150, -52, 300, 104, 12); g.fillStyle = '#fff'; g.fill(); g.lineWidth = 6; g.strokeStyle = C.ink; g.stroke();
    text(tr('CAMBIAME', 'CHANGE'), 0, -18, 38, C.ink, { font: FONT_T, weight: 800 });
    text(tr('DE OPINIÓN', 'MY MIND'), 0, 24, 38, C.ink, { font: FONT_T, weight: 800 });
    g.restore();
  }
  g.restore();
  title(name, x, y + 90 * s, 70 * s, { tin: 99, maxW: 680 * s });
  g.save(); g.globalAlpha *= a;
  g.translate(x, y); g.scale(s, s);
  wrap(joke, 0, 290, 52, 660, 62, C.ink, { weight: 900 });
  g.restore();
}
function cardBack(x, y, s, gold, t) {
  if (s <= 0) return;
  g.save(); g.translate(x, y); g.scale(s, s);
  rr(-CW / 2, -CHh / 2 + 16, CW, CHh, 48); g.fillStyle = 'rgba(0,0,0,.45)'; g.fill();
  rr(-CW / 2, -CHh / 2, CW, CHh, 48); g.fillStyle = gold ? '#C99A2E' : C.orange; g.fill(); g.lineWidth = 12; g.strokeStyle = C.ink; g.stroke();
  g.save(); rr(-CW / 2, -CHh / 2, CW, CHh, 48); g.clip();
  g.globalAlpha = .22; sunburst(0, 0, 24, t * .3, 'rgba(0,0,0,0)', '#fff', 900);
  g.restore();
  rr(-CW / 2 + 36, -CHh / 2 + 36, CW - 72, CHh - 72, 32); g.lineWidth = 6; g.strokeStyle = 'rgba(44,44,44,.6)'; g.stroke();
  g.restore();
  title('?', x, y, 300 * s, { tin: 99, gold: !gold, fill: gold ? '#FFF6C2' : undefined });
}
function pauseIcon(x, y, s, press) {
  g.save(); g.translate(x, y); g.scale(s * (1 - press * .1), s * (1 - press * .1));
  g.beginPath(); g.arc(0, 0, 70, 0, Math.PI * 2); g.fillStyle = 'rgba(255,248,231,.95)'; g.fill(); g.lineWidth = 8; g.strokeStyle = C.ink; g.stroke();
  g.fillStyle = C.ink; rr(-28, -32, 18, 64, 5); g.fill(); rr(10, -32, 18, 64, 5); g.fill();
  g.restore();
  if (press > 0) { g.save(); g.beginPath(); g.arc(x, y, 70 * s + 40 * (1 - press), 0, Math.PI * 2); g.lineWidth = 7; g.strokeStyle = `rgba(255,255,255,${press})`; g.stroke(); g.restore(); }
}

function sceneHook(t) {
  bgWarm(t);
  const shake = Math.sin(t * 30) * 5 * (t > 1.2 ? 1 : 0);
  const pin = lerp(.9, 1, E.backOut(seg(t, 0, .4), 1.6));
  cardBack(540 + shake, 1000, .9 * pin, false, t);
  title(tr('PAUSÁ EL VIDEO', 'PAUSE THE VIDEO'), 540, 320, 120, { tin: t + .6, anim: 'rise', dur: .45, stagger: .03, gold: true });
  title(tr('y descubrí qué fisura sos', 'and find out which one you are'), 540, 440, 76, { tin: t + .2, anim: 'rise', dur: .45, stagger: .015 });
  // la mano que pausa
  const press = t > 1.4 && t < 1.6 ? 1 - (t - 1.4) / .2 : t > 2.2 && t < 2.4 ? 1 - (t - 2.2) / .2 : 0;
  pauseIcon(820, 1470, E.backOut(seg(t, .1, .4), 2), press);
  // la carta se da vuelta y arranca la ruleta
  const fl = seg(t, 2.65, 3.0);
  if (fl > 0) { g.save(); g.globalAlpha = fl; g.fillStyle = 'rgba(255,248,231,.35)'; g.fillRect(0, 0, W, H); g.restore(); }
}

function reelIndex(t) { return Math.floor((t - REEL0) / STEP); }
function sceneReel(t) {
  bgWarm(t);
  const k = reelIndex(t), u = (t - REEL0) - k * STEP;
  const mv = u < HOLD ? 0 : E.cInOut((u - HOLD) / (STEP - HOLD));
  const gap = 1040;
  const slow = seg(t, REEL1 - .6, REEL1); // frena al final
  for (let j = -1; j <= 1; j++) {
    const idx = ((k + j) % CARDS.length + CARDS.length) % CARDS.length;
    const y = 980 + (j - mv) * gap;
    const s = .98 - Math.abs(j - mv) * .12;
    cardFront(CARDS[idx], 540, y, s, 1 - Math.abs(j - mv) * .55);
  }
  // viñeta arriba/abajo para que la carta central mande
  const vg = g.createLinearGradient(0, 0, 0, H);
  vg.addColorStop(0, 'rgba(18,9,6,1)'); vg.addColorStop(.2, 'rgba(18,9,6,.0)'); vg.addColorStop(.8, 'rgba(18,9,6,0)'); vg.addColorStop(1, 'rgba(18,9,6,.95)');
  g.fillStyle = vg; g.fillRect(0, 0, W, H);
  void slow;
  // recordatorio fijo arriba
  g.save();
  rr(90, 250, 900, 100, 50); g.fillStyle = 'rgba(20,14,10,.8)'; g.fill(); g.lineWidth = 5; g.strokeStyle = C.yellow; g.stroke();
  g.restore();
  pauseIcon(165, 300, .55, 0);
  text(tr('PAUSÁ Y DESCUBRÍ QUÉ FISURA SOS', 'PAUSE & FIND OUT WHICH ONE YOU ARE'), 575, 305, 44, C.cream, { font: FONT_T, weight: 800, maxW: 760 });
  for (const f0 of [6.0, 10.0]) {
    const d = t - f0;
    if (d >= 0 && d < .9) {
      const p = E.backOut(seg(d, 0, .25), 2.2) * (1 - seg(d, .7, .9));
      g.save(); g.translate(800, 470); g.rotate(.12); g.scale(p, p);
      rr(-190, -60, 380, 120, 30); g.fillStyle = C.pink; g.fill(); g.lineWidth = 8; g.strokeStyle = C.ink; g.stroke();
      g.restore();
      title(tr('¡PAUSÁ YA!', 'PAUSE NOW!'), 800, 465, 70 * p, { tin: 99, rot: .12 });
    }
  }
}

function sceneTwist(t) {
  bgWarm(t, .6);
  shade(.35);
  const d = t - 14.5;
  // la ruleta se va
  if (d < .4) { g.save(); g.globalAlpha = 1 - d / .4; cardFront(CARDS[reelIndex(REEL1) % CARDS.length], 540, 980 + d * 500, .98 - d * .3); g.restore(); }
  const pin = E.backOut(seg(t, 14.7, 15.2), 1.6);
  const flip = seg(t, 16.8, 17.15);
  const sx = Math.abs(Math.cos(flip * Math.PI));
  const lp = seg(t, 16.95, 17.6);
  rays(540, 980, 22, t * .25, 1200 * lp, 'rgba(255,220,120,1)', .3 * lp, .35);
  glow('gold', 540, 980, 600 * (pin * .4 + lp * .6), .6);
  g.save(); g.translate(540, 980); g.scale(Math.max(.02, sx), 1); g.translate(-540, -980);
  if (flip < .5) cardBack(540, 980, .98 * pin, true, t);
  else {
    // frente: silueta con halo, sin revelar
    g.save(); g.translate(540, 980); g.scale(.98, .98);
    rr(-CW / 2, -CHh / 2, CW, CHh, 48); g.fillStyle = '#1A1024'; g.fill(); g.lineWidth = 12; g.strokeStyle = C.yellow; g.stroke();
    g.save(); rr(-CW / 2, -CHh / 2, CW, CHh, 48); g.clip();
    glow('gold', 0, -60, 420, .9);
    const im = IMG.god, bb = im.bb, h = 640, w = h * bb.w / bb.h;
    g.drawImage(tint('god', '#FFE7A0'), 0, 0, bb.w, bb.h, -w / 2 - 6, 330 - h - 6, w + 12, h + 12);
    g.drawImage(tint('god', '#07040F'), 0, 0, bb.w, bb.h, -w / 2, 330 - h, w, h);
    g.restore();
    g.restore();
    title('?', 540, 890, 180, { tin: 99, gold: true });
  }
  g.restore();
  title(tr('Hay uno que no sale', "There's one that's"), 540, 300, 84, { tin: t - 14.8, anim: 'rise', dur: .45, stagger: .02, tout: t > 15.55 ? t - 15.55 : null });
  title(tr('en la ruleta…', 'NOT on the wheel…'), 540, 400, 84, { tin: t - 15.05, anim: 'rise', dur: .45, stagger: .02, tout: t > 15.55 ? t - 15.55 : null });
  title(tr('¿QUIÉN ES? 👀', 'WHO IS IT? 👀'), 540, 340, 110, { tin: t - 15.65, anim: 'slam', dur: .25, stagger: .03, tout: t > 16.15 ? t - 16.15 : null });
  title(tr('¿EL PEPE? 🤨', 'YOUR EX? 🤨'), 540, 340, 120, { tin: t - 16.25, anim: 'slam', dur: .25, stagger: .03, fill: C.pink, tout: t > 16.75 ? t - 16.75 : null });
  title(tr('NO.', 'NO.'), 540, 340, 140, { tin: t - 16.85, anim: 'slam', dur: .25, stagger: .05, gold: true, tout: t > 18.2 ? t - 18.2 : null });
  title(tr('A ESE HAY QUE LLEGAR.', 'YOU HAVE TO EARN THIS ONE.'), 540, 1520, 92, { tin: t - 17.1, anim: 'slam', dur: .3, stagger: .03, gold: true, maxW: 1000, tout: t > 18.3 ? t - 18.3 : null });
}

const BLUR = [];
function drawScene(t) {
  g.setTransform(SCALE, 0, 0, SCALE, 0, 0);
  g.globalAlpha = 1; g.globalCompositeOperation = 'source-over';
  g.fillStyle = '#000'; g.fillRect(0, 0, W, H);
  if (t < REEL0) sceneHook(t);
  else if (t < REEL1) sceneReel(t);
  else if (t < 14.5) {
    // la ruleta queda quieta: ¿ya pausaste?
    g.save(); sceneReel(REEL1 - .001 - (STEP - HOLD)); g.restore();
    shade(.55 * seg(t, REEL1, REEL1 + .3));
    title(tr('¿YA PAUSASTE?', 'DID YOU PAUSE?'), 540, 440, 130, { tin: t - REEL1 - .1, anim: 'slam', dur: .3, stagger: .04, gold: true, tout: t > 14.3 ? t - 14.3 : null });
  } else if (t < 18.5) sceneTwist(t);
  else {
    ctaEnd(t, 18.5, EN
      ? { lines: ['WHICH ONE DID YOU GET?', 'COMMENT 👇'], foot: "Tag the friend who's The Landlord" }
      : { lines: ['¿CUÁL TE TOCÓ?', 'COMENTALO 👇'], foot: 'Etiquetá a tu amigo que es el Rey del Ladrillo' });
    flash(1 - seg(t, 18.5, 18.75), '#FFF3D0');
  }
}
function sceneSetup() { impact(16.95, 12); impact(16.25, 6); }
window.DURATION = DURATION;
boot();
