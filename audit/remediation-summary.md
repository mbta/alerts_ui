# Remediation Summary

_Generated: 2026-05-14T19:45:00-05:00_

## Top 5 Risks

1. **Silent Oban job failure in `DelayedJob`** — Every error inside a job dispatched via `DelayedJob` (including `FeedWriter`) is caught, logged as a warning, and discarded. Oban records the job as successful; no retry fires; Sentry sees nothing. A broken `FeedWriter` would silently stop updating the GTFS-RT feed. Source: Reliability.

2. **Zero test coverage on `create_alert_mono_live/`** — The newer, actively developed alert creation flow (3,119 LOC, 19 files, core Slice protocol) has no tests of any kind. Any regression in this flow — the primary path for new alert creation — will reach production undetected. Source: Test Quality, Maintainability.

3. **Missing FK indexes on three association tables** — `informed_entities`, `active_period`, and `reminder_times` have no index on their `alert_id` foreign key columns. Every 30-second `FeedWriter` run performs a sequential scan on each table. As alert volume grows, this will degrade the critical feed-write pipeline. Source: Performance.

4. **`Jason.decode!(keys: :atoms)` atom exhaustion vector in the IBI import pipeline** — User-controlled input decoded with `keys: :atoms` can create unbounded atoms in the BEAM VM, which are never garbage collected. A malformed IBI feed or adversarial input could exhaust the atom table and crash the node. Source: Security.

5. **`CreateAlertLive` ↔ `FormComponents` dependency cycle + inverted layer dependencies** — The legacy form components call back into the parent LiveView for utility functions, and six business-layer modules import the web layer. Neither `CreateAlertLive` nor the form components can be compiled, tested, or reused independently. This also blocks retiring the legacy flow. Source: Architecture.

---

## Top 5 Recommendations

1. **Fix `DelayedJob` error propagation (one-line change)** — Change `rescue e -> Logger.warning(...)` to `rescue e -> Logger.warning(...); reraise e, __STACKTRACE__` in `delayed_job.ex`. Oban will correctly mark failures and Sentry will capture them. Risk reduction: High. Source: [remediation.md N1](remediation.md).

2. **Add three FK index migrations** — A single migration adding `create index(:informed_entities, [:alert_id])`, `create index(:active_period, [:alert_id])`, and `create index(:reminder_times, [:alert_id])` eliminates sequential scans on the highest-frequency DB hot path. Risk reduction: High. Source: [remediation.md N2](remediation.md).

3. **Write tests for `create_alert_mono_live/` and the Slice protocol** — Unit tests for each slice's `validate/3` callback and integration tests for the `CreateAlertMonoLive` LiveView covering all `combination` values. This is the single highest-leverage test investment in the codebase. Risk reduction: High. Source: [remediation.md N5](remediation.md).

4. **Break the `CreateAlertLive` ↔ `FormComponents` cycle** — Extract `get_routes/1`, `get_stops/3`, `get_schedules_by_date/2`, and `filter_out_old_trips/1` from `CreateAlertLive` into a shared context module. This resolves the cycle, unblocks decoupling the mono flow slices from the legacy LiveView, and is the prerequisite for legacy flow retirement. Risk reduction: High. Source: [remediation.md X1](remediation.md).

5. **Document the `combination` decision matrix and add `@moduledoc` to all 9 slice files** — All 9 slice implementation modules have no `@moduledoc`. The `combination` field values (`:ACCESS`, `:R`, `:RDS`, `:RDT`, `:RDTS`, `:SR`) that control the entire mono creation flow are entirely undocumented. This is the primary barrier to onboarding contributors to the codebase's core abstraction. Risk reduction: High. Source: [remediation.md X5](remediation.md).

---

## Cross-Cutting Themes

- **`create_alert_mono_live/` is the highest-risk area** — Zero tests, zero `@moduledoc`, undocumented `combination` semantics, and architectural coupling to the legacy flow all concentrate in this one feature area. Items N5, X4, and X5 together address the risk. Fixing them in sequence (architecture decoupling first, then tests, then docs) is the most efficient path.

- **Architecture debt is operational debt** — The `CreateAlertLive` ↔ `FormComponents` cycle and the inverted layer dependency (business logic importing the web layer) are not abstract cleanness concerns; they prevent isolated testing, block the legacy flow retirement, and make any change to `FormComponents.Helpers` a full-codebase ripple. Items X1, X2, and X4 form a dependency chain: X1 enables X4; X2 reduces the blast radius of every future change.

- **Observability gaps compound each other** — `DelayedJob` swallows errors (N1), the telemetry reporter is disabled (X7), and there is no operational runbook (L1). The result is that a broken feed write cycle could run silently for an extended period with no operator alert. N1 is the most impactful single fix; X7 and L1 complete the picture.

- **Quick wins available** — N1 (one-line change), N3 (delete one line of code), and N2 (one migration file) together address three High-severity findings with negligible implementation complexity. These can be done immediately without any design decisions.

---

## Confidence

Severity and risk-reduction scores are based on code reading and pattern analysis — not production incident data, load testing, or profiling. The following judgments are most load-bearing:

- **Performance F1 (missing FK indexes)** — High confidence. Confirmed by exhaustive search across all migration files. Impact scale depends on current row counts in `informed_entities` (not measured), but the pattern is structurally unambiguous.
- **Test quality F1 (zero coverage on mono flow)** — High confidence. File-by-file search confirms no test files reference `CreateAlertMonoLive` or any slice module.
- **Architecture cycle (X1)** — High confidence. Bidirectional grep confirms mutual imports. The specific functions involved are directly readable in the source.
- **Priority ordering within Next/Later** — Medium confidence. Items with overlapping interdependencies (X1 → X4, X2 → X4) are sequenced based on dependency structure, not effort estimation. The relative ordering of X7, X8, X9, X10 is lower-confidence and teams may reasonably reorder.

This plan does not include effort sizing, duration estimates, or team-shape projections.
