import { defineConfig, devices } from '@playwright/test';
import * as path from 'path';

// Captured deployed-env sessions live in the shared qa-asana-ticket .auth store.
// Path is relative to this config file: test/alerts_ui_web/playwright -> repo root.
const authDir = path.join(__dirname, '../../../.claude/skills/qa-asana-ticket/scripts/.auth');
const stateFor = (env: string) => path.join(authDir, `${env}-state.json`);

export default defineConfig({
  testDir: './tests',
  fullyParallel: true,
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
