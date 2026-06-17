import { defineConfig, devices } from '@playwright/test';
import * as path from 'path';
import * as fs from 'fs';

// Captured deployed-env sessions live in the shared qa-asana-ticket .auth store.
// Path is relative to this config file: test/alerts_ui_web/playwright -> repo root.
const authDir = path.join(__dirname, '../../../.claude/skills/qa-asana-ticket/scripts/.auth');

// Only attach storageState when a captured session actually exists, so a
// deployed run with no session still creates a context (mutating tests then
// skip via skipIfDeployed; read-only tests need a captured session — see README).
const stateFor = (env: string) => {
  const p = path.join(authDir, `${env}-state.json`);
  return fs.existsSync(p) ? p : undefined;
};

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
  projects: [
    {
      name: 'local',
      use: { ...devices['Desktop Chrome'], baseURL: 'http://localhost:4010' },
    },
    {
      name: 'dev-green',
      use: {
        ...devices['Desktop Chrome'],
        baseURL: 'https://alerts-manager-dev-green.mbtace.com',
        storageState: stateFor('dev-green'),
      },
    },
    {
      name: 'dev-orange',
      use: {
        ...devices['Desktop Chrome'],
        baseURL: 'https://alerts-manager-dev-orange.mbtace.com',
        storageState: stateFor('dev-orange'),
      },
    },
    {
      name: 'staging',
      use: {
        ...devices['Desktop Chrome'],
        baseURL: 'https://alerts-manager-staging.mbtace.com',
        storageState: stateFor('staging'),
      },
    },
  ],
});
