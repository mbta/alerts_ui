
import { CreateAlertPage } from "./helpers/create_alert_page";
import { test, expect } from "@playwright/test"

test.describe('Create a one-time Subway alert', () => {
  test('fills the form, reviews, and submits, landing back on the list with the new alert @mutating',
    async ({ page }) => {
      const create = new CreateAlertPage(page);

      // Subway -> Station Issue details form
      await create.gotoNew();
      await create.chooseServiceType('subway');
      await create.chooseEffect('station_issue');

      // Selecting a stop drives the autotext main message.
      await create.selectStop('Alewife');
      // Autotext incorporates the chosen stop.
      await expect(create.mainMessage()).toHaveValue(/Station issue at Alewife\./);

      // Review shows the selections (modal open is a server round-trip).
      await create.reviewAndSubmit();
      await expect(create.reviewModal()).toBeVisible({ timeout: 20000 });
      await expect(create.reviewModal()).toContainText('Station issue at Alewife.');

      // Keep editing returns to the form with state preserved.
      await create.keepEditing();
      await expect(create.reviewModal()).toBeHidden();
      await expect(create.mainMessage()).toHaveValue(/Station issue at Alewife\./);

      // Review again and submit for real.
      await create.reviewAndSubmit();
      await expect(create.reviewModal()).toBeVisible({ timeout: 20000 });
      await create.submit();

      // Lands back on the alerts list with the newly created alert present.
      await expect(page).toHaveURL(/\/alerts(\?|$)/);
      await expect(
        page.locator('tbody tr', { hasText: 'Station issue at Alewife.' }).first(),
      ).toBeVisible();
    });
});

// These are tests that are generally difficult to test in elixir
test.describe("create alert form interactions", () => {
  test("Should be able to unselect the last item on a multiselect", async ({ page }) => {
    const create = new CreateAlertPage(page);

    await create.gotoEffect("bus", "delay")
    await create.selectRoute("SL1")

    await expect(create.mainMessage()).toHaveValue(/SL1 is experiencing delays of about 15 minutes\./)

    // Unselect SL1
    await create.selectRoute("SL1", { modifiers: ["Meta"] })
    await expect(create.mainMessage()).toHaveValue(/experiencing delays of about 15 minutes\./)

    // Submitting should show error since route was unselected
    await create.reviewAndSubmit();
    await expect(create.flashMessage()).toContainText("Select route(s)", { timeout: 15000 })
  })

  test("Hitting esc should not take user back to the home page", async ({ page }) => {
    const create = new CreateAlertPage(page);
    await create.gotoEffect("bus", "delay")
    await expect(page).toHaveURL('/alerts/new/bus/delay');
    const navigationPromise = page.waitForURL("/alerts", { timeout: 2000 }).catch(() => null);
    page.keyboard.press('Escape')

    // Await the navigation promise, otherwise asserting on the current URL will always pass
    // because playwright checks immediately before navigation
    await navigationPromise;
    await expect(page).toHaveURL('/alerts/new/bus/delay');
  })

  test("Should not be able to select All Stops AND other stops", async ({ page }) => {
    const create = new CreateAlertPage(page);
    await create.gotoEffect("bus", "delay")
    await expect(page).toHaveURL('/alerts/new/bus/delay');
    await create.selectRoute("SL1")

    await create.selectStop("South Station (outbound)")
    await create.selectStop("Silver Line Way (outbound)", { modifiers: ["Shift"] })
    await expect(create.supportingMessage()).toHaveValue("Affected outbound stops:\nSouth Station\nCourthouse\nWorld Trade Center\nSilver Line Way")

    // Try to also click 'All Stops', should only keep South Station selected
    await create.selectStop("All Stops", { modifiers: ["Shift"] })
    await expect(create.supportingMessage()).toHaveValue("Affected outbound stops:\nSouth Station")
    await expect(page.locator('#alert_data_stop_names_and_ids')).toHaveValues(["South Station (outbound)|place-sstat"])

    // Now only select 'All Stops'
    await create.selectStop("All Stops")
    await expect(create.supportingMessage()).toHaveValue("")
    await expect(page.locator('#alert_data_stop_names_and_ids')).toHaveValues(["default"])

    // Try to mod+select one other stop. Only the other stop should get selected
    await create.selectStop("South Station (outbound)", { modifiers: ["Meta"] })
    await expect(create.supportingMessage()).toHaveValue("Affected outbound stops:\nSouth Station")
    await expect(page.locator('#alert_data_stop_names_and_ids')).toHaveValues(["South Station (outbound)|place-sstat"])

  })
})