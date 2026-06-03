// Example per-agent headless verification script.
// Copy/adapt into $CLAUDE_JOB_DIR/tmp/<ticket_gid>-verify.mjs and run with:
//   node --experimental-default-type=module <script>   (cwd: this scripts/ dir, so `playwright` resolves)
// or: NODE_PATH=<this dir>/node_modules node <script>
//
// Each script owns a private headless browser — no MCP, no shared tabs, no contention.
import { chromium } from 'playwright';
import { existsSync } from 'fs';

const BASE = process.env.QA_BASE_URL ?? 'http://localhost:4010';
const OUT = process.env.QA_EVIDENCE_DIR ?? '.';

// Deployed envs (dev-green/dev-orange/staging) sit behind a real Keycloak wall.
// If the user has captured an authenticated session (see SKILL.md "Auth-walled
// environments"), a storageState file exists under scripts/.auth/ — load it and
// the context starts already signed in. Local needs no state (FakeKeycloak).
const STATE = new URL(`./.auth/${process.env.QA_AUTH_STATE ?? 'dev-green-state'}.json`, import.meta.url).pathname;
const contextOpts = { viewport: { width: 1440, height: 900 } };
if (BASE.includes('mbtace.com') && existsSync(STATE)) contextOpts.storageState = STATE;

const browser = await chromium.launch({ headless: true });
const context = await browser.newContext(contextOpts);
const page = await context.newPage();
const consoleErrors = [];
page.on('console', (m) => m.type() === 'error' && consoleErrors.push(m.text()));

try {
  // --- adapt from here: follow the ticket's Steps to Reproduce ---
  await page.goto(`${BASE}/alerts/mono/new`);          // alert URLs must contain /mono/
  // If this lands on login-dev.mbtace.com, the saved session has expired:
  // report BLOCKED and ask the orchestrator/user to re-capture, don't try to log in.
  await page.getByRole('button', { name: /subway/i }).click();
  // Evidence per criterion: screenshots + targeted assertions
  await page.screenshot({ path: `${OUT}/step-1.png`, fullPage: false });
  const box = await page.locator('#some_input').boundingBox(); // geometry checks
  // --- adapt to here ---

  console.log(JSON.stringify({ ok: true, box, consoleErrors }));
} catch (err) {
  await page.screenshot({ path: `${OUT}/failure.png` }).catch(() => {});
  console.log(JSON.stringify({ ok: false, error: String(err), consoleErrors }));
  process.exitCode = 1;
} finally {
  await browser.close();
}
