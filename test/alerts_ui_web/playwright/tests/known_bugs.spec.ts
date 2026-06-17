import { test, expect } from '../fixtures';
import { CreateAlertPage } from '../helpers/create_alert_page';

// Demonstrates UI bugs found while building this harness. Each test is marked
// test.fail(): it reproduces a real bug, so the suite stays green now and the
// run flips to an "unexpected pass" the moment the bug is fixed — a prompt to
// delete the marker. See docs/playwright-e2e-proving-slice-report.md.
test.describe('Known bugs @bug', () => {
  test('Subway Direction control should be labelled "Direction", not "Stops"', async ({ loggedInPage }) => {
    test.fail(); // BUG: affected_service_slice.ex labels the direction <select> "Stops"

    const create = new CreateAlertPage(loggedInPage);
    await create.gotoEffect('subway', 'delay');

    // Selecting a line enables the Direction control.
    await loggedInPage.locator('label[for="route-search-Red"]').click();

    // The direction dropdown should be reachable by an accurate accessible name.
    // Today it is labelled "Stops" (and the real stops list is unlabelled), so
    // this resolves to nothing and the assertion fails — which test.fail expects.
    await expect(loggedInPage.getByLabel('Direction')).toBeVisible();
  });
});
