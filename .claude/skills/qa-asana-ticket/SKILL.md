---
name: qa-asana-ticket
description: QA-verifies a single Asana ticket (bug fix or feature) against a running Alerts UI environment by reproducing its Steps to Reproduce (when present) and checking its Acceptance Criteria with Playwright via a scaled agent team, optionally writing an ExUnit regression test. Use when the user provides an Asana ticket URL or GID and asks to "QA", "verify", "check", or "reproduce" it, or when dispatched per-ticket by the qa-asana-backlog skill. Do NOT use for pulling lists of tickets — use qa-asana-backlog for batch verification.
---

# QA a Single Asana Ticket

Verify whether the work specified in one Asana ticket is complete — bug fixed,
or feature working as specified — with evidence, scaling the amount of agentic
effort to the complexity of the ticket.

## Arguments

Accept these via skill args (e.g. `ticket=120987654321 env=dev-green mode=write-test`)
or from the surrounding conversation:

- `ticket` (required): Asana task GID, or a URL like
  `https://app.asana.com/0/<project>/<task_gid>` (the task GID is the last long
  number in the path)
- `env` (optional): `local` | `dev-green` | `dev-orange` | `staging`. If absent
  and not inferable from the ticket, ask — suggest `local` first.
- `mode` (optional): `verify-only` (default) — report findings, write no code;
  `write-test` — also write an ExUnit regression test (Step 7).

## The browser rule (read first)

Pick the browser access mode for how you were invoked:

| Mode | When | How |
|------|------|-----|
| **Scripted — REQUIRED for batch** | Dispatched as one of several parallel agents | Write a throwaway headless Playwright script and run it with Bash — each script owns a **private browser process**, so there is no shared state at all. Toolkit: `.claude/skills/qa-asana-ticket/scripts/` (playwright npm package installed there; adapt `example-verify.mjs`; run with cwd in that dir or `NODE_PATH=<scripts>/node_modules`). |
| **Headed MCP** | Standalone/interactive — the user may watch, or must log in | `mcp__playwright__*` tools |
| **Headless MCP** | Standalone, no human interaction needed | `mcp__playwright_headless__*` tools — same API, can't steal window focus or catch stray keystrokes |

Both MCP modes are ONE shared browser per server: **only one agent may drive it
at any moment**, the human's keyboard can reach the headed one, and a dedicated
tab (`browser_tabs`, re-selected before every action) only reduces — does not
eliminate — cross-agent contamination. Proven empirically: a 10-agent batch on
2026-06-05 had criteria blocked by tab races, including one triggered by a
single user keystroke. That's why batch mode MUST use the scripted route.

**Simulate real user interaction, never synthetic DOM mutation.** Drive
controls the way a human would: Playwright `.click()` on checkboxes/toggles/
labels, real keyboard events (`press`, `type`) for text entry and deletion.
NEVER set `element.checked`/`element.value` via JS and dispatch synthetic
`input`/`change` events — LiveView does not treat those as real user changes,
and the phantom result reads as an application bug. Proven empirically: a
2026-06-05 FAIL verdict on ticket 1213454845351518 ("Auto refresh" toggle
appearing not to repopulate a cleared textarea) was retracted after
re-verification showed the bug only "reproduced" under synthetic
`checked = true` + dispatched events; a real `.click()` worked in 6/6 runs.
Reading state via JS (`textarea.value`, computed styles) is fine — the rule
covers *writes/actions*, not reads.
Auth-walled deployed environments can't be logged into headlessly with
credentials — but a user-captured session (`scripts/.auth/<env>-state.json`,
see Step 3) lets headless scripts start already authenticated.

## Instructions

### Step 1: Load the ticket

Call `mcp__claude_ai_Asana__asana_get_task` with the task GID. Parse the
description for subsections — typically **Steps to Reproduce** and
**Acceptance Criteria**, though some may be loosely defined. Feature tickets
will not have a "Steps to Reproduce" section — verify their acceptance criteria
directly. Stop and ask for clarification only if you can find no testable
criteria at all; don't guess.

### Step 2: Resolve the base URL

| env        | Base URL                                       |
|------------|------------------------------------------------|
| local      | http://localhost:4010/                         |
| dev-green  | https://alerts-manager-dev-green.mbtace.com/   |
| dev-orange | https://alerts-manager-dev-orange.mbtace.com/  |
| staging    | https://alerts-manager-staging.mbtace.com/     |

If the ticket itself names an environment ("confirm on dev-green"), prefer it.
Before testing `local`, sanity-check that the running code can contain the
change (e.g. the fix commit/branch is in the checkout serving the port) — if it
can't, say so and ask instead of producing a meaningless verdict.

### Step 3: Verify access

For deployed envs, check the saved auth session first:
`cd .claude/skills/qa-asana-ticket/scripts && node auth-smoke-test.mjs <env>`.
If `authed:true`, headless scripts start signed in (`example-verify.mjs`
auto-loads `scripts/.auth/<env>-state.json` for `mbtace.com` targets) —
continue. Local needs no session (FakeKeycloak).

If the state file is missing or expired:

- **Interactive session:** REQUIRED SUB-SKILL — invoke qa-capture-auth-session
  to have the user log in and recapture, then continue.
- **Dispatched sub-agent (no user interaction):** report **blocked** for
  browser verification and fall back to non-browser verification of the same
  criteria where possible — never attempt to log in.

You are never to be authorized to hold credentials for logging into the app
— the user must do that.

### Step 4: Size the verification effort

Pick the smallest approach that covers the ticket — scale up, don't default up:

| Ticket shape                                    | Approach |
|-------------------------------------------------|----------|
| 1–2 criteria, one linear repro path             | Do Steps 5–6 yourself, inline — no team |
| 3+ criteria, or multiple scenarios/data states  | Agent team (roles below) |
| Running in the main session (Workflow available)| Express the team as a Workflow: phases `Reproduce` → `Adjudicate` → `Challenge` (→ `Test`), pipeline so adjudication of early criteria overlaps later reproduction |
| Running as a dispatched sub-agent               | Same roles via parallel `Agent` calls |

**Roles:**

- **Driver** (browser; exactly one at a time): executes the Steps to Reproduce
  (or, for feature tickets, the flows the acceptance criteria imply) and
  exercises each criterion, saving evidence per criterion — snapshot excerpts
  and `mcp__playwright__browser_take_screenshot` images — under
  `qa/<task_gid>/evidence/`. The UI may have drifted since the
  ticket was written: make correct inferences when labels or layouts differ,
  but be exact about precisely-stated requirements (copy text, ordering,
  validation messages, times).
- **Adjudicators** (no browser; one per criterion, run in parallel): read the
  saved evidence for their criterion and return pass / fail / blocked with
  reasoning. They must judge only from evidence — if evidence is insufficient,
  they return blocked and say what's missing, which sends the Driver back out.
- **Skeptic** (browser allowed; runs after adjudication, serialized): tries to
  REFUTE the emerging verdict — e.g. verdict "pass" → attempt edge inputs,
  alternate data states, or timing variations from the ticket to break it.
  Scale with uncertainty: clear unanimous evidence → 1 skeptic pass;
  conflicting or surprising results → up to 3 passes with distinct lenses
  (exact text, timing/ordering, data state). A successful refutation reopens
  the Driver loop with the new scenario.

### Step 5: Reproduce and adjudicate

Run the Driver through the steps, **recording every executed step as you go —
numbered and imperative, written as a QA engineer would, so the report's steps
can be re-executed by a human**. Then adjudicate every acceptance criterion
individually: **pass**, **fail**, or **blocked** (couldn't be tested — say
why). If a step cannot be completed for reasons outside the app — e.g. it
refers to an inaccessible Figma design — mark the affected criteria for a
**conditional pass** and note exactly why they couldn't be verified. Loop
Driver ↔ Adjudicators until no criterion is blocked on missing evidence, max 3
rounds — then report remaining blocks honestly.

### Step 6: Challenge, then verdict

Run the Skeptic pass(es). Conclude one of, only after the skeptic fails to
refute it:

- **pass** — bug fixed / feature works as specified
- **fail** — bug still present / criteria not met
- **conditional pass** — verified except for steps that couldn't be completed
  for external reasons (inaccessible design reference, missing third-party
  system); state why
- **blocked** — couldn't test at all (auth, environment, missing data)

Do NOT perform root-cause analysis on failures — demonstrating the failure is
the deliverable.

### Step 7: Regression test (`mode=write-test` only)

Run this as a writer/reviewer team, scaled to the test's complexity:

1. **Test-Writer**: writes one concise, targeted ExUnit test demonstrating the
   verified behavior (or the failure) in its own file under
   `test/alerts_ui_web/tickets/`, named EXACTLY
   `<ticket_gid>_<concise_name>_test.exs` — GID first, then a short snake_case
   condensation of the ticket title, then the `_test.exs` suffix (required for
   `mix test` to pick the file up). Example:
   `1213835744527069_effect_period_breakpoint_test.exs`. No `ticket_` prefix,
   no GID-less or GID-last names. Include the ticket
   URL in the `@moduledoc` or a comment. Follow the style of existing tests
   (ex_machina factories in `test/support/`, `live_isolated_component` for
   components). Run it: `mix test test/alerts_ui_web/tickets/<file>.exs`.
   Expected outcome: verdict **pass** → green; **fail** → red, failing for the
   documented reason. One file per ticket — parallel batch agents must never
   share a test file.
2. **Test-Reviewers** (parallel, after the run matches expectation): one
   reviews rigor — would this test pass trivially, does it actually exercise
   the criterion it claims? (use the `pr-review-toolkit:pr-test-analyzer` agent
   type if available); a second hunts silent failures in the test itself. For a
   trivial assertion-level test, one reviewer is enough.
3. Loop Writer ↔ Reviewers until approved, max 3 iterations; report any
   unresolved objections instead of silently shipping them.

### Step 8: Report

**When a ticket fails or conditionally passes**: Write a per-ticket report to
`qa/<task_gid>.md` **relative to your current working directory** — the active
checkout, not a hardcoded path. In worktree-isolated sessions, writes outside
the worktree are blocked, so a hardcoded main-checkout path will fail; evidence
belongs under the same checkout's `qa/<task_gid>/evidence/`. Include: ticket
link, environment (and which checkout/branch actually served it), verdict, the
QA-engineer-style executed steps from Step 5, per-criterion results with
evidence paths, skeptic outcome, test names added (if any) with their result,
and any blockers or auth interruptions. If any loop hit its iteration cap, say
so — NO silent caps. Link any relevant evidence inline in the report so the
reader does not have to hunt for files. While you are writing a text makrdown
document, assume the reader will have a parser of some kind and can see images
and tables directly.

You can use the file `.claude/skills/qa-asana-ticket/report-example.md` as an
example of the format that all reports should be in. This is not a
hard-formatted file, but the sections should be followed in spirit and the
contents of each section should be taken as direction or example.

**When a ticket passes or fails**": Append a one-line entry (date, ticket,
verdict, linked report for failures) to `qa/summary.md` — the cumulative summary
across all runs. The header of the file should be amended to be a general
summary of the health of the ticket-related test suite: Passes, Fails, Blocked,
Total, notable places where failures occur and/or reasons why, and any other
notes that might be relevant to someone viewing an overview of the health of
these tests.  **Batch mode:** skip this append; the qa-asana-backlog aggregator
updates the cumulative summary once for the whole run.

## Constraints

- **CRITICAL:** any time you create, edit, or duplicate an alert, the URL must
  contain `/mono/` — the purpose is verifying the new mono form against the old
  requirements
- dev-green, dev-orange, and staging are **read-only**: never create, modify,
  or delete data there
- You MAY create missing test data in the local environment
- No root-cause analysis; no fixing the bug
- No detailed reports for Passing tickets.
- One browser driver at a time — see "The browser rule" above

## Troubleshooting

**Asana tools not available:** Load them via ToolSearch
(`select:mcp__claude_ai_Asana__asana_get_task`). If still missing, the Asana
connector isn't connected — ask the user to connect it.

**`localhost:4010` connection refused:** The dev server isn't running. Ask the
user to start it (`mix phx.server`) — don't start it yourself in a shared
session without asking.

**Login wall on a deployed environment:** See Step 3 — use the saved session
(`scripts/.auth/<env>-state.json`); if missing/expired, qa-capture-auth-session
(interactive) or report blocked (sub-agent). Never attempt credentials
yourself.

**Write to `qa/` rejected with a worktree-isolation error:** You're in an
isolated worktree session — write under the worktree's own `qa/` (your cwd),
or exit the worktree first. Don't fight the sandbox with absolute paths.

**Browser shows another ticket's page mid-run:** Tab contention — re-select
your tab via `mcp__playwright__browser_tabs` before every action; if it
persists, serialize browser phases and note the slowdown in the report.
