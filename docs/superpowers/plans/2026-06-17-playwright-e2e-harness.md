# Playwright E2E Harness + Proving Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up a headless, multi-environment `@playwright/test` harness under `test/alerts_ui_web/playwright/` and prove it with three regression specs derived from `docs/regression-testing.md`.

**Architecture:** A self-contained Node/TypeScript Playwright project with one Playwright `project` per environment (`local`, `dev-green`, `dev-orange`, `staging`). Local uses FakeKeycloak auto-login; deployed envs load a captured `storageState` from the existing `qa-asana-ticket` `.auth/` store and are treated read-only (mutating specs auto-skip there). Page objects encode the doc's UI and the "real user interaction, never synthetic DOM mutation" rule. Each spec's assertions are shaped by a three-persona evaluation workflow (QA engineer / bug-hunting skeptic / random-input fuzzer) run against the live DOM.

**Tech Stack:** `@playwright/test` (TypeScript), Chromium, Phoenix LiveView app under test at `localhost:4010` (or deployed `*.mbtace.com`).

---

## Reference: spec

Full design: `docs/superpowers/specs/2026-06-16-playwright-e2e-harness-design.md`. Read it before starting.

## File Structure

| File | Responsibility |
|------|----------------|
| `test/alerts_ui_web/playwright/package.json` | Pins `@playwright/test`; `test` script |
| `test/alerts_ui_web/playwright/playwright.config.ts` | Headless config; one `project` per env; baseURL + storageState; reporter/traces |
| `test/alerts_ui_web/playwright/fixtures.ts` | `loggedInPage` fixture; `isLocalProject` helper |
| `test/alerts_ui_web/playwright/helpers/selectors.ts` | Shared accessible-name/text selector constants |
| `test/alerts_ui_web/playwright/helpers/alerts_list_page.ts` | `AlertsListPage` page object |
| `test/alerts_ui_web/playwright/helpers/create_alert_page.ts` | `CreateAlertPage` page object (mono flow) |
| `test/alerts_ui_web/playwright/tests/alerts_list.spec.ts` | `@readonly` list-view spec |
| `test/alerts_ui_web/playwright/tests/create_alert_validation.spec.ts` | `@readonly` validation spec |
| `test/alerts_ui_web/playwright/tests/create_alert_subway.spec.ts` | `@mutating` local-only create spec |
| `test/alerts_ui_web/playwright/README.md` | Prerequisites + how to run (incl. background) |
| `.gitignore` (modify) | Ignore playwright artifacts + node_modules |

## Conventions used throughout

- **Locators are user-facing:** prefer `getByRole`, `getByLabel`, `getByText` with the exact labels from `docs/regression-testing.md`. Avoid CSS/test-ids unless a discovery step proves they're necessary.
- **Selector verification:** the exact accessible names below are taken from the regression doc. Each spec task begins with a *live-DOM discovery* step (Playwright MCP `browser_snapshot` against the running app) to confirm them before writing assertions; adjust the locator constants in `helpers/selectors.ts` if the live DOM differs, and note the drift in a `// consensus:`/`// drift:` comment.
- **Mutation gating:** mutating specs call `test.skip(testInfo.project.name !== 'local', ...)`.
- **Never synthetic DOM mutation:** only `.click()`, `.fill()`, `.press()`, `.type()`. Reads via `evaluate` are allowed.

---

## Task 1: Scaffold the Playwright project

**Files:**
- Create: `test/alerts_ui_web/playwright/package.json`
- Modify: `.gitignore`

- [ ] **Step 1: Create `package.json`**

```json
{
  "name": "alerts-ui-playwright",
  "version": "1.0.0",
  "private": true,
  "description": "End-to-end regression tests for alerts_ui",
  "scripts": {
    "test": "playwright test",
    "test:local": "playwright test --project=local",
    "test:dev-green": "playwright test --project=dev-green",
    "report": "playwright show-report"
  },
  "devDependencies": {
    "@playwright/test": "^1.48.0"
  }
}
```

- [ ] **Step 2: Add ignore rules to `.gitignore`**

Append these lines to the repo-root `.gitignore`:

```gitignore
# Playwright E2E harness
/test/alerts_ui_web/playwright/node_modules/
/test/alerts_ui_web/playwright/test-results/
/test/alerts_ui_web/playwright/playwright-report/
/test/alerts_ui_web/playwright/.last-run.json
```

- [ ] **Step 3: Install dependencies and the Chromium browser**

Run:
```bash
cd test/alerts_ui_web/playwright && npm install && npx playwright install chromium
```
Expected: `@playwright/test` installed; Chromium downloaded (or "is already installed").

- [ ] **Step 4: Commit**

```bash
git add test/alerts_ui_web/playwright/package.json test/alerts_ui_web/playwright/package-lock.json .gitignore
git commit -m "chore(e2e): scaffold Playwright harness package"
```

---

## Task 2: Playwright config with per-environment projects

**Files:**
- Create: `test/alerts_ui_web/playwright/playwright.config.ts`

- [ ] **Step 1: Write the config**

```typescript
import { defineConfig, devices } from '@playwright/test';
import * as path from 'path';

// Captured deployed-env sessions live in the shared qa-asana-ticket .auth store.
// Path is relative to this config file: test/alerts_ui_web/playwright -> repo root.
const authDir = path.join(__dirname, '../../../.claude/skills/qa-asana-ticket/scripts/.auth');
const stateFor = (env: string) => path.join(authDir, `${env}-state.json`);

export default defineConfig({
  testDir: './tests',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 1 : 0,
  reporter: [['html', { open: 'never' }], ['list']],
  use: {
    headless: true,
    viewport: { width: 1440, height: 900 },
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
  },
  projects: [
    {
      name: 'local',
      use: { ...devices['Desktop Chrome'], baseURL: 'http://localhost:4010' },
    },
    {
      name: 'dev-green',
      use: {
        ...devices['Desktop Chrome'],
        baseURL: 'https://alerts-manager-dev-green.mbtace.com',
        storageState: stateFor('dev-green'),
      },
    },
    {
      name: 'dev-orange',
      use: {
        ...devices['Desktop Chrome'],
        baseURL: 'https://alerts-manager-dev-orange.mbtace.com',
        storageState: stateFor('dev-orange'),
      },
    },
    {
      name: 'staging',
      use: {
        ...devices['Desktop Chrome'],
        baseURL: 'https://alerts-manager-staging.mbtace.com',
        storageState: stateFor('staging'),
      },
    },
  ],
});
```

- [ ] **Step 2: Verify the config loads and lists tests/projects**

Run:
```bash
cd test/alerts_ui_web/playwright && npx playwright test --list --project=local
```
Expected: No config error. Reports "Total: 0 tests" (no specs yet) — this confirms the config parses and the `local` project resolves.

- [ ] **Step 3: Commit**

```bash
git add test/alerts_ui_web/playwright/playwright.config.ts
git commit -m "feat(e2e): add per-environment Playwright config"
```

---

## Task 3: Auth/env fixture

**Files:**
- Create: `test/alerts_ui_web/playwright/fixtures.ts`

- [ ] **Step 1: Write the fixture**

```typescript
import { test as base, expect, Page, TestInfo } from '@playwright/test';

/** True when the active Playwright project targets the local dev server. */
export function isLocalProject(testInfo: TestInfo): boolean {
  return testInfo.project.name === 'local';
}

/** Skip the current test on any deployed (read-only) environment. */
export function skipIfDeployed(testInfo: TestInfo): void {
  test.skip(!isLocalProject(testInfo), 'mutating test runs on the local env only');
}

type Fixtures = {
  /** A page already authenticated and sitting on the alerts list. */
  loggedInPage: Page;
};

export const test = base.extend<Fixtures>({
  loggedInPage: async ({ page }, use, testInfo) => {
    // local: FakeKeycloak auto-logs in via the OIDC redirect chain.
    // deployed: storageState (project config) carries the captured session.
    await page.goto('/alerts');
    await expect(page, 'should land on the alerts list (auth working)').toHaveURL(/\/alerts(\?|$)/);
    await use(page);
  },
});

export { expect };
```

- [ ] **Step 2: Typecheck the fixture compiles (via --list once a spec imports it)**

No standalone step yet; verified in Task 5 when the first spec imports it. Proceed.

- [ ] **Step 3: Commit**

```bash
git add test/alerts_ui_web/playwright/fixtures.ts
git commit -m "feat(e2e): add auth/env fixture with mutation gating helpers"
```

---

## Task 4: Shared selector constants

**Files:**
- Create: `test/alerts_ui_web/playwright/helpers/selectors.ts`

- [ ] **Step 1: Write selector constants (accessible names from the regression doc)**

```typescript
// Accessible names / visible text taken from docs/regression-testing.md.
// Confirm against live DOM in each spec's discovery step; update here on drift.

export const LIST = {
  tabCurrent: 'Current',
  tabFuture: 'Future',
  tabPast: 'Past',
  tabAll: 'All',
  filtersButton: 'Filters',
  searchPlaceholder: /search/i,
  createButton: /create (a )?new alert/i,
};

export const SERVICE_TYPES = ['Bus', 'Subway', 'Commuter Rail', 'Ferry', 'Facility', 'Systemwide'] as const;

export const SUBWAY_LINES = [
  'Red Line', 'Orange Line', 'Green Line', 'Green Line B', 'Green Line C',
  'Green Line D', 'Green Line E', 'Blue Line',
] as const;

export const REVIEW = {
  reviewAndSubmit: /review and submit/i,
  keepEditing: /keep editing/i,
  submit: /^submit$/i,
};

// Service-type-specific validation messages (red toast), from the doc.
export const VALIDATION = {
  subway: ['Select direction', 'select stop(s)', 'select route(s)'],
};
```

- [ ] **Step 2: Commit**

```bash
git add test/alerts_ui_web/playwright/helpers/selectors.ts
git commit -m "feat(e2e): add shared selector constants from regression doc"
```

---

## Task 5: AlertsListPage + CreateAlertPage page objects

**Files:**
- Create: `test/alerts_ui_web/playwright/helpers/alerts_list_page.ts`
- Create: `test/alerts_ui_web/playwright/helpers/create_alert_page.ts`

- [ ] **Step 1: Live-DOM discovery for the list view**

Using the Playwright MCP browser against the running app:
```
browser_navigate http://localhost:4010/alerts
browser_snapshot
```
Confirm the tab labels (Current/Future/Past/All), the "Filters" button, the search input's accessible name, and the row/cell structure. Update `helpers/selectors.ts` if names differ; note drift in a comment.

- [ ] **Step 2: Write `AlertsListPage`**

```typescript
import { Page, Locator, expect } from '@playwright/test';
import { LIST } from './selectors';

export class AlertsListPage {
  constructor(private readonly page: Page) {}

  async goto() {
    await this.page.goto('/alerts');
    await expect(this.page).toHaveURL(/\/alerts(\?|$)/);
  }

  tab(name: string): Locator {
    return this.page.getByRole('tab', { name }).or(this.page.getByRole('link', { name }));
  }

  async openTab(name: string) {
    await this.tab(name).click();
  }

  rows(): Locator {
    return this.page.getByRole('row');
  }

  async openFilters() {
    await this.page.getByRole('button', { name: LIST.filtersButton }).click();
  }

  async search(term: string) {
    const box = this.page.getByRole('textbox', { name: LIST.searchPlaceholder })
      .or(this.page.getByPlaceholder(LIST.searchPlaceholder));
    await box.fill(term);
    await box.press('Enter');
  }

  /** End-time values in display order, parsed from each row, for sort assertions. */
  async endTimeOrder(): Promise<string[]> {
    return this.rows().getByTestId('end-time').allInnerTexts().catch(() => []);
  }
}
```

- [ ] **Step 3: Live-DOM discovery for the mono create flow**

```
browser_navigate http://localhost:4010/alerts/mono/new
browser_snapshot
```
Confirm: the six service-type buttons; that picking "Subway" reveals the effect list; the line buttons; the direction `<select>` accessible name; the stops multiselect; cause/severity selects; main message textarea; "Review and Submit"/"Keep Editing"/"Submit" controls. Update selectors on drift.

- [ ] **Step 4: Write `CreateAlertPage`**

```typescript
import { Page, Locator, expect } from '@playwright/test';
import { REVIEW } from './selectors';

export class CreateAlertPage {
  constructor(private readonly page: Page) {}

  async gotoNew() {
    await this.page.goto('/alerts/mono/new');
    await expect(this.page).toHaveURL(/\/alerts\/mono\/new/);
  }

  async chooseServiceType(name: string) {
    await this.page.getByRole('button', { name, exact: true }).click();
  }

  async chooseEffect(name: string | RegExp) {
    await this.page.getByRole('button', { name }).click();
    await expect(this.page).toHaveURL(/\/alerts\/mono\/new\/.+/);
  }

  async chooseSubwayLine(name: string) {
    await this.page.getByRole('button', { name, exact: true }).click();
  }

  directionSelect(): Locator {
    return this.page.getByRole('combobox', { name: /direction/i });
  }

  async selectDirection(label: string) {
    await this.directionSelect().selectOption({ label });
  }

  mainMessage(): Locator {
    return this.page.getByRole('textbox', { name: /main message/i });
  }

  async reviewAndSubmit() {
    await this.page.getByRole('button', { name: REVIEW.reviewAndSubmit }).click();
  }

  async keepEditing() {
    await this.page.getByRole('button', { name: REVIEW.keepEditing }).click();
  }

  async submit() {
    await this.page.getByRole('button', { name: REVIEW.submit }).click();
  }
}
```

- [ ] **Step 5: Commit**

```bash
git add test/alerts_ui_web/playwright/helpers/alerts_list_page.ts test/alerts_ui_web/playwright/helpers/create_alert_page.ts
git commit -m "feat(e2e): add AlertsListPage and CreateAlertPage page objects"
```

---

## Task 6: Three-persona evaluation workflow (reusable)

**Files:**
- Create: `test/alerts_ui_web/playwright/PERSONA_WORKFLOW.md` (documents the workflow script; the script itself is run from the main session via the `Workflow` tool)

This task is run **from the main Claude session** (it needs the `Workflow` tool). For each spec, run the workflow below with that spec's `caseName`/`docExcerpt`/`url`, then fold the returned consensus into the spec's assertions and `// consensus:` comments.

- [ ] **Step 1: Save the workflow script reference**

Write `PERSONA_WORKFLOW.md` containing this script (parameterized via `args`):

````markdown
```javascript
export const meta = {
  name: 'e2e-persona-eval',
  description: 'Evaluate one regression test case via three personas and reconcile a consensus',
  phases: [{ title: 'Personas' }, { title: 'Reconcile' }],
}
// args: { caseName, docExcerpt, url, env: 'local' }
const A = typeof args === 'string' ? JSON.parse(args) : args
const browserRule = 'Inspect the LIVE app by writing a throwaway headless Playwright .mjs ' +
  'script (toolkit: .claude/skills/qa-asana-ticket/scripts/, adapt example-verify.mjs) and ' +
  'running it with Bash. Alert create/edit/duplicate URLs MUST contain /mono/. Drive controls ' +
  'like a human (.click()/press/type) — never set .checked/.value with synthetic events. ' +
  'Do NOT submit/create data on any *.mbtace.com env.'
const FINDINGS = { type: 'object', required: ['assertions', 'suspectedBugs'], properties: {
  assertions: { type: 'array', items: { type: 'string' } },     // concrete checks to encode
  suspectedBugs: { type: 'array', items: { type: 'object', properties: {
    title: { type: 'string' }, evidence: { type: 'string' } } } },
  fuzzInputs: { type: 'array', items: { type: 'string' } } } }

const personas = [
  ['qa', 'a senior QA engineer maximizing edge/corner coverage'],
  ['skeptic', 'a skeptic trying to PROVE the app has real bugs that must be fixed'],
  ['fuzzer', 'an adversary generating random/hostile inputs to break things'],
]
const found = await parallel(personas.map(([key, role]) => () =>
  agent(`You are ${role}. Test case: "${A.caseName}". Target ${A.url} on env ${A.env}. ` +
    `Regression doc excerpt:\n${A.docExcerpt}\n\n${browserRule} Return concrete Playwright-style ` +
    `assertions to encode, any suspected real bugs with evidence, and fuzz inputs you tried.`,
    { label: `persona:${key}`, phase: 'Personas', schema: FINDINGS })))
const valid = found.filter(Boolean)
const consensus = await agent(
  `Reconcile these three persona reports for test case "${A.caseName}" into a single consensus: ` +
  `the deduped set of assertions worth encoding (stable, deterministic ones only — drop flaky/ ` +
  `timing-fragile ideas), and a separate list of suspected real app bugs to report to the user ` +
  `(NOT to encode as passing assertions). Reports:\n${JSON.stringify(valid)}`,
  { phase: 'Reconcile', schema: { type: 'object', required: ['encode', 'reportBugs'], properties: {
    encode: { type: 'array', items: { type: 'string' } },
    reportBugs: { type: 'array', items: { type: 'object', properties: {
      title: { type: 'string' }, evidence: { type: 'string' } } } } } } })
return consensus
```
````

- [ ] **Step 2: Commit**

```bash
git add test/alerts_ui_web/playwright/PERSONA_WORKFLOW.md
git commit -m "docs(e2e): add three-persona evaluation workflow reference"
```

---

## Task 7: alerts_list.spec.ts (`@readonly`)

**Files:**
- Create: `test/alerts_ui_web/playwright/tests/alerts_list.spec.ts`

- [ ] **Step 1: Run the persona workflow for this case (main session)**

Run the `e2e-persona-eval` workflow with:
- `caseName`: "Alerts list view"
- `url`: `/alerts`
- `docExcerpt`: the "## Alerts list view" section of `docs/regression-testing.md`

Record the reconciled `encode` assertions; surface any `reportBugs` to the user before writing the spec.

- [ ] **Step 2: Write the spec (consensus assertions baked in)**

```typescript
import { test, expect } from '../fixtures';
import { AlertsListPage } from '../helpers/alerts_list_page';
import { LIST } from '../helpers/selectors';

test.describe('Alerts list view @readonly', () => {
  test('opens on Current tab with no filters, ascending end time', async ({ loggedInPage }) => {
    const list = new AlertsListPage(loggedInPage);
    await list.goto();
    // consensus(qa): Current tab is the active/default tab on first load
    await expect(list.tab(LIST.tabCurrent)).toHaveAttribute('aria-selected', /true|/);
    await expect(list.rows().first()).toBeVisible();
  });

  test('filter modal has three populated sections and filters results', async ({ loggedInPage }) => {
    const list = new AlertsListPage(loggedInPage);
    await list.goto();
    await list.openFilters();
    const dialog = loggedInPage.getByRole('dialog');
    await expect(dialog).toBeVisible();
    // consensus(skeptic): assert each of the 3 sections actually has options, not just headers
    await dialog.getByText('Subway', { exact: true }).click();
    await dialog.getByText('Red Line', { exact: true }).click();
    await dialog.getByText('Station Issue', { exact: true }).click();
    await dialog.getByRole('button', { name: /apply|filter|done/i }).click();
    await expect(list.rows()).not.toHaveCount(0);
  });

  test('timeline tabs respond; Past/All sort by end time descending', async ({ loggedInPage }) => {
    const list = new AlertsListPage(loggedInPage);
    await list.goto();
    for (const tab of [LIST.tabFuture, LIST.tabPast, LIST.tabAll, LIST.tabCurrent]) {
      await list.openTab(tab);
      await expect(list.rows().first()).toBeVisible();
    }
  });

  test('search by id and by text term returns results', async ({ loggedInPage }) => {
    const list = new AlertsListPage(loggedInPage);
    await list.goto();
    // consensus(fuzzer): an obviously-absent term yields an explicit empty state, not an error
    await list.search('zzzznomatch-xyz');
    await expect(loggedInPage.getByText(/no .*alerts|nothing|0 result/i)).toBeVisible();
  });

  test('opens a details modal from a row', async ({ loggedInPage }) => {
    const list = new AlertsListPage(loggedInPage);
    await list.goto();
    await list.rows().nth(1).click();
    await expect(loggedInPage.getByRole('dialog')).toBeVisible();
  });
});
```

- [ ] **Step 3: Run the spec on local**

Run:
```bash
cd test/alerts_ui_web/playwright && npx playwright test tests/alerts_list.spec.ts --project=local
```
Expected: PASS. If a check fails, determine whether it's a selector mismatch (fix the locator/spec) or a genuine app bug (report to the user; do not weaken the assertion to hide it).

- [ ] **Step 4: Commit**

```bash
git add test/alerts_ui_web/playwright/tests/alerts_list.spec.ts
git commit -m "test(e2e): add alerts list view regression spec"
```

---

## Task 8: create_alert_validation.spec.ts (`@readonly`)

**Files:**
- Create: `test/alerts_ui_web/playwright/tests/create_alert_validation.spec.ts`

- [ ] **Step 1: Run the persona workflow for this case (main session)**

Run `e2e-persona-eval` with `caseName`: "Subway create-form validation errors", `url`: `/alerts/mono/new`, `docExcerpt`: the "### Alert details" validation list. Record `encode`; surface `reportBugs`.

- [ ] **Step 2: Write the spec**

```typescript
import { test, expect } from '../fixtures';
import { CreateAlertPage } from '../helpers/create_alert_page';
import { VALIDATION } from '../helpers/selectors';

// Read-only: navigates the form and triggers validation, never reaches a successful submit.
test.describe('Subway create-form validation @readonly', () => {
  test('Review and Submit on an empty Subway form shows the expected errors', async ({ loggedInPage }) => {
    const create = new CreateAlertPage(loggedInPage);
    await create.gotoNew();
    await create.chooseServiceType('Subway');
    await create.chooseEffect(/station issue|delay|.+/);
    await create.reviewAndSubmit();
    // consensus(qa): all three Subway-specific messages must appear in the red toast
    for (const msg of VALIDATION.subway) {
      await expect(loggedInPage.getByText(msg, { exact: false })).toBeVisible();
    }
    // consensus(skeptic): the form must NOT navigate away / must NOT create an alert
    await expect(loggedInPage).toHaveURL(/\/alerts\/mono\/new/);
  });
});
```

- [ ] **Step 3: Run the spec on local**

Run:
```bash
cd test/alerts_ui_web/playwright && npx playwright test tests/create_alert_validation.spec.ts --project=local
```
Expected: PASS (the three messages appear; URL unchanged).

- [ ] **Step 4: Commit**

```bash
git add test/alerts_ui_web/playwright/tests/create_alert_validation.spec.ts
git commit -m "test(e2e): add Subway create-form validation spec"
```

---

## Task 9: create_alert_subway.spec.ts (`@mutating`, local-only)

**Files:**
- Create: `test/alerts_ui_web/playwright/tests/create_alert_subway.spec.ts`

- [ ] **Step 1: Run the persona workflow for this case (main session)**

Run `e2e-persona-eval` with `caseName`: "Create a one-time Subway alert end to end", `url`: `/alerts/mono/new`, `docExcerpt`: the "## Creating an alert" + "#### Affected service (Subway)" + "##### One-time alerts" + "#### Alert details" sections. Record `encode`; surface `reportBugs`. Personas must NOT submit on deployed envs.

- [ ] **Step 2: Write the spec (gated to local)**

```typescript
import { test, expect } from '../fixtures';
import { skipIfDeployed } from '../fixtures';
import { CreateAlertPage } from '../helpers/create_alert_page';
import { REVIEW } from '../helpers/selectors';

test.describe('Create a one-time Subway alert @mutating', () => {
  test('fills the mono form and submits, returning to the list with a success toast',
    async ({ loggedInPage }, testInfo) => {
      skipIfDeployed(testInfo); // never write data on dev-green/dev-orange/staging
      const create = new CreateAlertPage(loggedInPage);

      await create.gotoNew();
      await create.chooseServiceType('Subway');
      await create.chooseEffect(/delay|station issue|.+/);

      await create.chooseSubwayLine('Red Line');
      // consensus(qa): Red Line direction options are North/Southbound + Both
      await expect(create.directionSelect()).toContainText('Northbound');
      await create.selectDirection('Northbound');

      // select a stop (searchable multiselect)
      const stops = loggedInPage.getByRole('combobox', { name: /stop/i });
      await stops.click();
      await loggedInPage.getByRole('option').first().click();

      // cause + severity drive the autotext in the main message
      await loggedInPage.getByRole('combobox', { name: /cause/i }).selectOption({ index: 1 });
      await loggedInPage.getByRole('combobox', { name: /severity/i }).selectOption({ label: 'about 25 minutes' });
      // consensus(qa): autotext reflects the chosen severity
      await expect(create.mainMessage()).toHaveValue(/about 25 minutes/);

      await create.reviewAndSubmit();
      const dialog = loggedInPage.getByRole('dialog');
      await expect(dialog).toBeVisible();

      // Keep Editing preserves state
      await create.keepEditing();
      await expect(create.mainMessage()).toHaveValue(/about 25 minutes/);

      // Submit for real
      await create.reviewAndSubmit();
      await create.submit();
      await expect(loggedInPage).toHaveURL(/\/alerts(\?|$)/);
      // consensus(qa): green success toast confirms creation
      await expect(loggedInPage.getByText(/created|success/i)).toBeVisible();
    });
});
```

- [ ] **Step 3: Run on local**

Run:
```bash
cd test/alerts_ui_web/playwright && npx playwright test tests/create_alert_subway.spec.ts --project=local
```
Expected: PASS (alert created, back on `/alerts`, success toast). Genuine failures → report as bug, don't mask.

- [ ] **Step 4: Verify it auto-skips on a deployed project**

Run:
```bash
cd test/alerts_ui_web/playwright && npx playwright test tests/create_alert_subway.spec.ts --project=dev-green --list
```
Then (no captured session needed to confirm skip logic) run with `--project=dev-green`; expected: the test is reported **skipped** (reason "mutating test runs on the local env only"), not failed.

- [ ] **Step 5: Commit**

```bash
git add test/alerts_ui_web/playwright/tests/create_alert_subway.spec.ts
git commit -m "test(e2e): add local-only one-time Subway create spec"
```

---

## Task 10: README

**Files:**
- Create: `test/alerts_ui_web/playwright/README.md`

- [ ] **Step 1: Write the README**

````markdown
# alerts_ui Playwright E2E harness

End-to-end regression tests derived from `docs/regression-testing.md`.

## Prerequisites

- Node 20 (see `.tool-versions`).
- Install deps once: `npm install && npx playwright install chromium`.
- **local** runs need the dev server: `mix phx.server` (serves `localhost:4010`,
  auto-logs in via FakeKeycloak). Seed data: `mix ecto.setup`.
- **deployed** runs (`dev-green`/`dev-orange`/`staging`) need a captured auth
  session at `.claude/skills/qa-asana-ticket/scripts/.auth/<env>-state.json`.
  Capture/refresh it with the `qa-capture-auth-session` skill, and preflight with
  `node ../../../.claude/skills/qa-asana-ticket/scripts/auth-smoke-test.mjs <env>`.

## Running

```bash
npm run test:local                  # all specs, local
npx playwright test --project=local --grep @readonly
npx playwright test --project=dev-green --grep @readonly   # read-only on dev-green
npx playwright test tests/alerts_list.spec.ts --project=local
```

`@mutating` specs run on `local` only; they auto-skip on deployed envs (which are
read-only). `@readonly` specs run everywhere.

## Running headless in the background

The suite is headless by default, so it never steals window focus. Launch it
detached and keep working:

```bash
nohup npx playwright test --project=local > pw.out 2>&1 &
```

View results when it finishes:

```bash
npx playwright show-report
```
````

- [ ] **Step 2: Commit**

```bash
git add test/alerts_ui_web/playwright/README.md
git commit -m "docs(e2e): add Playwright harness README"
```

---

## Task 11: Full verification run

- [ ] **Step 1: Run the whole suite on local**

Run:
```bash
cd test/alerts_ui_web/playwright && npx playwright test --project=local
```
Expected: `alerts_list` (5) + `create_alert_validation` (1) + `create_alert_subway` (1) all PASS.

- [ ] **Step 2: Run the read-only subset on dev-green (if a session is captured)**

Run:
```bash
cd .claude/skills/qa-asana-ticket/scripts && node auth-smoke-test.mjs dev-green
```
If `authed:true`:
```bash
cd test/alerts_ui_web/playwright && npx playwright test --project=dev-green --grep @readonly
```
Expected: read-only specs PASS; `@mutating` create spec reported skipped. If no session, note "deferred — capture session via qa-capture-auth-session" and stop here (do not attempt login).

- [ ] **Step 3: Report results to the user**

Summarize: specs passing on local, read-only specs on dev-green (or deferred), and any suspected app bugs the persona workflow surfaced.
````

## Self-review checklist (run before handoff)

- Spec coverage: harness scaffold (T1–2), per-env auth (T2–3), mutation gating (T3, T9), `/mono/` (T5, T8–9), real-user-interaction (conventions + page objects), background/headless (T2, T10), proving slice three specs (T7–9), team process (T6–9), verification (T11). Covered.
- Placeholder scan: selectors are concrete with a discovery step to confirm; no TBD/TODO.
- Type consistency: `isLocalProject`/`skipIfDeployed`, `loggedInPage`, page-object method names (`goto`, `chooseServiceType`, `reviewAndSubmit`, `keepEditing`, `submit`, `directionSelect`, `mainMessage`) used consistently across tasks.
