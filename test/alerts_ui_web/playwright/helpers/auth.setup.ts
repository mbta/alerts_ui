import { test as setup, chromium } from '@playwright/test';
import * as fs from 'fs';
import * as path from 'path';

// Reuse-or-prompt capture of deployed-env Keycloak sessions into the shared
// qa-asana-ticket .auth store. Runs (headed) as a dependency of the deployed
// projects. The USER logs in; we only persist the resulting session cookies.
// Mirrors the qa-capture-auth-session skill's conventions.

const authDir = path.join(__dirname, '../../../../.claude/skills/qa-asana-ticket/scripts/.auth');

const URLS: Record<string, string> = {
  'dev-green': 'https://alerts-manager-dev-green.mbtace.com',
  'dev-orange': 'https://alerts-manager-dev-orange.mbtace.com',
  staging: 'https://alerts-manager-staging.mbtace.com',
};

setup('capture deployed sessions', async () => {
  setup.setTimeout(360_000); // allow up to ~6 minutes for manual login

  const envs = (process.env.E2E_ENVS || '')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);

  for (const env of envs) {
    const base = URLS[env];
    if (!base) {
      console.log(`[auth] unknown env "${env}" — skipping`);
      continue;
    }
    const statePath = path.join(authDir, `${env}-state.json`);
    const appHost = new URL(base).host;

    // 1) Reuse a still-valid saved session.
    if (fs.existsSync(statePath) && (await sessionValid(base, statePath, appHost))) {
      console.log(`[auth] reusing valid ${env} session`);
      continue;
    }

    // 2) Interactive headed login — the user signs in; we never touch creds.
    const browser = await chromium.launch({ headless: false });
    try {
      const context = await browser.newContext();
      const page = await context.newPage();
      await page.goto(base);
      console.log(
        `\n>>> [auth] Log in to ${env} (${base}) in the opened browser window. ` +
          `Waiting up to 5 minutes for you to finish...\n`,
      );
      await page.waitForURL((u) => new URL(u).host === appHost, { timeout: 300_000 });

      // Keep only this env's app cookies + MBTA Keycloak SSO cookies; drop
      // Microsoft/EntraID/analytics. Drop localStorage (origins: []).
      const state = await context.storageState();
      const trimmed = {
        cookies: state.cookies.filter(
          (c) => c.domain.endsWith('mbtace.com') && (c.domain === appHost || c.domain.startsWith('login-')),
        ),
        origins: [] as never[],
      };
      fs.mkdirSync(path.dirname(statePath), { recursive: true });
      fs.writeFileSync(statePath, JSON.stringify(trimmed));
      fs.chmodSync(statePath, 0o600);
      console.log(`[auth] saved ${env} session -> ${statePath}`);
    } finally {
      await browser.close();
    }
  }
});

async function sessionValid(base: string, statePath: string, appHost: string): Promise<boolean> {
  const browser = await chromium.launch({ headless: true });
  try {
    const context = await browser.newContext({ storageState: statePath });
    const page = await context.newPage();
    await page.goto(base);
    await page.waitForLoadState('networkidle').catch(() => {});
    return new URL(page.url()).host === appHost;
  } catch {
    return false;
  } finally {
    await browser.close();
  }
}
