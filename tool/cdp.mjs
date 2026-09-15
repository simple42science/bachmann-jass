/**
 * Minimaler Treiber fuer das Chrome DevTools Protocol (aus der Web-App uebernommen).
 *
 * Braucht keine Abhaengigkeiten: Node bringt seit Version 22 einen WebSocket-Client mit.
 * Edge (oder Chrome) wird headless gestartet, danach laesst sich die Seite bedienen,
 * auslesen und fotografieren.
 */

import { spawn } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const BROWSER_CANDIDATES = [
  'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe',
  'C:\\Program Files\\Microsoft\\Edge\\Application\\msedge.exe',
  'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
  'C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe',
  '/usr/bin/google-chrome',
  '/usr/bin/chromium',
];

export function findBrowser() {
  return BROWSER_CANDIDATES.find((candidate) => fs.existsSync(candidate)) || null;
}

function waitFor(check, { timeout = 15000, interval = 120, label = 'Bedingung' } = {}) {
  const deadline = Date.now() + timeout;

  return new Promise((resolve, reject) => {
    const poll = async () => {
      try {
        const result = await check();
        if (result) {
          resolve(result);
          return;
        }
      } catch (error) {
        // weiterversuchen bis zum Timeout
      }
      if (Date.now() > deadline) {
        reject(new Error(`Timeout: ${label}`));
        return;
      }
      setTimeout(poll, interval);
    };
    poll();
  });
}

async function findFreePort() {
  const net = await import('node:net');
  return new Promise((resolve, reject) => {
    const server = net.createServer();
    server.on('error', reject);
    server.listen(0, '127.0.0.1', () => {
      const { port } = server.address();
      server.close(() => resolve(port));
    });
  });
}

export async function launchBrowser(startUrl) {
  const executable = findBrowser();
  if (!executable) {
    throw new Error('Kein Chromium-Browser gefunden (Edge oder Chrome).');
  }

  // Edge beendet sich bei --remote-debugging-port=0 wortlos, darum ein fixer freier Port.
  const port = await findFreePort();
  const profileDir = fs.mkdtempSync(path.join(os.tmpdir(), 'jass-cdp-'));
  const child = spawn(executable, [
    '--headless=new',
    '--disable-gpu',
    '--no-first-run',
    '--no-default-browser-check',
    '--disable-extensions',
    `--remote-debugging-port=${port}`,
    `--user-data-dir=${profileDir}`,
    '--window-size=1280,900',
    startUrl,
  ], { stdio: ['ignore', 'pipe', 'pipe'] });

  let stderr = '';
  child.stderr.on('data', (chunk) => {
    stderr += chunk.toString();
  });

  const httpBase = `http://127.0.0.1:${port}`;
  const target = await waitFor(async () => {
    const response = await fetch(`${httpBase}/json`);
    const targets = await response.json();
    return targets.find((entry) => entry.type === 'page' && entry.webSocketDebuggerUrl) || null;
  }, { label: `DevTools auf Port ${port}${stderr ? ` (${stderr.slice(0, 200)})` : ''}` });

  const page = await connectToPage(target.webSocketDebuggerUrl);

  page.close = async () => {
    try {
      page.socket.close();
    } catch (error) {
      // egal
    }
    child.kill();
    await new Promise((resolve) => setTimeout(resolve, 400));
    try {
      // Windows gibt das Profilverzeichnis manchmal verzoegert frei.
      fs.rmSync(profileDir, { recursive: true, force: true, maxRetries: 5, retryDelay: 200 });
    } catch (error) {
      // Ein liegengebliebenes Temp-Profil ist kein Testfehler.
    }
  };

  return page;
}

async function connectToPage(webSocketDebuggerUrl) {
  const socket = new WebSocket(webSocketDebuggerUrl);
  const pending = new Map();
  const events = [];
  let nextId = 1;

  socket.addEventListener('message', (message) => {
    const payload = JSON.parse(message.data);
    if (payload.id && pending.has(payload.id)) {
      const { resolve, reject } = pending.get(payload.id);
      pending.delete(payload.id);
      if (payload.error) {
        reject(new Error(payload.error.message));
      } else {
        resolve(payload.result);
      }
      return;
    }
    events.push(payload);
  });

  await new Promise((resolve, reject) => {
    socket.addEventListener('open', resolve, { once: true });
    socket.addEventListener('error', () => reject(new Error('WebSocket-Verbindung fehlgeschlagen')), { once: true });
  });

  function send(method, params = {}) {
    const id = nextId;
    nextId += 1;
    socket.send(JSON.stringify({ id, method, params }));
    return new Promise((resolve, reject) => {
      pending.set(id, { resolve, reject });
      setTimeout(() => {
        if (pending.has(id)) {
          pending.delete(id);
          reject(new Error(`Timeout bei ${method}`));
        }
      }, 20000);
    });
  }

  const page = {
    socket,
    send,
    events,
    consoleErrors: [],
  };

  await send('Page.enable');
  await send('Runtime.enable');
  await send('Log.enable');

  socket.addEventListener('message', (message) => {
    const payload = JSON.parse(message.data);
    if (payload.method === 'Runtime.exceptionThrown') {
      const details = payload.params.exceptionDetails;
      page.consoleErrors.push(details.exception?.description || details.text);
    }
    if (payload.method === 'Log.entryAdded' && payload.params.entry.level === 'error') {
      page.consoleErrors.push(payload.params.entry.text);
    }
  });

  page.goto = async (url) => {
    const loaded = new Promise((resolve) => {
      const handler = (message) => {
        if (JSON.parse(message.data).method === 'Page.loadEventFired') {
          socket.removeEventListener('message', handler);
          resolve();
        }
      };
      socket.addEventListener('message', handler);
    });
    await send('Page.navigate', { url });
    await loaded;
    await new Promise((resolve) => setTimeout(resolve, 250));
  };

  page.evaluate = async (expression) => {
    const result = await send('Runtime.evaluate', {
      expression: `(() => { ${expression} })()`,
      returnByValue: true,
      awaitPromise: true,
    });
    if (result.exceptionDetails) {
      throw new Error(result.exceptionDetails.exception?.description || result.exceptionDetails.text);
    }
    return result.result.value;
  };

  page.click = (selector) => page.evaluate(`
    const element = document.querySelector(${JSON.stringify(selector)});
    if (!element) { throw new Error('Element nicht gefunden: ' + ${JSON.stringify(selector)}); }
    element.click();
    return true;
  `);

  page.text = (selector) => page.evaluate(`
    const element = document.querySelector(${JSON.stringify(selector)});
    return element ? element.textContent.trim() : null;
  `);

  page.visible = (selector) => page.evaluate(`
    const element = document.querySelector(${JSON.stringify(selector)});
    if (!element) { return false; }
    if (element.classList.contains('hidden')) { return false; }
    const box = element.getBoundingClientRect();
    return box.width > 0 && box.height > 0;
  `);

  page.waitFor = (expression, options = {}) =>
    waitFor(() => page.evaluate(`return Boolean(${expression});`), options);

  page.setViewport = async (width, height, mobile = false) => {
    await send('Emulation.setDeviceMetricsOverride', {
      width,
      height,
      deviceScaleFactor: 1,
      mobile,
    });
    await new Promise((resolve) => setTimeout(resolve, 150));
  };

  page.screenshot = async (filePath) => {
    const { data } = await send('Page.captureScreenshot', { format: 'png' });
    fs.writeFileSync(filePath, Buffer.from(data, 'base64'));
    return filePath;
  };

  return page;
}
