import { Page, Locator, expect } from '@playwright/test';
import { CREATE } from './selectors';

/**
 * Page object for the "mono" alert creation flow (/alerts/mono/new...).
 * Drives controls like a human (click/fill/selectOption) — never synthetic
 * value/checked mutation, which LiveView ignores.
 */
export class CreateAlertPage {
  constructor(private readonly page: Page) {}

  async gotoNew() {
    await this.page.goto('/alerts/mono/new');
    await expect(this.page).toHaveURL(/\/alerts\/mono\/new/);
  }

  /** Service-type buttons: ids like #route-type-subway-button. */
  serviceTypeButton(routeKey: string): Locator {
    return this.page.locator(`#route-type-${routeKey}-button`);
  }

  async chooseServiceType(routeKey: string) {
    await this.serviceTypeButton(routeKey).click();
  }

  /** Effect buttons appear after a service type is selected. */
  async chooseEffect(name: string | RegExp) {
    await this.page.getByRole('button', { name }).first().click();
    await expect(this.page).toHaveURL(/\/alerts\/mono\/new\/.+\/.+/);
  }

  async chooseSubwayLine(name: string) {
    await this.page.getByRole('button', { name, exact: true }).click();
  }

  directionSelect(): Locator {
    return this.page.getByLabel(CREATE.directionLabel);
  }

  stopsSelect(): Locator {
    return this.page.getByLabel(CREATE.stopsLabel);
  }

  causeSelect(): Locator {
    return this.page.getByLabel(CREATE.causeLabel);
  }

  severitySelect(): Locator {
    return this.page.getByLabel(CREATE.severityLabel);
  }

  mainMessage(): Locator {
    return this.page.getByLabel(CREATE.mainMessageLabel);
  }

  notificationToggle(): Locator {
    return this.page.locator(CREATE.notificationToggleId);
  }

  async reviewAndSubmit() {
    await this.page.locator(CREATE.reviewButtonId).click();
  }

  reviewModal(): Locator {
    return this.page.locator('#review-modal');
  }

  async keepEditing() {
    await this.page.getByRole('button', { name: CREATE.keepEditing }).click();
  }

  async submit() {
    await this.page.getByRole('button', { name: CREATE.submit }).click();
  }
}
