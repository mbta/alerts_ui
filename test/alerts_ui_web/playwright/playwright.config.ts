import { defineConfig, devices } from '@playwright/test';
import type { PlaywrightTestConfig } from '@playwright/test';
import * as path from 'path';

// Captured deployed-env sessions live in the shared qa-asana-ticket .auth store.
// Path is relative to this config file: test/alerts_ui_web/playwright -> repo root.
const authDir = path.join(__dirname, '../../../.claude/skills/qa-asana-ticket/scripts/.auth');
const stateFor = (env: string) => path.join(authDir, `${env}-state.json`);

// Deployed environments behind the Keycloak wall (local needs no auth).
const DEPLOYED: Record<string, string> = {
  'dev-green': 'https://alerts-manager-dev-green.mbtace.com',
  'dev-orange': 'https://alerts-manager-dev-orange.mbtace.com',
  staging: 'https://alerts-manager-staging.mbtace.com',
};

// Engage a deployed env only when E2E_ENVS lists it (set by the `npm run
// test:<env>` scripts). A real shell env var propagates to worker processes, so
// the project list is identical in the runner and its workers — unlike argv,
// which workers don't see. Bare `npx playwright test` => local only.
const deployedRequested = (process.env.E2E_ENVS || '')
  .split(',')
  .map((s) => s.trim())
  .filter((e) => DEPLOYED[e]);

const projects: PlaywrightTestConfig['projects'] = [
  { name: 'local', use: { ...devices['Desktop Chrome'], baseURL: 'http://localhost:4010' } },
];

if (deployedRequested.length > 0) {
  // Headed setup: reuses or interactively captures the Keycloak session(s)
  // before the deployed projects run. See helpers/auth.setup.ts.
  projects.push({
    name: 'auth-setup',
    testDir: './helpers',
    testMatch: /auth\.setup\.ts/,
    use: { ...devices['Desktop Chrome'], headless: false },
  });
  for (const env of deployedRequested) {
    projects.push({
      name: env,
      use: {
        ...devices['Desktop Chrome'],
        baseURL: DEPLOYED[env],
        storageState: stateFor(env),
      },
      dependencies: ['auth-setup'],
    });
  }
}

export default defineConfig({
  testDir: './tests',
  fullyParallel: true,
  // The suite drives a single stateful LiveView dev server; a modest worker cap
  // avoids server/DB contention that otherwise makes round-trip events flaky.
  workers: process.env.CI ? 1 : 3,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 1 : 0,
  reporter: [['html', { open: 'never' }], ['list']],
  use: {
    headless: true,
    viewport: { width: 1440, height: 900 },
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
  },
  projects,
});
