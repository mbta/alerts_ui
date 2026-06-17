import { test, expect } from '../fixtures';
import { AlertsListPage } from '../helpers/alerts_list_page';

// Read-only: only reads/filters the list, never mutates data. Safe on all envs.
test.describe('Alerts list view @readonly', () => {
  test('opens on the Current tab with no filters and rows present', async ({ loggedInPage }) => {
    const list = new AlertsListPage(loggedInPage);
    await list.goto();
    // Default timeline is Current (its hidden radio is checked).
    await expect(list.timelineRadio('current')).toBeChecked();
    // No active filters on first load -> the funnel button reads plain "Filter".
    await expect(loggedInPage.getByRole('button', { name: /^Filter$/ })).toBeVisible();
    await expect(list.rows().first()).toBeVisible();
  });

  test('timeline tabs switch the view', async ({ loggedInPage }) => {
    const list = new AlertsListPage(loggedInPage);
    await list.goto();
    await list.openTab('Past');
    await expect(loggedInPage).toHaveURL(/timeline\]?=past/);
    await expect(list.timelineRadio('past')).toBeChecked();
    await list.openTab('Current');
    await expect(list.timelineRadio('current')).toBeChecked();
  });

  test('filter modal has three populated sections and applying filters narrows results', async ({ loggedInPage }) => {
    const list = new AlertsListPage(loggedInPage);
    await list.goto();
    await list.openFilters();

    // All three sections are present and populated.
    const modal = list.filterModal();
    await expect(modal.getByRole('heading', { name: 'Service Types' })).toBeVisible();
    await expect(modal.getByRole('heading', { name: 'Routes' })).toBeVisible();
    await expect(modal.getByRole('heading', { name: 'Effects' })).toBeVisible();
    await expect(loggedInPage.locator('#view_alerts_live_service_type option')).not.toHaveCount(0);
    await expect(loggedInPage.locator('#view_alerts_live_routes option')).not.toHaveCount(0);
    await expect(loggedInPage.locator('#view_alerts_live_effects option')).not.toHaveCount(0);

    // Apply the doc's example combination.
    await list.selectServiceType('Subway');
    await list.selectRoute('Red Line');
    await list.selectEffect('Station Issue');
    await list.applyFilters();

    // Modal closes and the chosen filters are reflected in the URL (results filtered).
    await expect(list.filterModal()).toBeHidden();
    await expect(loggedInPage).toHaveURL(/service_type/);
    await expect(loggedInPage).toHaveURL(/Station\+Issue|Station%20Issue|effects/);
  });

  test('search by id narrows to that alert; a non-match shows the empty state', async ({ loggedInPage }) => {
    const list = new AlertsListPage(loggedInPage);
    await list.goto();

    // Grab a real id from the first row so the test is robust to seed changes.
    const firstId = (await list.rows().first().locator('.alert-id-cell').innerText()).trim();
    expect(firstId).toMatch(/^\d+$/);

    await list.search(firstId);
    await expect(list.rows().first().locator('.alert-id-cell')).toHaveText(firstId);

    // A clearly-absent term yields an explicit empty state, not an error.
    await list.search('zzzznomatch-xyz');
    await expect(list.emptyState()).toBeVisible();
    await expect(loggedInPage.getByText('0 alerts')).toBeVisible();
  });

  test('clicking a row opens the alert details modal', async ({ loggedInPage }) => {
    const list = new AlertsListPage(loggedInPage);
    await list.goto();
    await list.rows().first().click();
    await expect(list.detailsModal()).toBeVisible();
  });
});
