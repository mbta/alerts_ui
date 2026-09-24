import { AlertsListPage } from "./helpers/alerts_list_page";
import { CreateAlertPage } from "./helpers/create_alert_page";
import { test, expect, type Page } from "@playwright/test"

test.describe.configure({ mode: 'serial' });

let page: Page;
const alertId1 = crypto.randomUUID()
const alertId2 = crypto.randomUUID()


test.beforeAll(async ({ browser }) => {
    page = await browser.newPage();
    const create = new CreateAlertPage(page);

    await create.createRedLineDelay(`test alert ${alertId1}`)
    await expect(page).toHaveURL(new RegExp(`/alerts$`));
    await create.createRedLineDelay(`test alert ${alertId2}`)
})

test.afterAll(async () => {
    await page.close()
})

test.describe('View alerts page @mutating', () => {

    test('can still open a modal after closing an alert',
        async ({ page }) => {
            const listPage = new AlertsListPage(page);
            await listPage.goto()
            await page.getByRole('cell', { name: `test alert ${alertId1}` }).click()
            await page.getByRole('button', { name: 'Close alert' }).click()
            await page.getByRole('button', { name: 'Close now' }).click()

            await page.getByRole('cell', { name: `test alert ${alertId2}` }).click()
            await expect(page.locator("#review-modal-container")).toBeVisible()
        });

    test("send notification checkbox stays checked after closing modal", async ({ page }) => {
        const listPage = new AlertsListPage(page);
        await listPage.goto()
        await page.getByRole('cell', { name: `test alert ${alertId2}` }).click()
        await page.getByRole('button', { name: 'Close alert' }).click()
        await expect(page.getByRole('checkbox')).toBeChecked();
        await page.getByRole('button', { name: 'Keep Active' }).click()
        await page.getByRole('button', { name: 'Close alert' }).click()
        await expect(page.getByRole('checkbox')).toBeChecked();
    })
});