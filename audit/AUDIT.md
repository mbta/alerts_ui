# Audit — MBTA / alerts_ui

_May 14, 2026_

## Verdict

**Risk level:** medium

**Headline:** A well-delivered codebase with a reliable feed pipeline and a silent failure mode in it, zero test coverage on the core alert creation flow, and missing database indexes on the 30-second hot path.

**Framing:** The reliability and architecture findings are individually tractable; several have one-line fixes. The test coverage gap in `create_alert_mono_live/` is the structural risk that will compound every other finding if left unaddressed.

---

## Executive Summary

`alerts_ui` is a single Phoenix LiveView application (~64,200 LOC) that MBTA staff use to author transit alerts published as GTFS-RT protobuf feeds to AWS S3 every 30 seconds. The delivery posture is strong — DORA proxies place the team in the High/Elite band across deployment frequency and change failure rate, and the CI pipeline is comprehensive. The codebase follows Phoenix conventions and has sensible structural layering for most of its life.

The most significant finding is that `create_alert_mono_live/` — the newer, actively developed primary alert creation flow at 3,119 LOC across 19 files — has **zero test coverage of any kind**. This is the highest-leverage test investment available and the finding most likely to compound other risks.

Three high-severity operational concerns require near-term attention:

1. **`DelayedJob` silently swallows errors** — a one-line rescue clause causes Oban to record any failing `FeedWriter` job as successful. A broken feed write cycle would log warnings and nothing else.
2. **Missing FK indexes** on `informed_entities`, `active_period`, and `reminder_times` mean the every-30-second feed write path runs sequential table scans. A simple migration resolves this.
3. **`Jason.decode!(keys: :atoms)`** in the IBI import pipeline is an atom exhaustion risk under adversarial or malformed input.

The architecture carries two structural debts: a confirmed dependency cycle between `CreateAlertLive` and four of its form components, and six business-layer modules that import the web layer (`AlertsUIWeb.FormComponents.Helpers.*`). Both prevent isolated testing and block the stated goal of retiring the legacy alert creation flow. These are the highest-leverage architectural investments.

Documentation is the weakest dimension (C+). All 9 slice implementation files have no `@moduledoc`, the `combination` field semantics that control the entire mono creation flow are undocumented, and the `.envrc.example` is missing the KEYCLOAK and SENTRY variables required to run the application.

The most important single-document improvement available is a `docs/SLICES.md` explaining the `Slice` protocol, the `combination` decision matrix, and a walkthrough for adding a new slice — the system's core abstraction has no written specification.

---

## Methodology & Limitations

This audit is **LLM-driven (v1)** — Claude reads code, manifests, configs, git history, and supplied artifacts and reasons about quality dimensions without running static-analysis tools. Findings are hypothesis-grade and should be confirmed with measurement before significant remediation.

**Anchored frameworks:** ISO/IEC 25010, ISO/IEC 5055, OWASP ASVS / SAMM, DORA / Accelerate, Robert C. Martin package metrics, *Your Code as a Crime Scene* (Tornhill hot-spot analysis).

**Known limitations:**
- Performance findings (missing indexes, duplicate S3 writes) are confirmed by code reading but unconfirmed by `EXPLAIN ANALYZE` or profiling. Confirm with real measurement before deprioritizing.
- Architecture cycle detection is direct (confirmed by bidirectional grep); additional indirect cycles spanning 3+ hops may exist. A real dependency graph tool (`mix xref graph`) would surface any missed.
- Security findings are hypothesis-grade. `mix sobelow` runs in CI but does not cover all OWASP categories analyzed here.
- MTTR and production incident history are not available from git history alone. Reliability findings are code-pattern-based.
- No dimensions were skipped; all 8 are present.

---

## Scorecard

| Dimension | Grade | Headline |
|-----------|-------|----------|
| Maintainability | B | Solid Phoenix conventions with two hot-spot files and `FormComponents.Helpers` acting as a coupling magnet |
| Test Quality | B | Strong unit test foundation; `create_alert_mono_live/` (the primary new flow) has zero tests |
| Security | B | No committed secrets; OIDC auth is correctly implemented; `Jason.decode!(keys: :atoms)` is the primary risk |
| Reliability | B | Oban + Sentry provide a solid base; `DelayedJob` silently swallows errors and telemetry metrics are discarded |
| Performance | B | Adequate at current scale; three missing FK indexes on the feed-write hot path are the highest-leverage fix |
| Architecture | B | Phoenix layering is generally sound; one confirmed module cycle and six inverted layer dependencies need resolution |
| Delivery | A- | Elite change failure rate (~2.5%); DORA High on deployment frequency; strong CI pipeline |
| Documentation | C+ | Functional README and CLAUDE.md; all 9 slice files undocumented; `combination` semantics entirely missing |

---

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

## Sub-reports

- [Inventory](inventory.md)
- [Maintainability](dimensions/maintainability.md)
- [Test Quality](dimensions/test-quality.md)
- [Security](dimensions/security.md)
- [Reliability](dimensions/reliability.md)
- [Performance](dimensions/performance.md)
- [Architecture](dimensions/architecture.md)
- [Delivery Health](dimensions/delivery.md)
- [Documentation & Onboarding](dimensions/documentation.md)
- [Domain Ontology](ontology.md)
- [Remediation Plan](remediation.md)
- [Remediation Summary (1-page)](remediation-summary.md)
