# alerts_ui Playwright E2E harness

End-to-end regression tests derived from `docs/regression-testing.md`, built with
`@playwright/test`. The suite is headless and multi-environment, and each test
case was shaped by a three-persona evaluation (QA / bug-hunting skeptic /
random-input fuzzer) — see `PERSONA_WORKFLOW.md`.

## Prerequisites

- **Node 20–22.** The repo pins Node 20.10.0 in `.tool-versions` (use it via
  `asdf install`). Note: Node **23.x breaks** Playwright's test-file loader
  (`context.conditions?.includes is not a function`) — do not run the suite on
  Node 23.
- Install once: `npm install && npx playwright install chromium`.
- **local** runs need the dev server: `mix phx.server` (serves
  `localhost:4010`, auto-logs in via `FakeKeycloak` with all roles). Seed data:
  `mix ecto.setup`.
- **deployed** runs (`dev-green` / `dev-orange` / `staging`) need a captured
  Keycloak session at
  `.claude/skills/qa-asana-ticket/scripts/.auth/<env>-state.json`. Capture or
  refresh it with the `qa-capture-auth-session` skill (you log in once; Claude
  never holds credentials), and preflight with
  `cd ../../../.claude/skills/qa-asana-ticket/scripts && node auth-smoke-test.mjs <env>`.
  Without a session, `@readonly` specs can't authenticate and `@mutating` specs
  skip.

## Running

```bash
npm run test:local                                   # whole suite, local
npx playwright test --project=local --grep @readonly # read-only specs only
npx playwright test --project=dev-green --grep @readonly  # read-only on dev-green (needs session)
npx playwright test tests/alerts_list.spec.ts --project=local   # one file
npm run report                                       # open the HTML report
```

Projects: `local` (default target), `dev-green`, `dev-orange`, `staging`.

### Tags and environment safety

- `@readonly` — list view, filters, search, form validation. Runs on **all**
  environments.
- `@mutating` — anything that submits/creates data. Runs on **local only**; it
  auto-skips on the read-only deployed environments (dev-green/orange/staging),
  so a deployed run never writes data.

All alert create/edit/duplicate flows drive `/alerts/mono/...` (the mono form).

## Running headless in the background

The suite is headless by default, so it never steals window focus. Launch it
detached and keep working:

```bash
nohup npx playwright test --project=local > pw.out 2>&1 &
```

When it finishes, review results with `npm run report` (or read `pw.out`).
Failures capture a screenshot and (on retry) a trace under `test-results/`.

## Layout

- `playwright.config.ts` — per-environment projects, headless, modest worker cap
  (the suite drives one stateful LiveView dev server).
- `fixtures.ts` — `loggedInPage` fixture + `isLocalProject` / `skipIfDeployed`.
- `helpers/` — `selectors.ts` (verified selectors), `AlertsListPage`,
  `CreateAlertPage` page objects. Page objects wait for `[data-phx-main].phx-connected`
  before interacting and drive controls like a human (no synthetic DOM mutation).
- `tests/` — the proving-slice specs.
- `PERSONA_WORKFLOW.md` — the three-persona evaluation workflow used to shape the
  specs.
