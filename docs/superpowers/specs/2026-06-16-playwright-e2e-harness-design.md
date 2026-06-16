# Playwright E2E harness + proving slice for alerts_ui

Date: 2026-06-16
Status: Approved (design)

## Goal

Stand up a Playwright end-to-end testing harness for the alerts_ui Phoenix
LiveView app, and produce a first "proving slice" of E2E tests derived from
`docs/regression-testing.md`.

Each test case is shaped by a three-persona evaluation — a QA coverage
engineer, a bug-hunting skeptic, and a random-input fuzzer — whose reconciled
consensus is baked directly into the generated test as assertions and brief
`// consensus:` comments. This first slice proves the harness end to end before
the full regression document is mechanically expanded into tests.

## Context / findings

- **No Playwright infrastructure exists** anywhere in the repo or any branch:
  no `@playwright/test` dependency, no config, no `test/alerts_ui_web/playwright`
  directory. This is greenfield.
- **Local auth is automatic.** `config/dev.exs` wires
  `Ueberauth.Strategy.FakeKeycloak`, which logs in a single user with all roles
  (`viewer`, `author`, `developer`). No login UI to drive locally; the doc's
  "Logging in" section is N/A locally.
- **Dev server** runs at `http://localhost:4010` (`config/dev.exs`) and is
  currently running.
- **Test env has `server: false`** (`config/test.exs`), so existing ExUnit /
  LiveView tests run in-process. Playwright needs a *real* running server —
  hence we target the dev server.
- **Two create flows exist.** Older `CreateAlertLive` (`/alerts/new/...`) and
  newer `CreateAlertMonoLive` (`/alerts/mono/...`). Edit and Duplicate from the
  list view both navigate to the `mono` flow. The exact "Create a new alert"
  entry point will be resolved by driving the running app, not by guessing from
  static routing.
- **Specific seeded records referenced by the doc are not in local seeds.**
  `688220` and `alert 4` (GTFS-missing warning) appear nowhere in
  `priv/repo/seeds.exs` or the codebase; they exist only in real/staging data.
  Those duplication cases are excluded from the proving slice.

## Approach

`@playwright/test` (Node/TypeScript), self-contained under
`test/alerts_ui_web/playwright/`.

Rejected alternatives:
- **Elixir `playwright` hex package** driven from ExUnit — weaker ecosystem,
  and the deliverable is described as a "Playwright test."
- **Playwright MCP only** — not a committed, runnable artifact.

Selectors are authored against the **live running server via the Playwright MCP
browser** during development, then encoded into deterministic spec files. This
avoids guessing DOM structure.

## Harness components

- `test/alerts_ui_web/playwright/package.json` — pins `@playwright/test`, adds a
  `test` script.
- `test/alerts_ui_web/playwright/playwright.config.ts` —
  `baseURL: http://localhost:4010`, single Chromium project,
  `trace: 'on-first-retry'`. No `webServer` auto-spawn in the first cut; the
  README documents that `mix phx.server` must be running.
- **Auth fixture** — navigates and asserts the session lands on `/alerts`
  (FakeKeycloak auto-login). Exposed as a `loggedInPage` fixture.
- **Page objects** in `helpers/` — `AlertsListPage`, `CreateAlertPage`
  (service type -> effect -> details -> review -> submit), plus shared selector
  constants.
- `test/alerts_ui_web/playwright/README.md` — prerequisites (`mix phx.server`
  running, `mix ecto.setup` seeds present) and how to run.

## Proving slice (this deliverable)

1. **Alerts list view** (`alerts_list.spec.ts`)
   - Opens on the Current tab, no filters selected, ordered by ascending end
     time.
   - Pagination: go to the last page and back.
   - Filter modal: all three sections populated; apply Subway / Red Line /
     Station Issue; assert results are filtered.
   - Timeline tabs: Current, Future, Past, All respond; Past and All sort by end
     time descending.
   - Search: by alert id, and by text term.
   - Open a details modal from a row.

2. **One full create flow** (`create_alert_subway.spec.ts`)
   - Subway alert: select a line, direction, and stop(s).
   - One-time timeframe (defaults).
   - Select a cause and severity; assert main-message autotext updates
     accordingly.
   - Fill main message; confirm delivery checkbox.
   - Review & Submit -> review modal shows selections.
   - Keep Editing -> modal closes, form state preserved.
   - Review & Submit -> Submit -> redirected to list with a green success toast.

3. **Validation case** (`create_alert_validation.spec.ts`)
   - Subway form, Review & Submit with nothing entered.
   - Assert the service-type-specific red-toast errors: "Select direction,
     select stop(s), select route(s)".

## Team process (per test case)

A `Workflow` runs the three personas per case against the live DOM:

1. **QA coverage engineer** — maximize edge/corner coverage of the behavior the
   doc describes.
2. **Bug-hunting skeptic** — attempt to prove the app contains real bugs that
   need fixing.
3. **Random-input fuzzer** — generate random/hostile inputs to break things.

Findings are reconciled into a consensus and baked into each spec as assertions
plus brief `// consensus:` comments. Genuine app bugs surfaced by the skeptic or
fuzzer are **reported separately to the user**, not silently encoded into tests.

## Deferred / flagged

- "Logging in" section — N/A locally (auto-login).
- Duplication of `688220` / `alert 4` — not in local seeds; environment-dependent.
- Out of scope this slice (follow-ups once the harness is proven): full
  six-service-type matrix, recurring deep-dive, rider reminders, editing,
  closing, duplicating, banner text, history downloads.

## Testing / verification

The harness is proven when all three proving-slice specs pass against a locally
running `mix phx.server` with default seeds, via
`npx playwright test` from `test/alerts_ui_web/playwright/`.
