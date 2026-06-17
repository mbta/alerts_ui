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

  test('"Start of service" date picker default is not below its own minimum', async ({ loggedInPage }) => {
    // BUG: the Start-of-service date picker defaults to today (the doc says it
    // should), but its `min` is set to tomorrow — so the default value is below
    // the field's own minimum and "today" is not actually selectable. Either the
    // default or the min is off by a day.
    test.fail();

    const create = new CreateAlertPage(loggedInPage);
    await create.gotoEffect('subway', 'station_issue');

    await loggedInPage.locator('#alert_data_active_period_start_specifier').selectOption('start_of_service');
    const dateInput = loggedInPage.locator('#alert_data_active_period_start_date');
    await expect(dateInput).toBeVisible();

    const value = await dateInput.inputValue();
    const min = await dateInput.getAttribute('min');
    expect(min, 'date picker should set a minimum').not.toBeNull();

    // ISO date strings sort lexicographically; the default must not predate min.
    expect(value >= (min as string), `default ${value} must be >= min ${min}`).toBe(true);
  });
});
