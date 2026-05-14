# Remediation Plan

_Generated: 2026-05-14T19:45:00-05:00_
_Sources: dimensions/maintainability.md, dimensions/test-quality.md, dimensions/security.md, dimensions/reliability.md, dimensions/performance.md, dimensions/architecture.md, dimensions/delivery.md, dimensions/documentation.md, ontology.md_

## Methodology

This plan synthesizes findings across the eight audit dimensions and the ontology. Items are merged across dimensions where the root cause and mitigation are shared. Each item is scored for severity and risk reduction, then grouped into **Now / Next / Later priority buckets** — not time buckets.

This plan does not include effort sizing, duration estimates, or team-shape projections.

---

## Now (highest priority)

These items have the best risk-reduction-to-severity ratio, address active operational risk, or unblock other work.

---

### N1 — Fix `DelayedJob` silent failure: reraise errors instead of returning `:ok`

- **Severity:** High
- **Risk reduction:** High
- **Source dimensions:** Reliability
- **Evidence:** [reliability.md F1](dimensions/reliability.md#f1--delayedjobperform2-swallows-errors-reporting-success-to-oban)
- **Discipline:** reliability
- **Acceptance criteria:**
  - `DelayedJob.perform/2`'s `rescue` clause calls `reraise e, __STACKTRACE__` (or `{:error, e}`) instead of returning `nil`/`:ok`
  - Oban marks a failing `FeedWriter` run as `failed` rather than `completed`
  - Sentry captures the exception with a stack trace
  - Existing `DelayedJob` unit test updated to assert on error propagation

---

### N2 — Add `alert_id` FK indexes on `informed_entities`, `active_period`, and `reminder_times`

- **Severity:** High
- **Risk reduction:** High
- **Source dimensions:** Performance
- **Evidence:** [performance.md F1](dimensions/performance.md#f1--no-fk-indexes-on-informed_entitiesalert_id-active_periodalert_id-reminder_timesalert_id)
- **Discipline:** data
- **Acceptance criteria:**
  - A single migration adds `create index(:informed_entities, [:alert_id])`, `create index(:active_period, [:alert_id])`, and `create index(:reminder_times, [:alert_id])`
  - `EXPLAIN ANALYZE` on the `FeedWriter` preload query (`WHERE alert_id IN (...)`) confirms index scan rather than sequential scan on each table

---

### N3 — Remove duplicate `write(:enhanced, enhanced_alerts)` in `write_feed.ex`

- **Severity:** Medium
- **Risk reduction:** High
- **Source dimensions:** Performance
- **Evidence:** [performance.md F2](dimensions/performance.md#f2--writefeed0-writes-the-enhanced-feed-twice-per-invocation)
- **Discipline:** reliability
- **Acceptance criteria:**
  - `write_feed.ex` contains exactly one `write(:enhanced, enhanced_alerts)` call
  - `FeedWriter` test confirms the S3 write function is called exactly once for the enhanced feed per invocation

---

### N4 — Replace `Jason.decode!(keys: :atoms)` with `keys: :strings` to eliminate atom DoS vector

- **Severity:** High
- **Risk reduction:** High
- **Source dimensions:** Security
- **Evidence:** [security.md F1](dimensions/security.md#f1--jasondecodekeys-atoms-in-ibi-pipeline-atom-exhaustion-vector)
- **Discipline:** security
- **Acceptance criteria:**
  - All `Jason.decode!/2` and `Jason.decode/2` calls with `keys: :atoms` replaced with `keys: :strings` or `keys: :atom!` (for known-key maps only)
  - IBI importer pipeline tests pass with string-keyed maps
  - `mix credo` and `mix sobelow` pass with no new warnings

---

### N5 — Write tests for `create_alert_mono_live/` (currently zero coverage)

- **Severity:** High
- **Risk reduction:** High
- **Source dimensions:** Test Quality, Maintainability
- **Evidence:** [test-quality.md F1](dimensions/test-quality.md#f1--create_alert_mono_live-has-zero-test-coverage), [maintainability.md F2](dimensions/maintainability.md)
- **Discipline:** reliability
- **Acceptance criteria:**
  - Test files exist for `CreateAlertMonoLive` (LiveView integration tests) and each of the 9 untested slice modules
  - At minimum, each slice has a unit test covering its `validate/3` callback with valid and invalid inputs
  - `CreateAlertMonoLive` integration tests cover: mount, step transitions, and form submission for each `combination` value
  - CI passes with the new tests

---

## Next (structural)

These items address architectural debt, reduce coupling, and prevent future regressions.

---

### X1 — Break `CreateAlertLive` ↔ `FormComponents` dependency cycle

- **Severity:** High
- **Risk reduction:** High
- **Source dimensions:** Architecture
- **Evidence:** [architecture.md F1](dimensions/architecture.md#f1--confirmed-dependency-cycle-createalertlive--formcomponents)
- **Discipline:** reliability
- **Acceptance criteria:**
  - `get_routes/1`, `get_stops/3`, `get_schedules_by_date/2`, and `filter_out_old_trips/1` extracted from `CreateAlertLive` into a dedicated context module (e.g. `AlertsUI.AlertFormData` or `AlertsUIWeb.AlertFormHelpers`)
  - `FormComponents.{AffectedService, AlertDetails, StopRouteAffectedService, AccessAffectedService}` import the new shared module, not `CreateAlertLive`
  - `mix xref graph` (or grep-based verification) confirms no cycle between `CreateAlertLive` and those four form components

---

### X2 — Resolve inverted layer dependency: move `FormComponents.Helpers` domain modules to `AlertsUI.*`

- **Severity:** High
- **Risk reduction:** High
- **Source dimensions:** Architecture, Maintainability
- **Evidence:** [architecture.md F2](dimensions/architecture.md#f2--business-layer-imports-web-layer-libalerts_ui--alertsuiwebformcomponentshelpers), [architecture.md F3](dimensions/architecture.md#f3--formcomponentshelpers-is-a-coupling-magnet-with-49-inbound-imports)
- **Discipline:** reliability
- **Acceptance criteria:**
  - Modules with domain logic currently in `AlertsUIWeb.FormComponents.Helpers.*` (e.g. `SelectFormatter`, `ServiceEffectCombinations`, `ContentFormatter`, `EffectsForRouteTypes`, `AutoText.*`) moved to `AlertsUI.*` namespaces (e.g. `AlertsUI.Formatting`, `AlertsUI.ServiceEffects`)
  - Zero `alias AlertsUIWeb` calls remain in `lib/alerts_ui/` (confirmed by grep)
  - All callers updated; `mix compile` passes without warnings

---

### X3 — Add explicit DB transaction timeouts to `IBIAlertImporter`

- **Severity:** High
- **Risk reduction:** High
- **Source dimensions:** Reliability
- **Evidence:** [reliability.md F2](dimensions/reliability.md#f2--ibialertimporter-holds-db-connections-with-timeout-infinity-6-occurrences)
- **Discipline:** reliability
- **Acceptance criteria:**
  - All six `timeout: :infinity` occurrences in `ibi_alert_importer.ex` replaced with explicit upper bounds (e.g. `timeout: 300_000` for the bulk import path)
  - Timeout failures logged with context (operation name, row count estimate) and surfaced as Oban job failures, not silent hangs
  - Pool starvation scenario considered: evaluate whether bulk import should run against a dedicated DB pool

---

### X4 — Decouple mono flow slices from `CreateAlertLive`

- **Severity:** Medium
- **Risk reduction:** High
- **Source dimensions:** Architecture
- **Evidence:** [architecture.md F4](dimensions/architecture.md#f4--createalertlive-used-as-a-utility-library-by-the-mono-flow-slices)
- **Discipline:** reliability
- **Note:** Blocked by X1 — the shared context module from X1 is the target import
- **Acceptance criteria:**
  - `affected_service_slice.ex`, `stop_route_service_slice.ex`, and `access_affected_service_slice.ex` import from the new shared context module, not from `AlertsUIWeb.CreateAlertLive`
  - No `alias AlertsUIWeb.CreateAlertLive` remains in any slice file
  - All three slices have tests that can run without `CreateAlertLive` loaded

---

### X5 — Document the `Slice` protocol: write `@moduledoc` for all 9 slice files and `AlertData`, plus a combination decision matrix

- **Severity:** High
- **Risk reduction:** High
- **Source dimensions:** Documentation, Maintainability
- **Evidence:** [documentation.md F1](dimensions/documentation.md#f1--all-9-slice-implementation-files-have-no-moduledoc-alertdata-moduledoc-is-minimal), [documentation.md F2](dimensions/documentation.md#f2--the-combination-field-semantics-are-entirely-undocumented)
- **Discipline:** docs
- **Acceptance criteria:**
  - Each of the 9 slice implementation files has a `@moduledoc` covering: business purpose, which `AlertData` fields it manages, and which validation rules it enforces
  - `AlertData` moduledoc describes the `combination` field with a decision matrix: for each of `:ACCESS`, `:R`, `:RDS`, `:RDT`, `:RDTS`, `:SR`, lists the human-readable scenario and which slices activate
  - A `docs/SLICES.md` (or equivalent) explains the `Slice` protocol callback contract, the combination/slice activation table, and a walkthrough of adding a new slice

---

### X6 — Add `receive_timeout` and `connect_timeout` to all outbound HTTP calls

- **Severity:** Medium
- **Risk reduction:** High
- **Source dimensions:** Reliability, Performance
- **Evidence:** [reliability.md F3](dimensions/reliability.md#f3--feedreader-uses-reqget1-bang-form-with-no-timeout), [performance.md F3](dimensions/performance.md#f3--serial-mbta-api-fan-out-on-stop-and-facility-id-lookups)
- **Discipline:** reliability
- **Acceptance criteria:**
  - `feed_reader.ex` Req calls include `receive_timeout: 10_000, connect_timeout: 5_000` (or module-level defaults)
  - `alert_validation_upcoming_worker.ex` Req calls likewise have explicit timeouts
  - Any `Req.get!` bang form that may surface a `MatchError` before Oban can catch it is replaced with the non-bang `Req.get` form with pattern matching
  - `mix dialyzer` passes

---

### X7 — Configure a telemetry reporter so metrics are not silently discarded

- **Severity:** Medium
- **Risk reduction:** High
- **Source dimensions:** Reliability
- **Evidence:** [reliability.md F4](dimensions/reliability.md#f4--metrics-reporter-disabled-telemetry-metrics-are-collected-but-not-exported)
- **Discipline:** observability
- **Acceptance criteria:**
  - A telemetry reporter is configured and active: either `telemetry_metrics_prometheus_core` (if Prometheus/Grafana is available in the environment) or `Telemetry.Metrics.ConsoleReporter` as a minimum for development visibility
  - Phoenix endpoint latency, LiveView socket counts, and Ecto query duration metrics are exported in at least one environment
  - Reporter configuration documented in CLAUDE.md or an ops runbook

---

### X8 — Add `alerts.closed_timestamp` index to support open-alert queries

- **Severity:** Medium
- **Risk reduction:** Medium
- **Source dimensions:** Performance
- **Evidence:** [performance.md R3](dimensions/performance.md#recommendations)
- **Discipline:** data
- **Acceptance criteria:**
  - Migration adds `create index(:alerts, [:closed_timestamp])` (partial index on `WHERE closed_timestamp IS NULL` preferred if Postgres supports it for the query planner)
  - `EXPLAIN ANALYZE` on `list_all_open/0` confirms index usage

---

### X9 — Update `.envrc.example` with `KEYCLOAK_*`, `SENTRY_DSN`, and `SECRET_KEY_BASE` instructions

- **Severity:** Medium
- **Risk reduction:** Medium
- **Source dimensions:** Documentation
- **Evidence:** [documentation.md F4](dimensions/documentation.md#f4--envrcexample-missing-keycloak_-variables-and-sentry_dsn-secret_key_base-is-empty-with-no-instructions)
- **Discipline:** docs
- **Acceptance criteria:**
  - `.envrc.example` includes commented-out entries for `KEYCLOAK_CLIENT_ID`, `KEYCLOAK_CLIENT_SECRET`, `KEYCLOAK_ISSUER` with a note about when they are required
  - `SENTRY_DSN` entry present with a note that it is only required in deployed environments (not local dev)
  - `SECRET_KEY_BASE` entry includes a comment: `# generate with: mix phx.gen.secret`

---

### X10 — Remove `MBTAV3API.Stops.Repo` call from the `Alert` domain model

- **Severity:** Medium
- **Risk reduction:** Medium
- **Source dimensions:** Architecture
- **Evidence:** [architecture.md F5](dimensions/architecture.md#f5--domain-models-import-mbta-api-io-layer)
- **Discipline:** reliability
- **Acceptance criteria:**
  - `Alert` model no longer imports `MBTAV3API.Stops.Repo` or calls `StopsRepo.get_parent/1`
  - The stop-parent lookup moved to the context layer (`DBContexts.Alerts`, `AlertBuilder`, or a new step in the alert creation pipeline)
  - `Alert` changeset tests no longer require the ConCache/MBTAV3API application to be started

---

## Later (strategic)

These items improve hygiene, reduce long-term risk, and improve the developer experience. None are operationally urgent.

---

### L1 — Write an operational runbook (`docs/runbook.md`)

- **Severity:** Medium
- **Risk reduction:** Medium
- **Source dimensions:** Documentation, Reliability
- **Evidence:** [documentation.md F5](dimensions/documentation.md#f5--no-operational-runbook-rollback-procedure-is-one-sentence-no-on-call-or-incident-response-docs), [reliability.md F1–F2](dimensions/reliability.md)
- **Discipline:** docs
- **Acceptance criteria:**
  - `docs/runbook.md` covers at minimum: what to do when Sentry fires a `DelayedJob` error, how to restart a stalled Oban queue, S3 write failure response, and the IBI importer bulk re-import procedure
  - Rollback procedure expanded beyond "create a release for a previous tag" to include: how to identify the target tag, what to monitor after rollback

---

### L2 — Add CSP headers and review cookie security flags

- **Severity:** Medium
- **Risk reduction:** Medium
- **Source dimensions:** Security
- **Evidence:** [security.md F3](dimensions/security.md#f3--no-content-security-policy-headers)
- **Discipline:** security
- **Acceptance criteria:**
  - `Plug.Conn.put_resp_header("content-security-policy", ...)` or `PlugContentSecurityPolicy` configured with a restrictive policy appropriate for a LiveView app (allowing `wss:` for WebSocket, self for scripts/styles)
  - Session cookie has `secure: true` and `http_only: true` confirmed in endpoint configuration
  - No browser console CSP violations on the primary alert creation and listing flows

---

### L3 — Add rate limiting to OIDC authentication and API endpoints

- **Severity:** Medium
- **Risk reduction:** Medium
- **Source dimensions:** Security
- **Evidence:** [security.md F4](dimensions/security.md#f4--no-rate-limiting-on-authentication-endpoints)
- **Discipline:** security
- **Acceptance criteria:**
  - `Hammer` (or equivalent) plug applied to the `/auth` callback routes and the `/api` scope
  - Rate limit is per-IP; limit values documented in config
  - 429 responses return a standard JSON error body for API routes

---

### L4 — Establish ADR practice: write ADRs for `Slice` protocol and legacy flow retirement plan

- **Severity:** Low
- **Risk reduction:** Low
- **Source dimensions:** Architecture, Documentation
- **Evidence:** [architecture.md F6](dimensions/architecture.md#f6--no-architectural-decision-records-adrs)
- **Discipline:** docs
- **Acceptance criteria:**
  - `docs/adr/` directory created with at minimum two ADRs: (1) rationale for the `Slice` protocol pattern over the legacy form-component approach; (2) decision and plan for retiring `create_alert_live.ex`
  - ADR format: Context / Decision / Consequences (3–5 lines each is sufficient)

---

### L5 — Enable `gzip: true` in `Plug.Static` to serve pre-compressed assets

- **Severity:** Low
- **Risk reduction:** Low
- **Source dimensions:** Performance
- **Evidence:** [performance.md F6](dimensions/performance.md#f6--plugstatic-served-with-gzip-false-in-endpoint)
- **Discipline:** platform
- **Acceptance criteria:**
  - `Plug.Static` in `endpoint.ex` has `gzip: true` (conditionally for prod, or unconditionally since `phx.digest` generates `.gz` files)
  - Network tab in browser DevTools confirms `Content-Encoding: gzip` for `.js` and `.css` assets in staging

---

### L6 — Merge open Dependabot PRs and establish a regular merge cadence

- **Severity:** Low
- **Risk reduction:** Low
- **Source dimensions:** Delivery
- **Evidence:** [delivery.md F3](dimensions/delivery.md#f3--8-open-dependabot-prs-unmerged)
- **Discipline:** build
- **Acceptance criteria:**
  - All 8 current Dependabot PRs merged (or explicitly closed with a note explaining why)
  - A documented merge cadence established (e.g. merge Dependabot patch/minor PRs weekly as part of routine maintenance)

---

### L7 — Archive or promote `agentic-dev-improvements.md`; clean up stale branches

- **Severity:** Low
- **Risk reduction:** Low
- **Source dimensions:** Documentation, Delivery
- **Evidence:** [documentation.md F6](dimensions/documentation.md#f6--agentic-dev-improvementsmd-is-a-planning-artifact-in-the-repo-root-not-a-doc-artifact), [delivery.md F2](dimensions/delivery.md#f2--14-stale-unmerged-remote-branches-90-days-no-merge-to-main)
- **Discipline:** docs
- **Acceptance criteria:**
  - `agentic-dev-improvements.md` converted to tracked issues (Asana or GitHub) and removed from the repo root, or moved to `docs/` with a clear status indicator
  - 14 stale remote branches reviewed: branches with no corresponding open PR deleted; work-in-progress branches converted to draft PRs with descriptions of remaining work

---

### L8 — Add README architecture section, link to CLAUDE.md, and add LICENSE

- **Severity:** Low
- **Risk reduction:** Low
- **Source dimensions:** Documentation
- **Evidence:** [documentation.md F3](dimensions/documentation.md#f3--readme-missing-license-ci-badges-and-contribution-guidelines)
- **Discipline:** docs
- **Acceptance criteria:**
  - `README.md` includes a brief Architecture section (or a link to `CLAUDE.md`)
  - A `LICENSE` file exists in the repo root (content: MIT or Apache 2.0 per MBTA standard practice)
  - README step numbering corrected (the `npm --prefix assets i` step numbering resets)

---

### L9 — Protect Swagger UI endpoint with authentication or disable in production

- **Severity:** Medium
- **Risk reduction:** Low
- **Source dimensions:** Security
- **Evidence:** [security.md F2](dimensions/security.md#f2--swagger-ui-accessible-without-authentication)
- **Discipline:** security
- **Note:** Lower risk-reduction score because the API itself is protected; Swagger exposure is an information disclosure issue, not a direct access control bypass.
- **Acceptance criteria:**
  - `/api/swagger` route restricted to the `:developer` role plug, or disabled entirely in non-development environments
  - Change confirmed in router configuration and tested: unauthenticated request to `/api/swagger` returns 403 or 404 in staging

---

### L10 — Establish staging-to-production promotion SLA

- **Severity:** Medium
- **Risk reduction:** Low
- **Source dimensions:** Delivery
- **Evidence:** [delivery.md F1](dimensions/delivery.md#f1--production-requires-a-manual-release-tag-no-full-cd-to-production)
- **Discipline:** build
- **Acceptance criteria:**
  - A documented policy exists stating the maximum window between a staging deployment and a production promotion (e.g. "2 business days unless a blocking issue is identified")
  - Policy linked from the deployment runbook or `README.md`

---

### L11 — Add `CODEOWNERS` file routing PRs to relevant reviewers

- **Severity:** Low
- **Risk reduction:** Low
- **Source dimensions:** Delivery
- **Evidence:** [delivery.md F4](dimensions/delivery.md#f4--no-codeowners-file)
- **Discipline:** build
- **Acceptance criteria:**
  - `.github/CODEOWNERS` created with at minimum entries for: `lib/alerts_ui/jobs/`, `lib/alerts_ui/feed_output/`, `lib/alerts_ui_web/live/create_alert_mono_live/`, and `lib/alerts_ui_web/live/create_alert_live.ex`

---

## Index by Source Dimension

| Dimension | Items |
|-----------|-------|
| Architecture | N5 (partial), X1, X2, X4, X10, L4 |
| Delivery | L6, L7 (partial), L10, L11 |
| Documentation | N5 (partial), X5, X9, L1, L4, L7, L8 |
| Maintainability | N5, X2 (partial), X5 (partial) |
| Performance | N2, N3, X6 (partial), X8 |
| Reliability | N1, N3 (partial), N5 (partial), X3, X6, X7 |
| Security | N4, L2, L3, L9 |
| Test Quality | N5 |
