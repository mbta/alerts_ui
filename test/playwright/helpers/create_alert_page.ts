import { Page, Locator, expect } from '@playwright/test';

type ClickOptions = Parameters<Locator['click']>[0]

/**
 * Page object creating alerts.
 */
export class CreateAlertPage {
    constructor(private readonly page: Page) { }

    async gotoNew() {
        await this.page.goto('/alerts/new');
        await expect(this.page).toHaveURL(/\/alerts\/new/);
        await this.page.locator('[data-phx-main].phx-connected').waitFor();
    }

    /** Deep-link straight to a route_type + effect details form. */
    async gotoEffect(routeType: string, effectSlug: string) {
        await this.page.goto(`/alerts/new/${routeType}/${effectSlug}`);
        await expect(this.page).toHaveURL(new RegExp(`/alerts/new/${routeType}/${effectSlug}`));
        await this.page.locator('[data-phx-main].phx-connected').waitFor();
    }

    /** Service-type buttons: ids like #route-type-subway-button. */
    async chooseServiceType(routeKey: string) {
        await this.page.locator(`#route-type-${routeKey}-button`).click();
    }

    /** Effect buttons: ids like #effect-name-station_issue-button. */
    async chooseEffect(effectSlug: string) {
        await this.page.locator(`#effect-name-${effectSlug}-button`).click();
        await expect(this.page).toHaveURL(new RegExp(`/alerts/new/.+/${effectSlug}`));
    }

    async selectRoute(name: string, opts?: ClickOptions) {
        await this.page.getByLabel('Routes').getByRole('option', { name, exact: true }).click(opts)
    }

    /** Stops render as a role=listbox "Stops" with role=option children. */
    async selectStop(name: string, opts?: ClickOptions) {
        await this.page.locator('#alert_data_stop_names_and_ids').
            getByRole('option', { name, exact: true }).click(opts);
    }

    mainMessage(): Locator {
        return this.page.locator('#alert_data_header_text');
    }

    supportingMessage(): Locator {
        return this.page.getByRole('textbox', { name: 'Supporting information' })
    }

    flashMessage(): Locator {
        return this.page.getByRole("alert")
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