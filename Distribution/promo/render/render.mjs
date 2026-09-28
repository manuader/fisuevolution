// Render determinístico del reel: sirve el repo, abre la escena en Chromium
// y captura cada frame. Los workers se reparten rangos y cada uno escribe un
// segmento H.264; al final se concatenan y se mezcla el audio.
//
//   node render.mjs preview 0.1 3.5 8.2 ...     → PNGs sueltos en out/preview/
//   node render.mjs video --scale 2 --fps 60     → out/segments + out/video_*.mp4
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { spawn } from 'node:child_process';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';

const require = createRequire(import.meta.url);
let playwright;
try { playwright = require('playwright'); } catch { playwright = require('/opt/node22/lib/node_modules/playwright'); }

const HERE = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(HERE, '../../..');
const OUT = path.join(HERE, 'out');
const FFMPEG = process.env.FFMPEG || 'ffmpeg';

const args = process.argv.slice(2);
const mode = args[0];
const opt = (name, def) => { const i = args.indexOf('--' + name); return i >= 0 ? args[i + 1] : def; };
const SCALE = parseFloat(opt('scale', '1'));
const FPS = parseFloat(opt('fps', '60'));
const WORKERS = parseInt(opt('workers', '4'), 10);
const FROM = parseFloat(opt('from', '0'));
const TO = opt('to', null);
const V = opt('v', '1');
const LANG = opt('lang', 'es');           // --lang en → versión EE. UU.
const POSTER = opt('poster', null);       // --poster 12.3 → el frame 0 muestra ese instante (miniatura)
const TAG = LANG === 'es' ? '' : '_' + LANG;

const MIME = { '.html': 'text/html', '.js': 'text/javascript', '.png': 'image/png', '.woff2': 'font/woff2', '.json': 'application/json' };
function serve() {
  return new Promise(res => {
    const srv = http.createServer((req, rsp) => {
      const p = path.join(ROOT, decodeURIComponent(req.url.split('?')[0]));
      if (!p.startsWith(ROOT) || !fs.existsSync(p) || fs.statSync(p).isDirectory()) { rsp.writeHead(404); rsp.end(); return; }
      rsp.writeHead(200, { 'Content-Type': MIME[path.extname(p)] || 'application/octet-stream' });
      fs.createReadStream(p).pipe(rsp);
    });
    srv.listen(0, '127.0.0.1', () => res(srv));
  });
}

async function openPage(browser, port) {
  const w = Math.round(1080 * SCALE), h = Math.round(1920 * SCALE);
  const page = await browser.newPage({ viewport: { width: w, height: h }, deviceScaleFactor: 1 });
  page.on('pageerror', e => console.error('pageerror', e));
  await page.goto(`http://127.0.0.1:${port}/Distribution/promo/render/index.html?scale=${SCALE}&fps=${FPS}&v=${V}&lang=${LANG}`);
  await page.waitForFunction(() => window.READY || window.ERROR, null, { timeout: 120000 });
  const err = await page.evaluate(() => window.ERROR);
  if (err) throw new Error(err);
  return page;
}

async function main() {
  const srv = await serve();
  const port = srv.address().port;
  const browser = await playwright.chromium.launch({ args: ['--disable-gpu-vsync', '--force-color-profile=srgb'] });
  try {
    if (mode === 'preview') {
      const times = args.slice(1).filter(a => !a.startsWith('--') && !isNaN(parseFloat(a)) && !['--scale', '--v', '--fps', '--lang', '--poster'].includes(args[args.indexOf(a) - 1]));
      fs.mkdirSync(path.join(OUT, 'preview'), { recursive: true });
      const page = await openPage(browser, port);
      for (const t of times) {
        await page.evaluate(tt => window.renderFrame(tt), parseFloat(t));
        const f = path.join(OUT, 'preview', `v${V}${TAG}_t${parseFloat(t).toFixed(3)}.jpg`);
        await page.screenshot({ path: f, type: 'jpeg', quality: 85 });
        console.log(f);
      }
    } else if (mode === 'video') {
      const dur = TO ? parseFloat(TO) : await (async () => { const p = await openPage(browser, port); const d = await p.evaluate(() => window.DURATION); await p.close(); return d; })();
      const first = Math.round(FROM * FPS), last = Math.round(dur * FPS); // [first, last)
      const n = last - first;
      const segDir = path.join(OUT, `segments_v${V}${TAG}_${SCALE}x_${FPS}`);
      fs.mkdirSync(segDir, { recursive: true });
      const per = Math.ceil(n / WORKERS);
      const started = Date.now();
      let done = 0;
      const jobs = [];
      for (let wi = 0; wi < WORKERS; wi++) {
        const a = first + wi * per, b = Math.min(last, a + per);
        if (a >= b) continue;
        jobs.push((async () => {
          const page = await openPage(browser, port);
          const file = path.join(segDir, `seg_${String(wi).padStart(2, '0')}.mp4`);
          const ff = spawn(FFMPEG, ['-y', '-loglevel', 'error', '-f', 'image2pipe', '-framerate', String(FPS), '-c:v', 'mjpeg', '-i', '-',
            '-c:v', 'libx264', '-preset', 'slow', '-crf', SCALE >= 2 ? '14' : '12', '-tune', 'animation',
            '-pix_fmt', 'yuv420p', '-profile:v', 'high', '-color_primaries', 'bt709', '-color_trc', 'bt709', '-colorspace', 'bt709',
            '-r', String(FPS), file], { stdio: ['pipe', 'inherit', 'inherit'] });
          const closed = new Promise((res, rej) => ff.on('close', c => c === 0 ? res() : rej(new Error('ffmpeg ' + c))));
          for (let f = a; f < b; f++) {
            await page.evaluate(tt => window.renderFrame(tt), f === 0 && POSTER ? parseFloat(POSTER) : f / FPS);
            const png = await page.screenshot({ type: 'jpeg', quality: 97 });
            if (!ff.stdin.write(png)) await new Promise(r => ff.stdin.once('drain', r));
            done++;
            if (done % 60 === 0) {
              const el = (Date.now() - started) / 1000;
              console.log(`${done}/${n} frames · ${(done / el).toFixed(2)} fps · faltan ~${Math.round((n - done) / (done / el))} s`);
            }
          }
          ff.stdin.end();
          await closed;
          await page.close();
          return file;
        })());
      }
      const files = await Promise.all(jobs);
      fs.writeFileSync(path.join(segDir, 'list.txt'), files.map(f => `file '${f}'`).join('\n'));
      console.log('segmentos listos en', segDir);
    }
  } finally {
    await browser.close();
    srv.close();
  }
}
main().catch(e => { console.error(e); process.exit(1); });
