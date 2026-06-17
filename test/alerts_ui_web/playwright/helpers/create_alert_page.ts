import { Page, Locator, expect } from '@playwright/test';

/**
 * Page object for the "mono" alert creation flow (/alerts/mono/new...).
 * Drives controls like a human (click/fill/selectOption) — never synthetic
 * value/checked mutation, which LiveView ignores. Element ids verified live
 * (alert_data_* form fields; #review button; #review-modal dialog).
 */
export class CreateAlertPage {
  constructor(private readonly page: Page) {}

  async gotoNew() {
    await this.page.goto('/alerts/mono/new');
    await expect(this.page).toHaveURL(/\/alerts\/mono\/new/);
    await this.page.locator('[data-phx-main].phx-connected').waitFor();
  }

  /** Deep-link straight to a route_type + effect details form. */
  async gotoEffect(routeType: string, effectSlug: string) {
    await this.page.goto(`/alerts/mono/new/${routeType}/${effectSlug}`);
    await expect(this.page).toHaveURL(new RegExp(`/alerts/mono/new/${routeType}/${effectSlug}`));
    await this.page.locator('[data-phx-main].phx-connected').waitFor();
  }

  /** Service-type buttons: ids like #route-type-subway-button. */
  async chooseServiceType(routeKey: string) {
    await this.page.locator(`#route-type-${routeKey}-button`).click();
  }

  /** Effect buttons: ids like #effect-name-station_issue-button. */
  async chooseEffect(effectSlug: string) {
    await this.page.locator(`#effect-name-${effectSlug}-button`).click();
    await expect(this.page).toHaveURL(new RegExp(`/alerts/mono/new/.+/${effectSlug}`));
  }

  /** Stops render as a role=listbox "Stops" with role=option children. */
  async selectStop(name: string) {
    await this.page.getByRole('option', { name, exact: true }).click();
  }

  mainMessage(): Locator {
    return this.page.locator('#alert_data_header_text');
  }

  async selectCause(label: string) {
    await this.page.locator('#alert_data_cause_detail').selectOption({ label });
  }

  async selectSeverity(label: string) {
    await this.page.locator('#alert_data_severity').selectOption({ label });
  }

  notificationToggle(): Locator {
    return this.page.getByRole('checkbox', { name: /Send notification to alert subscribers/i });
  }

  async reviewAndSubmit() {
    await this.page.locator('#review').click();
  }

  reviewModal(): Locator {
    return this.page.locator('#review-modal');
  }

  async keepEditing() {
    await this.reviewModal().getByRole('button', { name: /keep editing/i }).click();
  }

  async submit() {
    await this.reviewModal().getByRole('button', { name: /^submit$/i }).click();
  }
}
