# Playwright E2E harness — proving-slice report

Date: 2026-06-17
Branch: `jy-playwright`
Spec: `docs/superpowers/specs/2026-06-16-playwright-e2e-harness-design.md`
Plan: `docs/superpowers/plans/2026-06-17-playwright-e2e-harness.md`

## What shipped

A headless, multi-environment `@playwright/test` harness under
`test/alerts_ui_web/playwright/` plus a proving slice of **7 tests, all green
and stable** (verified 5× with `--repeat-each`, 35/35):

- `alerts_list.spec.ts` (`@readonly`) — default Current tab, timeline switching,
  filter modal (three populated sections + an applied filter), search by id and
  empty state, details modal.
- `create_alert_validation.spec.ts` (`@readonly`) — empty Subway Review&Submit
  shows "Please fix the following errors: Select stop(s)" and does not advance.
- `create_alert_subway.spec.ts` (`@mutating`, local-only) — full mono
  Subway/Station-issue create → review → Keep editing → submit → new alert on
  the list. Auto-skips on deployed environments.

Harness: per-environment projects (`local` / `dev-green` / `dev-orange` /
`staging`); `storageState` reused from the `qa-asana-ticket` `.auth` store (only
attached when present); page objects that wait for
`[data-phx-main].phx-connected` and drive controls like a human (no synthetic
DOM mutation); a README; and the three-persona workflow reference
(`PERSONA_WORKFLOW.md`).

## The three-persona team

The QA / bug-hunting-skeptic / random-input-fuzzer workflow ran against the live
app for two cases (list view and create flow). Consensus assertions were baked
into the specs; bugs are reported below rather than encoded as passing tests.

One initially-suspected "crash" on empty submit was a **false alarm** — Phoenix's
always-present *hidden* error overlay — confirmed before reporting.

## Real bugs surfaced (not encoded — for triage)

### Alerts list view

1. `?order_by=` / `?order_direction=` with unknown values → blank total count and
   an empty "No alerts found" table instead of being validated/defaulted.
   `String.to_existing_atom` is called on the raw user-controlled params
   (`lib/alerts_ui_web/live/view_alerts_live.ex` ~line 97 and ~line 549). A
   PAGEERROR was also observed. Recommend whitelisting against known
   fields/directions and falling back to the default.
2. Multi-column search uses SQL `LIKE` wildcards **without escaping**: `%`
   returns every row and `_` matches any single character. Not SQL injection
   (values are parameterized — `'; DROP TABLE alerts;--` safely returns 0 rows);
   a `LIKE`-pattern-escaping gap. Recommend escaping `%` and `_` in the user term.
3. Search typed immediately after page load is **intermittently dropped** — the
   first 750ms-debounced `phx-change` fires before the LiveView socket settles,
   leaving the table unfiltered until another event re-triggers the query.
   (The harness mitigates this by waiting for `phx-connected` before typing.)
4. Non-numeric `?page=abc` blanks the table, whereas out-of-range pages
   (`?page=99999`, `?page=-1`) are safely ignored — inconsistent handling.
5. Returning to `/alerts` after navigating away can render an empty list with no
   active filter (remount/initial-query timing). Observed once.
6. Timeline tabs are `class="hidden"` radio inputs with no `label[for]`
   association → excluded from the accessibility tree; `getByRole('radio')` finds
   nothing and screen-reader users can't perceive the tab group/selection.

### Create form (mono)

7. Subway **Direction select is labeled "Stops"** and the real Stops multiselect
   has no label. Confirmed in
   `lib/alerts_ui_web/live/create_alert_mono_live/slices/affected_service_slice.ex:618`
   (direction label) and `:626` (stops label). Screen-reader users hear the
   direction dropdown announced as "Stops"; the stops list is unlabeled.
8. The required main message has **no visible validation feedback** when Review
   is blocked: with a line selected and the message empty, clicking Review does
   nothing observable (no modal, no `aria-invalid`, no message).
9. Default main-message autotext is **malformed before a line is selected**
   (`": delays of."` — leading colon, no route prefix). Corrected once a line is
   chosen.
10. Char counter (counts codepoints/graphemes) and the `maxlength=255` cap
    (UTF-16 length) use **different length semantics** for multi-code-unit
    characters (e.g. emoji) — the displayed remaining count can disagree with the
    enforced limit. Low severity.
11. The Direction option list can **transiently collapse to only "Both
    Directions"** right after a rapid line change, because `direction_options` is
    server-computed and loaded async. Timing window, not a hard bug.

### Doc discrepancy

Default severity is not always "about 15 minutes" as the regression doc states:
Station Issue defaults to "information"; Delay defaults to "about 10 minutes"
(value `3`). Minor doc inaccuracy.

## Demonstrator tests

Three of these bugs now have executable demonstrators (they assert the intended
behavior, so they stay red until fixed):

- `test/alerts_ui/models/custom_filters_known_bugs_test.exs` — unescaped `LIKE`
  wildcard in search (`@tag :known_bug`).
- `test/alerts_ui_web/live/view_alerts_order_param_known_bug_test.exs` — unknown
  `order_by` param crashes via `String.to_existing_atom` (`@tag :known_bug`).
- `test/alerts_ui_web/playwright/tests/known_bugs.spec.ts` — Subway Direction
  control mislabeled "Stops" (`test.fail()`, `@bug`).

The ExUnit ones are excluded from the default suite (`mix test --include
known_bug` to run them); the Playwright one is an expected failure, so the suite
stays green and flips to an "unexpected pass" when the bug is fixed.

## Operational notes

- **Node:** run on the repo's pinned Node 20 (or ≤ 22). Node **23.x breaks**
  Playwright's test-file loader (`context.conditions?.includes is not a
  function`). Documented in the harness README.
- The `@mutating` create spec writes data on **local only**; repeated runs leave
  "Station issue at Alewife." alerts in the local dev DB. `mix ecto.reset` clears
  them.
- Deployed read-only verification needs a captured session via the
  `qa-capture-auth-session` skill (dev-green/orange/staging are read-only).

## Deferred (per the approved plan)

Full six-service-type matrix; recurring alerts; rider reminders; editing,
closing, and duplicating; banner text; history downloads; and deployed
read-only verification once a session is captured.
