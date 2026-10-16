'use strict';
// Placa BOFU (4,5 s): cierre de conversión para los cortes cortos.
// Elimina objeciones (gratis, sin cuenta, offline — store-metadata.md),
// suma urgencia con el texto promocional real del App Store y señala el
// botón de instalar de la plataforma.

const DURATION = 4.5;

function assetList() {
  return commonAssets({});
}

function check(x, y, s) {
  if (s <= 0) return;
  g.save(); g.translate(x, y); g.scale(s, s);
  g.beginPath(); g.arc(0, 0, 40, 0, Math.PI * 2); g.fillStyle = '#2FB560'; g.fill(); g.lineWidth = 7; g.strokeStyle = C.ink; g.stroke();
  g.lineWidth = 11; g.strokeStyle = '#fff'; g.lineCap = 'round'; g.lineJoin = 'round';
  g.beginPath(); g.moveTo(-17, 1); g.lineTo(-5, 14); g.lineTo(19, -13); g.stroke();
  g.restore();
}

function drawScene(t) {
  g.setTransform(SCALE, 0, 0, SCALE, 0, 0);
  g.globalAlpha = 1; g.globalCompositeOperation = 'source-over';
  sunburst(540, 700, 26, t * .25, C.orange, '#FF8A4C');
  glow('warm', 540, 700, 1000, .55);
  const gr = g.createRadialGradient(540, 900, 300, 540, 960, 1400);
  gr.addColorStop(0, 'rgba(0,0,0,0)'); gr.addColorStop(1, 'rgba(40,10,0,.6)');
  g.fillStyle = gr; g.fillRect(0, 0, W, H);
  const sh = shakeAt(t);
  g.save(); g.translate(sh.x, sh.y);
  // estudio arriba, chiquito
  const lw = 190, lh = lw * IMG.ader.height / IMG.ader.width;
  g.save(); g.globalAlpha = E.cOut(seg(t, .1, .4)); g.drawImage(IMG.ader, 540 - lw / 2, 205, lw, lh); g.restore();
  // ícono de la app
  const ip = E.backOut(seg(t, 0, .4), 1.8), is = 250 * ip;
  if (is > 1) {
    g.save(); g.translate(540, 490 + Math.sin(t * 3) * 5);
    rr(-is / 2, -is / 2 + 12, is, is, is * .22); g.fillStyle = 'rgba(0,0,0,.4)'; g.fill();
    rr(-is / 2, -is / 2, is, is, is * .22); g.save(); g.clip(); g.drawImage(IMG.app_icon, -is / 2, -is / 2, is, is); g.restore();
    g.restore();
  }
  title(tr('DESCARGALO', 'DOWNLOAD IT'), 540, 700, 112, { tin: t - .15, anim: 'slam', dur: .25, stagger: .02 });
  title(tr('GRATIS', 'FREE'), 540, 820, 150, { tin: t - .3, anim: 'slam', dur: .25, stagger: .04, gold: true });
  // objeciones fuera
  [[tr('SIN CUENTA NI REGISTRO', 'NO ACCOUNT NEEDED'), .7], [tr('JUGÁ OFFLINE', 'PLAYS OFFLINE'), .95], [tr('37 NIVELES POR DESCUBRIR', '37 LEVELS TO DISCOVER'), 1.2]].forEach(([s, t0], i) => {
    const y = 962 + i * 92;
    const p = E.backOut(seg(t, t0, t0 + .3), 2.2);
    check(250, y, p);
    title(s, 620, y + 4, 64, { tin: t - t0 - .05, anim: 'rise', dur: .3, stagger: .015, maxW: 600 });
  });
  // urgencia: el texto promocional real del App Store
  const rp = E.backOut(seg(t, 1.6, 1.95), 1.8);
  if (rp > 0) {
    g.save(); g.translate(540, 1318); g.rotate(-.025); g.scale(rp, rp);
    rr(-470, -78, 940, 156, 34); g.fillStyle = 'rgba(0,0,0,.35)'; g.fill();
    rr(-470, -88, 940, 156, 34); g.fillStyle = C.yellow; g.fill(); g.lineWidth = 8; g.strokeStyle = C.ink; g.stroke();
    text(tr('¡Llegó el Aguinaldo! Entrá a cobrarlo', 'Bonus paycheck day! Cash it in'), 0, -38, 44, C.ink, { font: FONT_T, weight: 800, maxW: 880 });
    text(tr('antes de que se lo lleve la inflación.', 'before inflation eats it.'), 0, 18, 44, C.ink, { font: FONT_T, weight: 800, maxW: 880 });
    g.restore();
  }
  const bp = E.backOut(seg(t, 2.0, 2.35), 2);
  const pulse = t > 2.6 ? 1 + Math.max(0, Math.sin((t - 2.6) * Math.PI * 2)) * .04 : 1;
  appStoreBadge(540, 1478, 400, bp * pulse, cl(bp));
  // flecha al botón de instalar
  const ap = E.cOut(seg(t, 2.4, 2.7));
  if (ap > 0) {
    const bounce = Math.abs(Math.sin((t - 2.4) * Math.PI * 2.2)) * 26;
    g.save(); g.globalAlpha = ap; g.translate(540, 1620 + bounce);
    g.beginPath(); g.moveTo(-50, -40); g.lineTo(50, -40); g.lineTo(50, 10); g.lineTo(90, 10); g.lineTo(0, 90); g.lineTo(-90, 10); g.lineTo(-50, 10); g.closePath();
    g.fillStyle = C.cream; g.fill(); g.lineWidth = 9; g.strokeStyle = C.ink; g.lineJoin = 'round'; g.stroke();
    g.restore();
  }
  burst(t, { t0: .3, x: 540, y: 750, n: 60, seed: 6000, kind: 'confetti', spd: [800, 2000], grav: 1400, life: [1.4, 2], size: [22, 34], drag: 1.6 });
  burst(t, { t0: .3, x: 540, y: 750, n: 22, seed: 6001, kind: 'coin', spd: [700, 1800], grav: 2400, life: [1, 1.5], size: [60, 100], drag: 1 });
  g.restore();
  flash(1 - seg(t, 0, .18), '#FFF3D0');
}

const BLUR = [];
function sceneSetup() { impact(.3, 18); }
window.DURATION = DURATION;
boot();
