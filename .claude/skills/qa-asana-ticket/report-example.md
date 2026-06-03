# QA: [title]

- **Ticket:** [ticket url]
- **GID:** [ticket GID]
- **Type:** [ticket type: feature, bug, etc
- **Environment:** [environment name and URL]
- **Checkout/branch served:** [git branch, if local. If remote, the git checkout
can be obtained from `[url]/_version`]
- **Verdict:** [verdict]

## Summary

Summary of what was expected and the quick version of what you did. Use
relevant parts of the ticket description where useful

## Executed steps (re-runnable)

1. Exhaustive list of the steps you took to try to reproduce the issue in the
   ticket. You do not need to mention any authentication steps, as they are
   assumed to be required.

## Acceptance criteria

| # | Criterion | Result | Evidence |
|---|-----------|--------|----------|
| 1 | Each Acceptance Criterion listed in the ticket, concisely summarized | verdict | Evidence supporting the verdict, including linked screenshots if they are relevant. |

## Skeptic pass (4 lenses — none refuted the fix)

1. **Exact ticket flow** — typed lowercase, then capitalized one character at a
   time without clearing (`south station` → `south Station` → `South Station`):
   all three → identical 2 results, no non-matching.
2. **Real char-by-char keystrokes** (120ms/key, fires many change events): same
   2 results.
3. **Repeat clear-then-research x3**: stable at 2 results each time.
4. **Nonsense search** (`zzzznotarealstop`): correctly empty (0 results), no
   stale list. `evidence/skeptic-nonsense.png`

No console errors (CSP/live-debugger noise excluded).

## Regression test

- File: `test/alerts_ui_web/tickets/1213373025641047_stop_search_strange_results_test.exs`
- Target: `SelectFormatter.formatted_select_options/1` — the deterministic core
  the live list is built from and the function named in Erin's tech note.
- Result: **4 tests, 0 failures** (green, matching PASS verdict).
- Reviewer / mutation check: temporarily removing the `String.downcase` calls in
  `apply_search` (simulating the reported case-sensitivity symptom) turned the
  suite red (3 of 4 fail on AC2/AC3), proving the test is not trivial. Source
  was restored and re-confirmed green.

## Notes / blockers

- Direct URL `/alerts/mono/new/3/stop_closure` 500s (`Protocol.UndefinedError`
  in `humanize_effect_name`) — the bus route_type slug in the URL is `bus`, not
  `3`. Drove the UI by clicking instead; not part of this ticket.
- No iteration caps were hit.

