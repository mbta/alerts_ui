# Architecture

_Generated: 2026-05-14T17:45:00-05:00_
_Repos covered: alerts_ui_

## Summary

`alerts_ui` follows Phoenix conventions well: a two-namespace split (`AlertsUI` for business logic, `AlertsUIWeb` for presentation), Ecto context modules at the DB boundary, and Oban workers cleanly separated in `lib/alerts_ui/jobs/`. The newer `create_alert_mono_live/` flow introduces a well-designed `Slice` protocol that correctly localizes form-step concerns. The most significant architectural flaw is a confirmed module cycle between `CreateAlertLive` and four of its child `FormComponents` — the parent dispatches to children, and the children call back into the parent for utility functions. A second structural concern is the `FormComponents.Helpers` namespace acting as a coupling magnet with 49 import lines across the codebase, including 6 inverted imports from the business layer (`lib/alerts_ui/`) into the web layer. No architectural decision records (ADRs) exist.

**Overall grade:** B

## Framework anchors

- ISO/IEC 25010 §6.5.1 — Modularity sub-characteristic
- Robert C. Martin package metrics — Instability (I), Acyclic Dependencies Principle (ADP)
- Stable Dependencies Principle (SDP) — depend in the direction of stability
- Light DDD — bounded contexts and ubiquitous language

## Top-Level Module Map

| Namespace | Responsibility |
|-----------|----------------|
| `AlertsUI.Models.*` | Ecto schemas — Alert, InformedEntity, ActivePeriod, Effect, Cause, User, etc. |
| `AlertsUI.DBContexts.*` | Ecto query contexts — `Alerts`, `Users`; all DB access routes through here |
| `AlertsUI.FeedOutput.*` | GTFS-RT/JSON feed assembly and S3 write pipeline |
| `AlertsUI.Jobs.*` | Oban background workers — FeedWriter, FeedChecker, FeedExporter, RecurringAlertUpdater |
| `AlertsUI.AlertValidation.*` | Alert validation against live GTFS data |
| `AlertsUI.IBIAlertImporter.*` | IBI third-party alert ingestion and conversion |
| `AlertsUI.Trapeze.*` | Trapeze SFTP work-order bridge |
| `AlertsUI.Helpers.*` | Pure utility functions — datetime math, recurrence helpers, reminder time handling |
| `AlertsUI.Configs.*` | Static configuration data (mode-effect combinations) |
| `AlertsUIWeb.Live.*` | Phoenix LiveView modules — alert creation (legacy + mono), alert listing, admin |
| `AlertsUIWeb.FormComponents.*` | Shared LiveView function components and form helpers |
| `AlertsUIWeb.FormComponents.Helpers.*` | Coupling magnet — 22 helper modules (formatters, validators, auto-text builders) |
| `AlertsUIWeb.Components.*` | Phoenix function components — `SharedComponents`, `CoreComponents`, modals |
| `AlertsUIWeb.Controllers.*` | Traditional Phoenix controllers — API, page |
| `Ueberauth.Strategy.*` | OIDC/Keycloak authentication strategy shim |
| `MBTAV3API.*` | External git dependency — MBTA V3 API client with ConCache-backed repos |

## Findings

### F1 — Confirmed dependency cycle: `CreateAlertLive` ↔ `FormComponents`

- **Severity:** High
- **Location:**
  - `CreateAlertLive` → `FormComponents.{AffectedService, AlertDetails, StopRouteAffectedService, AccessAffectedService}` (imports at `create_alert_live.ex:30-43`)
  - `FormComponents.AffectedService` → `CreateAlertLive.get_routes/1`, `.get_stops/3` (`affected_service.ex:10`, `:433`, `:442`)
  - `FormComponents.AlertDetails` → `CreateAlertLive.filter_out_old_trips/1` (`alert_details.ex:9`, `:120`)
  - `FormComponents.StopRouteAffectedService` → `CreateAlertLive.get_schedules_by_date/2` etc. (`stop_route_affected_service.ex:10`)
  - `FormComponents.AccessAffectedService` → `CreateAlertLive.get_schedules_by_date/2` (`access_affected_service.ex:11`)
- **Evidence:**
  ```
  CreateAlertLive  →  FormComponents.AffectedService
  FormComponents.AffectedService  →  CreateAlertLive.get_routes/1
  ```
  Violates the Acyclic Dependencies Principle (ADP). The form components are not self-contained and cannot be compiled, tested, or reused without `CreateAlertLive`.
- **Impact:** The parent LiveView and its child components have mutual compile-time dependencies. Extracting any form component for reuse requires dragging `CreateAlertLive` along. Testing the components in isolation requires the full parent. This also means the functions `get_routes/1`, `get_stops/3`, `get_schedules_by_date/2`, and `filter_out_old_trips/1` are not in a logically appropriate home — they are query/helper functions that belong in a service or context module, not in a LiveView.

### F2 — Business layer imports web layer (`lib/alerts_ui/` → `AlertsUIWeb.FormComponents.Helpers.*`)

- **Severity:** High
- **Location:** `alert_builder.ex:13`, `alert_history.ex:10`, `active_status.ex:7`, `db_contexts/alerts.ex:10`, `models/informed_entity.ex:8`, `trapeze/work_order.ex:7-8`
- **Evidence:** Six modules in `lib/alerts_ui/` alias `AlertsUIWeb.FormComponents.Helpers.*` helpers (e.g. `SelectFormatter`, `ServiceEffectCombinations`, `ContentFormatter`, `EffectsForRouteTypes`, `AutoText.*`). The dependency direction is inverted: the domain layer is downstream of the web presentation layer.
- **Impact:** `lib/alerts_ui/` cannot be compiled, loaded, or tested without `lib/alerts_ui_web/`. This also means `FormComponents.Helpers` modules carry more responsibility than their name implies — they are domain utilities masquerading as view helpers. Any Phoenix upgrade or web framework swap would require updating domain-layer modules. (SDP violation: the stable domain layer depends on the less-stable web layer)

### F3 — `FormComponents.Helpers` is a coupling magnet with 49 inbound imports

- **Severity:** Medium
- **Location:** `lib/alerts_ui_web/live/form_components/helpers/` (22 modules)
- **Evidence:** `grep -rn "alias AlertsUIWeb.FormComponents.Helpers"` across `lib/` yields 49 import lines, touching: all 6 business-layer violators (F2), most LiveView files, multiple `SharedComponents`, and 3 mono-flow slices. The directory contains formatters, validators, sort-order helpers, auto-text builders, and Green Line topology logic — a heterogeneous mix with no shared semantic boundary.
- **Impact:** Modules inside `FormComponents.Helpers` cannot be modified without ripple risk across the full application. The name `Helpers` provides no guidance on what belongs there or what shouldn't be added. Any new utility function will default to this namespace, accelerating the fan-in. (Robert C. Martin — utility packages with high instability and high fan-in are at risk of cascading change)

### F4 — `CreateAlertLive` used as a utility library by the mono-flow slices

- **Severity:** Medium
- **Location:** `create_alert_mono_live/slices/affected_service_slice.ex:4`, `stop_route_service_slice.ex:6,12`, `access_affected_service_slice.ex:6`
- **Evidence:** Three slices in the newer `create_alert_mono_live/` architecture import `AlertsUIWeb.CreateAlertLive` to call its utility functions (route/stop/schedule fetching). The `Slice` protocol was designed to allow independent, substitutable form-step implementations — but importing the legacy LiveView couples every slice to the legacy flow.
- **Impact:** The mono flow cannot be fully decoupled from the legacy flow. Removing `CreateAlertLive` (the stated future goal) requires first extracting those utility functions. The coupling also means the architectural benefit of the `Slice` protocol (independent testability of each slice) is partially negated. This is a concrete blocker for the legacy-flow retirement mentioned in maintainability F3.

### F5 — Domain models import MBTA API I/O layer

- **Severity:** Medium
- **Location:** `lib/alerts_ui/models/alert.ex:35-36`; `lib/alerts_ui/models/informed_entity.ex:9`
- **Evidence:** `Alert` imports `MBTAV3API.Stops.Repo` and calls `StopsRepo.get_parent(stop_id)` (lines 471, 508) — an HTTP-backed cache call — inside what appears to be a changeset validation or entity-building function. `InformedEntity` imports `MBTAV3API.Routes.Route` for type purposes.
- **Impact:** The `Alert` domain model is not a pure data structure; it embeds an outbound HTTP call. Testing `Alert` changeset logic requires the `MBTAV3API.Stops` ConCache to be started, or the test must mock `StopsRepo`. This increases the surface area required to test a domain model. The `Route` type import in `InformedEntity` is lower risk (type only, no call), but it couples the schema to an external type definition. (SDP violation: stable domain model depends on less-stable external HTTP client)

### F6 — No architectural decision records (ADRs)

- **Severity:** Low
- **Location:** Entire codebase (no `docs/adr/`, `docs/architecture/`, `decisions/`, or equivalent)
- **Evidence:** Exhaustive search found no ADR directory or RFC files. The `Slice` protocol, dual alert creation flows, and the `FormComponents.Helpers` coupling pattern are significant architectural choices with no written rationale.
- **Impact:** Architectural intent is communicated through code and contributor knowledge only. New contributors have no documented reason for the `Slice` pattern versus the legacy form approach, or why `FormComponents.Helpers` was placed in the web layer. Decisions made in the original design are invisible. (ISO/IEC 25010 §6.5 — analysability)

## Metrics

| Repo | Metric | Value | Notes |
|------|--------|-------|-------|
| alerts_ui | Layering scheme | Phoenix MVC + context pattern | `AlertsUI` context + `AlertsUIWeb` web — generally clean with noted violations |
| alerts_ui | Top-level namespaces | 16 | See module map above |
| alerts_ui | Confirmed module cycles | 1 | `CreateAlertLive` ↔ `FormComponents` (4 child components) |
| alerts_ui | Suspected additional cycles | 1 | Mono slices → `CreateAlertLive` (not a strict cycle but increases coupling) |
| alerts_ui | Inverted layer dependencies | 6 modules | `lib/alerts_ui/` → `AlertsUIWeb.FormComponents.Helpers.*` |
| alerts_ui | Coupling magnets | 2 | `FormComponents.Helpers` (49 imports), `CreateAlertLive` (8 back-callers as utility) |
| alerts_ui | ADR presence | None | No `docs/adr/` or equivalent |
| alerts_ui | Cross-service coupling | N/A | Single-repo |
| alerts_ui | `Slice` protocol quality | High | Well-defined 5-callback protocol; good extensibility design |

## Recommendations

- **R1** — Break the `CreateAlertLive` ↔ `FormComponents` cycle by extracting `get_routes/1`, `get_stops/3`, `get_schedules_by_date/2`, and `filter_out_old_trips/1` from `CreateAlertLive` into a dedicated `AlertsUI.AlertFormData` (or similar) context module. Both `CreateAlertLive` and the form components would then depend on this shared module — no cycle. [Horizon: next] [Risk reduction: Hi]
- **R2** — Move `FormComponents.Helpers` modules that contain domain logic (formatters, effect lookups, service-effect combinations) out of `AlertsUIWeb` into `AlertsUI` (e.g. `AlertsUI.Formatting`, `AlertsUI.ServiceEffects`). Remove the 6 inverted imports from `lib/alerts_ui/`. This resolves both F2 and F3 in one sweep. [Horizon: next] [Risk reduction: Hi]
- **R3** — Remove the direct `MBTAV3API.Stops.Repo` call from `Alert` model. Move the stop-parent lookup to the context (`DBContexts.Alerts` or a new `AlertBuilder` step) so the domain model remains pure and testable without starting the API cache. [Horizon: next] [Risk reduction: Med]
- **R4** — Decouple mono flow slices from `CreateAlertLive`: once R1 is done, update the 3 slices that import `CreateAlertLive` to import from the new shared context module instead. This removes the last structural blocker to retiring the legacy flow. [Horizon: next] [Risk reduction: Med]
- **R5** — Establish a lightweight ADR practice: write one ADR each for the `Slice` protocol decision and the planned `create_alert_live.ex` retirement. A simple `docs/adr/` directory with 3-5 line markdown files (Context / Decision / Consequences) is sufficient. [Horizon: later] [Risk reduction: Lo]

## Confidence

- **Cycle detection (F1)** is confirmed by bidirectional grep: `CreateAlertLive` imports `FormComponents.*`, and `affected_service.ex`, `alert_details.ex`, `stop_route_affected_service.ex`, and `access_affected_service.ex` each explicitly alias `AlertsUIWeb.CreateAlertLive` and call its functions. High confidence.
- **Inverted dependency count (F2)** is confirmed by exhaustive grep on `lib/alerts_ui/` for `alias AlertsUIWeb`. 6 modules found; high confidence this is the complete list.
- **`FormComponents.Helpers` import count (F3)** is 49 from grep; includes alias, import, and use lines. The exact call count is lower; the coupling signal is directional but accurate.
- **ADR absence** is confirmed by filesystem search. High confidence.
- **v1 cycle detection is heuristic** — full cycle analysis would require a tool like `mix xref graph`. False negatives (undiscovered cycles) are possible for indirect cycles spanning 3+ hops. The confirmed cycle is direct and high-confidence.
