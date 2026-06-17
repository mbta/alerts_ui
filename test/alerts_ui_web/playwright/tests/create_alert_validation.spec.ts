import { test, expect } from '../fixtures';
import { CreateAlertPage } from '../helpers/create_alert_page';
import { VALIDATION } from '../helpers/selectors';

// Read-only: navigates the mono create form and triggers validation, never
// reaching a successful submit, so it is safe on every environment.
test.describe('Subway create-form validation @readonly', () => {
  test('Review and Submit on an empty Subway form shows validation errors and does not advance', async ({ loggedInPage }) => {
    const create = new CreateAlertPage(loggedInPage);
    await create.gotoNew();
    await create.chooseServiceType('subway');
    await create.chooseEffect(/station issue/i);

    await create.reviewAndSubmit();

    // The red error flash names the missing required selection.
    // consensus: the displayed wording is error_formatter's ("Select stop(s)"),
    // matching the regression doc — not the internal changeset message.
    const flash = loggedInPage.getByRole('alert').filter({ hasText: VALIDATION.errorFlashTitle });
    await expect(flash).toBeVisible();
    await expect(flash).toContainText(VALIDATION.subwayStop);

    // The form must not advance to the review modal or create an alert.
    await expect(loggedInPage).toHaveURL(/\/alerts\/mono\/new\/subway\/station_issue/);
    await expect(create.reviewModal()).toBeHidden();

    // consensus (skeptic): the LiveView must not crash — Phoenix's always-present
    // server-error overlay stays hidden (it is in the DOM but only shown on crash).
    await expect(loggedInPage.getByText(/something went wrong/i)).toBeHidden();
  });
});
