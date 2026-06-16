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

The harness must run **headless and in the background** so a developer can keep
using their machine while a suite runs, and must be able to target **multiple
environments** (local plus the deployed dev/staging environments) for richer QA.

## Context / findings

- **No Playwright infrastructure exists** anywhere in the repo or any branch:
  no `@playwright/test` dependency, no config, no `test/alerts_ui_web/playwright`
  directory. This is greenfield. (A bare `playwright` runtime package is
  installed under `.claude/skills/qa-asana-ticket/scripts/node_modules` for the
  QA toolkit, but not the `@playwright/test` runner.)
- **Local auth is automatic.** `config/dev.exs` wires
  `Ueberauth.Strategy.FakeKeycloak`, which logs in a single user with all roles
  (`viewer`, `author`, `developer`). No login UI to drive locally; the doc's
  "Logging in" section is N/A locally.
- **Test env has `server: false`** (`config/test.exs`), so existing ExUnit /
  LiveView tests run in-process. Playwright needs a *real* running server.
- **Two create flows exist.** Older `CreateAlertLive` (`/alerts/new/...`) and
  newer `CreateAlertMonoLive` (`/alerts/mono/...`). Edit and Duplicate from the
  list view both navigate to the `mono` flow.
- **Specific seeded records referenced by the doc are not in local seeds.**
  `688220` and `alert 4` (GTFS-missing warning) appear nowhere in
  `priv/repo/seeds.exs` or the codebase; they exist only in real/staging data.
  Those duplication cases are excluded from the proving slice.

These constraints are sourced from the existing QA skills
(`.claude/skills/qa-asana-backlog`, `qa-asana-ticket`,
`qa-capture-auth-session`) and their scripts; the harness deliberately reuses
their conventions.

## Approach

`@playwright/test` (Node/TypeScript), self-contained under
`test/alerts_ui_web/playwright/`. Chosen over raw `playwright` `.mjs` scripts
(the style of the `qa-asana-ticket` toolkit) because a durable regression
*suite* benefits from per-environment projects, tag-based selection, the HTML
reporter, traces, retries, and parallel workers. It still runs fully headless
and backgroundable, and it reuses the QA toolkit's captured `.auth` sessions.

Selectors are authored against a **live running server via the Playwright MCP
browser** during development, then encoded into deterministic spec files. This
avoids guessing DOM structure.

## Target environments

| env (project) | Base URL | Auth |
|---------------|----------|------|
| `local` (default) | `http://localhost:4010/` | FakeKeycloak auto-login, no session file |
| `dev-green` | `https://alerts-manager-dev-green.mbtace.com/` | captured Keycloak session |
| `dev-orange` | `https://alerts-manager-dev-orange.mbtace.com/` | captured Keycloak session |
| `staging` | `https://alerts-manager-staging.mbtace.com/` | captured Keycloak session |

Environment is selected per run via `--project=<env>`; the default is `local`.
Each Playwright `project` sets its own `baseURL` and (for deployed envs) its
`storageState`.

## Authentication per environment

- **local:** nothing to do — FakeKeycloak auto-logs in with all roles.
- **deployed (dev-green / dev-orange / staging):** behind a real Keycloak wall.
  Playwright loads `storageState` from the existing convention
  `.claude/skills/qa-asana-ticket/scripts/.auth/<env>-state.json` (gitignored,
  `chmod 600`). Sessions are captured/refreshed by **reusing** the
  `qa-capture-auth-session` skill: the user logs in headed once and Claude never
  holds or types credentials. Sessions expire in ~10h.
- Before a deployed run, smoke-test the session with
  `cd .claude/skills/qa-asana-ticket/scripts && node auth-smoke-test.mjs <env>`.
  If the state file is missing or expired, the run **fails fast** with a message
  pointing to `qa-capture-auth-session` — it never attempts to log in.

## Constraints

- **Deployed envs are READ-ONLY.** dev-green / dev-orange / staging must never
  have data created, edited, or deleted. Each spec is tagged:
  - `@readonly` — list view, filters, search, navigating the create form, form
    validation, review-modal preview → run on **all** envs.
  - `@mutating` — anything that hits **Submit** (create), plus future
    edit/close/duplicate-save → **auto-skip on deployed envs; local only.**

  Mutation gating is enforced in the spec (skip when the active project is not
  `local`), so a deployed run silently and safely skips mutating cases rather
  than writing data.
- **`/mono/` URLs.** All alert create/edit/duplicate flows drive
  `/alerts/mono/...`, verifying the new mono form against the doc's
  requirements. The create spec targets `/alerts/mono/new`.
- **Real user interaction, never synthetic DOM mutation.** Page objects drive
  controls the way a human would (`.click()`, real `press`/`type`); they never
  set `element.checked` / `element.value` and dispatch synthetic
  `input`/`change` events — LiveView ignores those and they read as phantom
  application bugs. Reading state via JS is fine.

## Background execution

- **Headless by default**, so runs never steal window focus and the developer
  can keep working while a suite runs.
- Runs are launchable in the **background** (Bash `run_in_background`, or
  `npx playwright test` detached). The HTML report and traces are collected on
  completion for later review.
- This mirrors the QA toolkit's "private headless browser per process — no
  shared MCP/tab contention," which keeps parallel and background runs safe.

## Harness components

- `test/alerts_ui_web/playwright/package.json` — pins `@playwright/test`, adds a
  `test` script. Reuses already-installed browser binaries where present.
- `test/alerts_ui_web/playwright/playwright.config.ts` — headless default;
  `projects` for `local` / `dev-green` / `dev-orange` / `staging`, each setting
  `baseURL` and (deployed only) `storageState` from the `.auth/<env>-state.json`
  path; `trace: 'on-first-retry'`; HTML reporter. No `webServer` auto-spawn in
  the first cut; the README documents that `mix phx.server` must be running for
  `local`.
- **Auth/env fixture** — resolves the active project, asserts the session lands
  on `/alerts` (auto-login locally; storageState for deployed), and exposes a
  `loggedInPage` fixture plus an `isLocal` helper for mutation gating.
- **Page objects** in `helpers/` — `AlertsListPage`, `CreateAlertPage`
  (service type -> effect -> details -> review -> submit, all under `/mono/`),
  plus shared selector constants. Page objects encode the real-user-interaction
  rule.
- `test/alerts_ui_web/playwright/README.md` — prerequisites (`mix phx.server`
  for local, `mix ecto.setup` seeds, captured `.auth` session for deployed),
  how to run a single env, how to run headless in the background, and where the
  HTML report lands.

## Proving slice (this deliverable)

1. **Alerts list view** (`alerts_list.spec.ts`, `@readonly`)
   - Opens on the Current tab, no filters selected, ordered by ascending end
     time.
   - Pagination: go to the last page and back.
   - Filter modal: all three sections populated; apply Subway / Red Line /
     Station Issue; assert results are filtered.
   - Timeline tabs: Current, Future, Past, All respond; Past and All sort by end
     time descending.
   - Search: by alert id, and by text term.
   - Open a details modal from a row.

2. **One full create flow** (`create_alert_subway.spec.ts`, `@mutating`,
   local-only)
   - Navigate the `/alerts/mono/new` Subway flow: select a line, direction, and
     stop(s).
   - One-time timeframe (defaults).
   - Select a cause and severity; assert main-message autotext updates
     accordingly.
   - Fill main message; confirm delivery checkbox.
   - Review & Submit -> review modal shows selections.
   - Keep Editing -> modal closes, form state preserved.
   - Review & Submit -> Submit -> redirected to list with a green success toast.

3. **Validation case** (`create_alert_validation.spec.ts`, `@readonly`)
   - Subway form at `/alerts/mono/new`, Review & Submit with nothing entered.
   - Assert the service-type-specific red-toast errors: "Select direction,
     select stop(s), select route(s)". (Read-only: never reaches Submit success,
     so safe on deployed envs.)

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

- "Logging in" section — N/A locally (auto-login); deployed login is handled by
  the captured-session flow, not driven by tests.
- Duplication of `688220` / `alert 4` — not in local seeds; environment-dependent.
- Out of scope this slice (follow-ups once the harness is proven): full
  six-service-type matrix, recurring deep-dive, rider reminders, editing,
  closing, duplicating, banner text, history downloads.

## Testing / verification

The harness is proven when:
- the `@readonly` specs pass on **`local`** *and* on **`dev-green`** (with a
  captured session), via `npx playwright test --project=<env>` from
  `test/alerts_ui_web/playwright/`; and
- the `@mutating` create-flow spec passes on **`local`** and **auto-skips** on
  deployed envs.
