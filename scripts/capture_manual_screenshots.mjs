/**
 * Captura pantallas públicas del manual (login / registro).
 * Requiere: build web previo + Chrome instalado.
 *
 * Uso:
 *   flutter build web --release
 *   node scripts/capture_manual_screenshots.mjs
 */
import { spawn } from 'node:child_process';
import { mkdir } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(__dirname, '..');
const outDir = path.join(root, 'docs', 'screenshots');
const webDir = path.join(root, 'build', 'web');
const port = 8765;
const baseUrl = `http://127.0.0.1:${port}/login`;
const viewport = { width: 390, height: 844 };

async function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function startServer() {
  return spawn('python3', ['-m', 'http.server', String(port), '--bind', '127.0.0.1'], {
    cwd: webDir,
    stdio: 'ignore',
  });
}

async function main() {
  await mkdir(outDir, { recursive: true });

  let playwright;
  try {
    playwright = await import('playwright');
  } catch {
    console.error('Instala Playwright: npx playwright install chromium');
    process.exit(1);
  }

  const server = startServer();
  await sleep(1200);

  const browser = await playwright.chromium.launch({
    channel: 'chrome',
    headless: true,
  });

  try {
    const page = await browser.newPage({ viewport });

    async function shot(name, action) {
      await page.goto(baseUrl, { waitUntil: 'networkidle', timeout: 120000 });
      await page.waitForTimeout(4500);
      if (action) await action();
      await page.waitForTimeout(800);
      await page.screenshot({
        path: path.join(outDir, name),
        fullPage: false,
      });
      console.log('OK', name);
    }

    await shot('01-login-inicio.png');

    await shot('02-login-registro.png', async () => {
      const registerLink = page.getByText(/crear cuenta nueva/i);
      if (await registerLink.count()) {
        await registerLink.first().click();
        await page.waitForTimeout(1200);
      }
    });

    await page.goto(`http://127.0.0.1:${port}/email-verification`, {
      waitUntil: 'networkidle',
      timeout: 120000,
    });
    await page.waitForTimeout(3500);
    await page.screenshot({
      path: path.join(outDir, '03-verificacion-correo.png'),
      fullPage: false,
    });
    console.log('OK 03-verificacion-correo.png');
  } finally {
    await browser.close();
    server.kill('SIGTERM');
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
