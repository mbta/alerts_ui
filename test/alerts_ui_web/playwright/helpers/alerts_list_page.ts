import { Page, Locator, expect } from '@playwright/test';
import { LIST } from './selectors';

/** Page object for the alerts list view (/alerts). */
export class AlertsListPage {
  constructor(private readonly page: Page) {}

  async goto() {
    await this.page.goto('/alerts');
    await expect(this.page).toHaveURL(/\/alerts(\?|$)/);
    // LiveView server events (tab switch, modal show) need the socket joined.
    await this.page.locator('[data-phx-main].phx-connected').waitFor();
  }

  /**
   * Timeline tabs render as clickable labels wrapping hidden radios.
   * Click the label text; assert state via the hidden radio (see timelineRadio).
   */
  tab(name: string): Locator {
    return this.page.locator('.join.w-full').getByText(name, { exact: true });
  }

  /** Hidden radio backing a timeline tab (value is lowercased name). */
  timelineRadio(value: string): Locator {
    return this.page.locator(`input[name="timeline"][value="${value}"]`);
  }

  async openTab(name: string) {
    await this.tab(name).click();
  }

  /** Funnel button labelled "Filter" or "Filters: N". */
  async openFilters() {
    await this.page.getByRole('button', { name: LIST.filtersButton }).first().click();
    await expect(this.filterModal()).toBeVisible();
  }

  filterModal(): Locator {
    return this.page.locator(LIST.filterModalId);
  }

  // The three filter sections are collapsed accordions wrapping hidden
  // (visibility:hidden) native multi-selects. Expand the section by clicking
  // its label before the select can receive selectOption.
  private async expandSection(heading: string) {
    await this.filterModal().locator('label', { hasText: heading }).click();
  }

  async selectServiceType(label: string) {
    await this.expandSection('Service Types');
    await this.page.locator('#view_alerts_live_service_type').selectOption({ label });
  }
  async selectRoute(label: string) {
    await this.expandSection('Routes');
    await this.page.locator('#view_alerts_live_routes').selectOption({ label });
  }
  async selectEffect(label: string) {
    await this.expandSection('Effects');
    await this.page.locator('#view_alerts_live_effects').selectOption({ label });
  }

  async applyFilters() {
    await this.filterModal().getByRole('button', { name: LIST.applyButton }).click();
  }

  rows(): Locator {
    return this.page.locator('tbody tr');
  }

  /** The "N alerts" count shown above the table. */
  countText(): Locator {
    return this.page.getByText(/^\d+ alerts?$/);
  }

  /** Search is debounced and applied on change; do NOT press Enter. */
  async search(term: string) {
    await this.page.getByPlaceholder(LIST.searchPlaceholder).fill(term);
  }

  emptyState(): Locator {
    return this.page.getByText(LIST.emptyState);
  }

  detailsModal(): Locator {
    return this.page.locator(LIST.detailsModalId);
  }
}
