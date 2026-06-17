import { test as base, expect, Page, TestInfo } from '@playwright/test';

/** True when the active Playwright project targets the local dev server. */
export function isLocalProject(testInfo: TestInfo): boolean {
  return testInfo.project.name === 'local';
}

/** Skip the current test on any deployed (read-only) environment. */
export function skipIfDeployed(testInfo: TestInfo): void {
  test.skip(!isLocalProject(testInfo), 'mutating test runs on the local env only');
}

type Fixtures = {
  /** A page already authenticated and sitting on the alerts list. */
  loggedInPage: Page;
};

export const test = base.extend<Fixtures>({
  loggedInPage: async ({ page }, use) => {
    // local: FakeKeycloak auto-logs in via the OIDC redirect chain.
    // deployed: storageState (project config) carries the captured session.
    await page.goto('/alerts');
    await expect(page, 'should land on the alerts list (auth working)').toHaveURL(/\/alerts(\?|$)/);
    await use(page);
  },
});

export { expect };
