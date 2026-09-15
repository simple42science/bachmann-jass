/**
 * Fotografiert die Web-Version in mehreren Fenstergroessen und Spielsituationen.
 *
 * Voraussetzung: ein Web-Build mit Demo-Start,
 *   flutter build web --release --dart-define=JASS_DEMO=true
 * Danach:
 *   node tool/screenshot_web.mjs [ausgabeordner]
 *
 * Es wird ein lokaler Server fuer build/web gestartet, Edge headless
 * laedt jede Situation ueber die Demo-URL und speichert ein PNG.
 */

import fs from 'node:fs';
import http from 'node:http';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { launchBrowser } from './cdp.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const webDir = path.join(root, 'build', 'web');
const outDir = path.resolve(root, process.argv[2] ?? path.join('docs', 'screenshots'));

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript',
  '.mjs': 'text/javascript',
  '.wasm': 'application/wasm',
  '.json': 'application/json',
  '.css': 'text/css',
  '.png': 'image/png',
  '.webp': 'image/webp',
  '.svg': 'image/svg+xml',
  '.otf': 'font/otf',
  '.ttf': 'font/ttf',
  '.ico': 'image/x-icon',
};

const VIEWPORTS = [
  { name: 'handy-hoch', width: 390, height: 844, mobile: true },
  { name: 'handy-quer', width: 844, height: 390, mobile: true },
  { name: 'tablet-hoch', width: 768, height: 1024, mobile: true },
  { name: 'desktop', width: 1440, height: 800, mobile: false },
];

const SCENES = [
  { name: 'home', query: '' },
  { name: 'schieber-spielart', query: '?demo=schieber&seed=5&moves=0' },
  { name: 'schieber-stich', query: '?demo=schieber&seed=5&moves=4' },
  { name: 'bieter-gebot', query: '?demo=bieter&seed=1000&moves=0' },
  { name: 'bieter-stich', query: '?demo=bieter&seed=1000&moves=3' },
  { name: 'jasstafel', query: '?demo=schieber&seed=5&moves=40&screen=scoreboard' },
  { name: 'regeln', query: '?demo=schieber&seed=5&screen=rules' },
];

function serve() {
  const server = http.createServer((request, response) => {
    const url = new URL(request.url, 'http://localhost');
    let file = path.join(webDir, decodeURIComponent(url.pathname));
    if (!fs.existsSync(file) || fs.statSync(file).isDirectory()) {
      file = path.join(webDir, 'index.html');
    }
    response.writeHead(200, { 'Content-Type': MIME[path.extname(file)] ?? 'application/octet-stream' });
    fs.createReadStream(file).pipe(response);
  });
  return new Promise((resolve) => {
    server.listen(0, '127.0.0.1', () => resolve(server));
  });
}

if (!fs.existsSync(path.join(webDir, 'index.html'))) {
  throw new Error('build/web fehlt. Zuerst: flutter build web --release --dart-define=JASS_DEMO=true');
}

const server = await serve();
const base = `http://127.0.0.1:${server.address().port}`;
fs.mkdirSync(outDir, { recursive: true });

const page = await launchBrowser(`${base}/`);
try {
  for (const viewport of VIEWPORTS) {
    await page.setViewport(viewport.width, viewport.height, viewport.mobile);
    for (const scene of SCENES) {
      await page.goto(`${base}/${scene.query}`);
      // Flutter zeichnet erst nach dem Laden von CanvasKit und den Kartenbildern.
      await new Promise((resolve) => setTimeout(resolve, 4500));
      const file = path.join(outDir, `${viewport.name}_${scene.name}.png`);
      await page.screenshot(file);
      console.log(`${path.relative(root, file)}`);
    }
  }
  if (page.consoleErrors.length > 0) {
    console.log('\nFehler in der Browserkonsole:');
    for (const error of page.consoleErrors) {
      console.log(`  ${error.split('\n')[0]}`);
    }
  }
} finally {
  await page.close();
  server.close();
}
