# QA Asana Ticket — Cumulative Summary

Overview of the health of the per-ticket QA regression suite
(`test/alerts_ui_web/tickets/`), tracked across `qa-asana-ticket` runs.

**Health (tracked runs below):** Passes: 41 · Conditional: 4 · Fails: 1 · Blocked: 0 · Total: 46

Notes:
- Regression tests in `test/alerts_ui_web/tickets/` from tracked runs include one
  intentionally-red test added 2026-06-07 for ticket 1213737377246666 (F2H trip-based
  gap: Boat-F1 not included in trip-based Boat-F2H alert informed_entities). All
  other ticket tests remain green.
- 2026-06-07 adversarial re-check of ticket 1213737377246666 (FAIL verdict): re-checked
  with real Playwright `selectOption` interaction (not synthetic DOM), two different Boat-F2H
  trips (alerts 1000022 & 1000023). Both confirm Boat-F1 absent from trip-based alert feed.
  Non-trip case continues to PASS (alert 1000021). Original FAIL verdict stands.
- 2026-06-08 batch (10 tickets, env=dev-green, Sonnet 4.6): 10 pass / 0 conditional / 0 fail.
  Covered DST crash, escape-in-modal, auto-refresh repopulation, actions menu truncation,
  affected service filter scroll/selection, form-crash-on-delete, push notification timestamp,
  SR alert stop filtering, stop search consistency, and GTFS Green Line validation.
  One ticket (1213373025641034) had a single conditional criterion (recurring-UI path
  not directly driveable via Playwright) but overall verdict was pass; unit test coverage
  fills the gap. Same for 1213275668858461 (observability stretch goal out of scope).
- 2026-06-06 batch (10 tickets, env=dev-green with a captured authenticated
  Keycloak session — first batch with true deployed-env browser verification):
  7 pass / 3 conditional / 0 fail. No verdict was disputed by the challenge
  phase.
- Conditional passes cluster in two areas, neither a UI defect:
  1. **Tickets with no acceptance criteria / unmeasurable targets** — the two
     DB/perf tickets (1214803667933030 missing FK indexes: 4 of 5 indexes
     delivered, `ibi_alerts.alert_version_id` still unindexed;
     1214298862551001 slow View Alerts query: fix verified at code/LiveView
     level but no perf target existed to measure against).
  2. **Storage-layer-only fixes leaving legacy data paths** — 1212433843572811
     (Direction field): new/edited alerts are correct, but legacy alerts with
     stored `Both` can still render Direction in the review modal and history
     CSV (renderer unchanged).
- 1213835744527069 (effect period breaking point) previously FAILED on a
  2026-06-06 local run due to a deploy gap; it now PASSES on dev-green — the
  fix has been deployed.
- This summary file was created during the 2026-06-06 run for ticket
  1213905421595760; all per-ticket reports now live under `qa/`.

## Runs

| Date | Ticket | Verdict | Report |
|------|--------|---------|--------|
| 2026-06-06 | [1213905421595760](https://app.asana.com/1/15492006741476/project/1167196461144361/task/1213905421595760) — alert_duration should show end time today | PASS | |
| 2026-06-06 | [1213835744527069](https://app.asana.com/1/15492006741476/project/1167196461144361/task/1213835744527069) — Awkward breaking point in effect period inputs | PASS | |
| 2026-06-06 | [1214803667933030](https://app.asana.com/1/15492006741476/project/1167196461144361/task/1214803667933030) — Add missing foreign key indexes | CONDITIONAL PASS (ibi_alerts.alert_version_id still unindexed) | [report](qa/1214803667933030.md) |
| 2026-06-06 | [1214457338889820](https://app.asana.com/1/15492006741476/project/1167196461144361/task/1214457338889820) — Retain sort parameters after filtering | PASS | |
| 2026-06-06 | [1214298862551001](https://app.asana.com/1/15492006741476/project/1167196461144361/task/1214298862551001) — Slow database query on View Alerts Page | CONDITIONAL PASS (no measurable perf target in ticket) | [report](qa/1214298862551001.md) |
| 2026-06-06 | [1214053426015565](https://app.asana.com/1/15492006741476/project/1167196461144361/task/1214053426015565) — Alerts crash upon reload | PASS | |
| 2026-06-06 | [1211949790816584](https://app.asana.com/1/15492006741476/project/1167196461144361/task/1211949790816584) — Improve sorting for affected routes auto-text | PASS | |
| 2026-06-06 | [1212952513436008](https://app.asana.com/1/15492006741476/project/1167196461144361/task/1212952513436008) — Adjust hover CSS for selected buttons | PASS | |
| 2026-06-06 | [1214108822755652](https://app.asana.com/1/15492006741476/project/1167196461144361/task/1214108822755652) — Facility selector & filter search bar clears upon selection | PASS | |
| 2026-06-06 | [1212433843572811](https://app.asana.com/1/15492006741476/project/1167196461144361/task/1212433843572811) — Don't store/show Direction field when not relevant | CONDITIONAL PASS (legacy 'Both' data can still render in modal/CSV) | [report](qa/1212433843572811.md) |
| 2026-06-07 | [1214511140968898](https://app.asana.com/1/15492006741476/project/1167196461144361/task/1214511140968898) — Actions buttons have no accessible labels or titles | PASS | |
| 2026-06-07 | [1213534705218460](https://app.asana.com/1/15492006741476/project/1167196461144361/task/1213534705218460) — Ensure AM is behind the web firewall | PASS (infra: WAF blocks XSS/SQLi/scanner UAs on all deployed envs; Terraform config conditional per separate repo) | |
| 2026-06-07 | [1214283657147217](https://app.asana.com/1/15492006741476/project/1167196461144361/task/1214283657147217) — Making reminders doesn't work properly anymore | PASS | |
| 2026-06-07 | [1213794748602766](https://app.asana.com/1/15492006741476/project/1167196461144361/task/1213794748602766) — Buttons go dark when hovering | PASS | |
| 2026-06-07 | [1213791649887634](https://app.asana.com/1/15492006741476/project/1167196461144361/task/1213791649887634) — When text limit is reached, "Copy text" turns red | PASS | |
| 2026-06-07 | [1208409681222950](https://app.asana.com/1/15492006741476/project/1167196461144361/task/1208409681222950) — When user changes direction, remove selected bus stops in opposite direction | PASS | |
| 2026-06-07 | [1214053426015558](https://app.asana.com/1/15492006741476/project/1167196461144361/task/1214053426015558) — Some facilities can't be selected and submitted successfully | PASS | |
| 2026-06-07 | [1213737377246666](https://app.asana.com/1/15492006741476/project/1167196461144361/task/1213737377246666) — F1 should be informed entity for F2H alerts | FAIL (non-trip-based PASS; trip-based FAIL — Boat-F1 absent when specific trip selected) | [report](qa/1213737377246666.md) |
| 2026-06-07 | [1213347936088923](https://app.asana.com/1/15492006741476/project/1167196461144361/task/1213347936088923) — App shouldn't reload itself unless session has ended | PASS | |
| 2026-06-07 | [1213857569129036](https://app.asana.com/1/15492006741476/project/1167196461144361/task/1213857569129036) — Description auto-text erroneously adds stops to wrong direction upon auto-refresh | PASS | |
| 2026-06-07 | [1211955886164861](https://app.asana.com/1/15492006741476/project/1167196461144361/task/1211955886164861) — Issues with clearing filters in filter modal | PASS | |
| 2026-06-07 | [1213493564093955](https://app.asana.com/1/15492006741476/project/1167196461144361/task/1213493564093955) — Special characters should export cleanly in history | CONDITIONAL PASS (CSV is correctly UTF-16 LE+BOM on dev-green, 81 alerts checked; no dev-green alert has special chars in text fields to directly verify the round-trip — confirmed via local unit tests) | [report](qa/1213493564093955.md) |
| 2026-06-07 | [1213671640738760](https://app.asana.com/1/15492006741476/project/1167196461144361/task/1213671640738760) — Direction shouldn't be in facility alerts | PASS | |
| 2026-06-07 | [1213545400300573](https://app.asana.com/1/15492006741476/project/1167196461144361/task/1213545400300573) — Manual facility alerts outputting wrong `cause` | PASS | |
| 2026-06-07 | [1213402732501477](https://app.asana.com/1/15492006741476/project/1167196461144361/task/1213402732501477) — Can't change recurring alert to 1-time | PASS | |
| 2026-06-08 | [1213628754823604](https://app.asana.com/0/1167196461144361/1213628754823604) — GTFS validator says Green Line no longer exists | PASS | |
| 2026-06-08 | [1213454845351518](https://app.asana.com/0/1167196461144361/1213454845351518) — Auto refresh should work even if all text has been deleted | PASS | |
| 2026-06-08 | [1213156310400768](https://app.asana.com/0/1167196461144361/1213156310400768) — Other actions menu being truncated | PASS | |
| 2026-06-08 | [1213275668858461](https://app.asana.com/0/1167196461144361/1213275668858461) — Form crashes after deleting time value | PASS | |
| 2026-06-08 | [1213372459286241](https://app.asana.com/0/1167196461144361/1213372459286241) — Stops not filtering correctly in SR alerts | PASS | |
| 2026-06-08 | [1213373025641047](https://app.asana.com/0/1167196461144361/1213373025641047) — Strange results in stop search | PASS | |
| 2026-06-08 | [1213450829885289](https://app.asana.com/0/1167196461144361/1213450829885289) — Pressing escape when in review modal takes you back to alerts table | PASS | |
| 2026-06-08 | [1213373025641034](https://app.asana.com/0/1167196461144361/1213373025641034) — App crashes when creating an alert with a datetime during the non-existent DST hour | PASS | |
| 2026-06-08 | [1213450829885294](https://app.asana.com/0/1167196461144361/1213450829885294) — Push notification behavior not working correctly | PASS | |
| 2026-06-08 | [1212270992306498](https://app.asana.com/0/1167196461144361/1212270992306498) — Weirdness in affected service filter | PASS | |
