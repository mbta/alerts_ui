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
- **deployed** runs (`dev-green` / `dev-orange` / `staging`) sit behind a real
  Keycloak wall. You don't capture a session by hand — `npm run test:<env>`
  opens a **headed browser** and prompts you to log in if no valid session
  exists (see "Running on a deployed environment" below). The session is saved
  to `.claude/skills/qa-asana-ticket/scripts/.auth/<env>-state.json` (gitignored,
  reused for ~10h). You log in yourself; credentials are never handled by the
  tooling — only the resulting session cookies, matching the
  `qa-capture-auth-session` skill.

## Running

```bash
npx playwright test                                  # bare run => local only
npm run test:local                                   # same, explicit
npx playwright test --project=local --grep @readonly # read-only specs only
npx playwright test tests/alerts_list.spec.ts --project=local   # one file
npm run report                                       # open the HTML report
```

A bare `npx playwright test` runs **only the `local` project** — it never
touches the deployed environments, so it can't fail on missing auth. Deployed
projects are engaged only via the `E2E_ENVS` env var, which the `test:<env>`
scripts set for you.

## Running on a deployed environment

```bash
npm run test:dev-green     # = E2E_ENVS=dev-green playwright test --project=dev-green
npm run test:dev-orange
npm run test:staging
```

Each of these first runs a headed `auth-setup` step:

- If a saved session for that env is still valid, it is reused silently.
- Otherwise a browser window opens to the environment's login page and waits up
  to 5 minutes for **you** to sign in. Once you reach the app, the session is
  captured and the specs run.

Add `--grep @readonly` to limit to the read-only specs (recommended on deployed,
since `@mutating` specs skip there anyway):

```bash
E2E_ENVS=dev-green npx playwright test --project=dev-green --grep @readonly
```

Projects: `local` (default), plus `dev-green` / `dev-orange` / `staging` (each
engaged only when named in `E2E_ENVS`).

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
