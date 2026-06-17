import { test, expect, skipIfDeployed } from '../fixtures';
import { CreateAlertPage } from '../helpers/create_alert_page';

// @mutating: this test SUBMITS and creates an alert, so it runs on the local
// env only and auto-skips on the read-only deployed environments.
test.describe('Create a one-time Subway alert @mutating', () => {
  // Use the raw `page` (not the loggedInPage fixture) and skip BEFORE any
  // navigation, so a deployed run skips without hitting the Keycloak wall.
  test('fills the mono form, reviews, and submits, landing back on the list with the new alert',
    async ({ page }, testInfo) => {
      skipIfDeployed(testInfo);
      const loggedInPage = page;
      const create = new CreateAlertPage(loggedInPage);

      // Subway -> Station Issue details form (URL stays under /mono/).
      await create.gotoNew();
      await create.chooseServiceType('subway');
      await create.chooseEffect('station_issue');

      // Selecting a stop drives the autotext main message.
      await create.selectStop('Alewife');
      // consensus (qa): autotext incorporates the chosen stop.
      await expect(create.mainMessage()).toHaveValue(/Station issue at Alewife\./);

      // Review shows the selections.
      await create.reviewAndSubmit();
      await expect(create.reviewModal()).toBeVisible();
      await expect(create.reviewModal()).toContainText('Station issue at Alewife.');

      // Keep editing returns to the form with state preserved.
      await create.keepEditing();
      await expect(create.reviewModal()).toBeHidden();
      await expect(create.mainMessage()).toHaveValue(/Station issue at Alewife\./);

      // Review again and submit for real.
      await create.reviewAndSubmit();
      await expect(create.reviewModal()).toBeVisible();
      await create.submit();

      // Lands back on the alerts list with the newly created alert present.
      await expect(loggedInPage).toHaveURL(/\/alerts(\?|$)/);
      await expect(
        loggedInPage.locator('tbody tr', { hasText: 'Station issue at Alewife.' }).first(),
      ).toBeVisible();
    });
});
