import { Page, Locator, expect } from '@playwright/test';
import { LIST } from './selectors';

/** Page object for the alerts list view (/alerts). */
export class AlertsListPage {
  constructor(private readonly page: Page) {}

  async goto() {
    await this.page.goto('/alerts');
    await expect(this.page).toHaveURL(/\/alerts(\?|$)/);
  }

  /** Timeline tabs render as radio inputs with an aria-label. */
  tab(name: string): Locator {
    return this.page.getByRole('radio', { name, exact: true });
  }

  async openTab(name: string) {
    await this.tab(name).click();
  }

  /** Funnel button labelled "Filter" or "Filters: N". */
  async openFilters() {
    await this.page.getByRole('button', { name: LIST.filtersButton }).first().click();
  }

  filterModal(): Locator {
    return this.page.locator(LIST.filterModalId);
  }

  rows(): Locator {
    // Data rows live in the table body; exclude the header row.
    return this.page.locator('tbody tr');
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
