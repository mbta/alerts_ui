// Smoke-test a saved auth session for a deployed Alerts UI environment.
// Usage (cwd: this scripts/ dir, so `playwright` resolves):
//   node auth-smoke-test.mjs <dev-green|dev-orange|staging>
// Exit 0 + {"authed":true} if the saved storageState still reaches the app;
// exit 1 if there is no state file or it bounces to the Keycloak login.
import { chromium } from 'playwright';
import { existsSync } from 'fs';

const env = process.argv[2] ?? 'dev-green';
const URLS = {
  'dev-green': 'https://alerts-manager-dev-green.mbtace.com',
  'dev-orange': 'https://alerts-manager-dev-orange.mbtace.com',
  staging: 'https://alerts-manager-staging.mbtace.com',
};
if (!URLS[env]) {
  console.log(JSON.stringify({ authed: false, reason: `unknown env "${env}"` }));
  process.exit(1);
}
const statePath = new URL(`./.auth/${env}-state.json`, import.meta.url).pathname;
if (!existsSync(statePath)) {
  console.log(JSON.stringify({ authed: false, reason: 'no state file', statePath }));
  process.exit(1);
}

const browser = await chromium.launch({ headless: true });
try {
  const context = await browser.newContext({ storageState: statePath });
  const page = await context.newPage();
  await page.goto(URLS[env]);
  await page.waitForLoadState('networkidle');
  const authed = new URL(page.url()).host === new URL(URLS[env]).host;
  console.log(JSON.stringify({ authed, url: page.url(), title: await page.title() }));
  process.exitCode = authed ? 0 : 1;
} finally {
  await browser.close();
}
