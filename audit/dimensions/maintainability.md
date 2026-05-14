# Maintainability

_Generated: 2026-05-14T15:30:00-05:00_
_Repos covered: alerts_ui_

## Summary

The `alerts_ui` codebase follows Phoenix conventions well — clear context/model/web layering, consistent naming, and liberal use of Ecto schemas and protocols for structure. The primary maintainability debt is a recurring layer-boundary violation: six business-logic modules alias and call directly into `AlertsUIWeb.FormComponents.Helpers.*`, blurring the separation between business logic and UI concerns. Seventeen production Elixir files exceed 500 LOC (the largest at 1,583 LOC), and the two parallel alert-creation flows (`create_alert_live.ex` and `create_alert_mono_live/`) both appear in the top 5 churn hot-spots, imposing ongoing dual-maintenance cost. These issues are real but not catastrophic — the codebase is actively maintained with clear intent, and the concerns concentrate in well-identified files.

**Overall grade:** B

## Framework anchors

- ISO/IEC 25010 §6.5 — Maintainability (modularity, analysability, modifiability, reusability)
- ISO/IEC 5055 MN-FN-LOC — function/file size thresholds
- Tornhill, *Your Code as a Crime Scene* — churn × complexity hot-spot analysis

## Findings

### F1 — Business-logic modules depend on the web layer

- **Severity:** High
- **Location:** `lib/alerts_ui/alert_builder.ex:13`, `lib/alerts_ui/alert_history.ex:10`, `lib/alerts_ui/active_status.ex:7`, `lib/alerts_ui/db_contexts/alerts.ex:10`, `lib/alerts_ui/models/informed_entity.ex:8`, `lib/alerts_ui/trapeze/work_order.ex:7-8`
- **Evidence:** Six modules under `lib/alerts_ui/` alias and call `AlertsUIWeb.FormComponents.Helpers.*` (e.g. `SelectFormatter`, `ServiceEffectCombinations`, `ContentFormatter`, `EffectsForRouteTypes`, `AutoText.*`). Example: `alert_builder.ex:13` — `alias AlertsUIWeb.FormComponents.Helpers.{SelectFormatter, ServiceEffectCombinations}`.
- **Impact:** The `alerts_ui` business logic layer cannot be tested or compiled independently from the web layer. Any refactor of `FormComponents.Helpers` cascades into core domain modules. This inverts the expected dependency direction (ISO/IEC 25010 §6.5 — modularity) and makes the helpers resistant to extraction or replacement. (ISO/IEC 5055 — coupling constraint)

### F2 — `alert_builder.ex` is a 1,215-LOC procedural assembler with loose typing

- **Severity:** High
- **Location:** `lib/alerts_ui/alert_builder.ex` (1,215 LOC, 23 functions, churned 93 times in 2 years)
- **Evidence:** The primary `build_alert/4` function chains 13 `Map.merge/2` calls, each delegating to a private function. The input type (`alert_data_t`) is a 33-field map type spec — not a struct. `Map.get(alert_data, ...)` appears 49 times throughout the file, making key typos invisible at compile time.
- **Impact:** Any change to the alert data shape requires auditing 49+ call sites. The absence of struct-level compile-time checks means regressions surface only at runtime or in tests. As the top-3 churn hot-spot, every alert-creation feature touches this file. (ISO/IEC 5055 MN-FN-LOC)

### F3 — Dual alert-creation flows both in active churn

- **Severity:** High
- **Location:** `lib/alerts_ui_web/live/create_alert_live.ex` (848 LOC, 85 functions, churned 77 times) and `lib/alerts_ui_web/live/create_alert_mono_live/` (multiple files)
- **Evidence:** The legacy `create_alert_live.ex` is ranked 5th in churn over the last 2 years despite the mono flow being the stated successor. Both flows must stay functionally in sync, and bug fixes applied to one may not be applied to the other.
- **Impact:** Dual-maintenance creates permanent divergence risk. Any new alert feature (new timing type, new combination) must be implemented twice. The legacy flow's 85-function, 848-LOC structure with 77 churn events suggests it is not read-only.

### F4 — `auto_text_duration.ex` has 37 pattern-match clauses on `build_onetime_string`

- **Severity:** Medium
- **Location:** `lib/alerts_ui_web/live/form_components/helpers/auto_text/auto_text_duration.ex:129–515` (749 LOC, 86 function heads)
- **Evidence:** `build_onetime_string/1` has 37 pattern-match clauses spread across ~390 lines. Each clause matches a map with slightly different boolean flag combinations (`starts_today?`, `ends_today?`, `within_same_service_day?`, etc.). There is no truth-table comment or exhaustion proof.
- **Impact:** Adding a new timing scenario requires finding the correct insertion point among 37 clauses. Missing a case silently falls through to `build_onetime_string(_), do: ""`, producing empty auto-text with no error. The implicit enumeration of a 5-flag boolean space (32 possible combinations) is undocumented. (ISO/IEC 25010 §6.5 — analysability)

### F5 — 17 production files exceed 500 LOC

- **Severity:** Medium
- **Location:** across `lib/` (see Metrics table)
- **Evidence:** `shared_components.ex` (1,583 LOC, 37 UI function components), `alert_builder.ex` (1,215 LOC), `ibi_alert_importer.ex` (1,005 LOC), `affected_service.ex` (969 LOC), `create_alert_live.ex` (848 LOC). 17 files total exceed 500 LOC.
- **Impact:** Files of this size have higher per-line defect density and are harder to review in PRs. The fact that the three largest files are all in the top-5 churn list compounds the risk. (ISO/IEC 5055 MN-FN-LOC)

### F6 — `ibi_alert_importer.ex` mixes I/O, parsing, and domain logic (1,005 LOC)

- **Severity:** Medium
- **Location:** `lib/alerts_ui/ibi_alert_importer.ex` (1,005 LOC, 69 functions, churned 83 times)
- **Evidence:** The file fetches remote JSON, parses it, maps it to alert domain objects, and handles retry/error logic — all in one module. There is a separate `ibi_alert_importer/` directory with `ibi_import_worker.ex` and `parent_child_stop_mapping.ex`, suggesting earlier partial extraction that stalled.
- **Impact:** Testing the domain-mapping logic requires either mocking HTTP or testing the full I/O path. The incomplete extraction leaves the file at high churn and high LOC. (ISO/IEC 25010 §6.5 — modifiability, testability)

## Metrics

| Repo | Metric | Value | Notes |
|------|--------|-------|-------|
| alerts_ui | Files >500 LOC (production `lib/`) | 17 | LLM-counted via `find` + `wc -l` |
| alerts_ui | Largest file | `shared_components.ex` — 1,583 LOC | UI component library; many small components |
| alerts_ui | Average cyclomatic complexity | Medium | LLM-estimated from sampled files; `alert_builder.ex` and `auto_text_duration.ex` are High individually |
| alerts_ui | Top 5 hot-spots (churn × size) | `shared_components.ex` (107 churns, 1583 LOC), `affected_service.ex` (98, 969), `alert_builder.ex` (93, 1215), `ibi_alert_importer.ex` (83, 1005), `create_alert_live.ex` (77, 848) | `git log` last 2 years |
| alerts_ui | Duplication impression | Minimal | No pervasive copy-paste identified; pattern-match proliferation in `auto_text_duration.ex` is idiomatic, not duplicated logic |
| alerts_ui | Layer-boundary violations | 6 modules | `lib/alerts_ui/**` aliasing `AlertsUIWeb.FormComponents.Helpers.*` |

## Recommendations

- **R1** — Extract `FormComponents.Helpers` utilities that are used by `lib/alerts_ui/` into a framework-agnostic `lib/alerts_ui/` module (e.g. `AlertsUI.Formatting`, `AlertsUI.ServiceEffects`). Remove the web-layer alias from all six offending business-logic modules. [Horizon: next] [Risk reduction: Hi]
- **R2** — Convert `AlertBuilder.alert_data_t` from a loosely-typed map to an Ecto embedded schema or a plain struct so that missing keys are caught at compile time. Replace `Map.get(alert_data, ...)` call sites with struct field access. [Horizon: next] [Risk reduction: Hi]
- **R3** — Establish a formal migration plan to retire `create_alert_live.ex`: freeze new feature additions to the legacy flow now, track remaining gaps between flows in a single issue, and set a deletion target. [Horizon: next] [Risk reduction: Med]
- **R4** — Refactor `auto_text_duration.ex:build_onetime_string/1` to replace the 37-clause pattern match with a decision table (a map from flag-tuple to string-builder function), and add a fallthrough clause that logs/raises rather than silently returning `""`. [Horizon: later] [Risk reduction: Med]
- **R5** — Split `ibi_alert_importer.ex` into: an HTTP/parse module (I/O boundary), a domain-mapping module, and a retry/orchestration module. The directory scaffold already exists. [Horizon: later] [Risk reduction: Med]

## Confidence

- **Churn counts** are directly observed from `git log --name-only --since="2 years ago"`. High confidence.
- **LOC counts** are from `find` + `wc -l` on the `lib/` directory. High confidence.
- **Cyclomatic complexity** is LLM-estimated by reading representative functions. "High" for `alert_builder.ex` and `auto_text_duration.ex` is defensible from observable nesting and clause counts, but exact numbers were not measured with a tool like `lizard` or `sobelow`. Treat as directional, not exact.
- **Duplication assessment** is impressionistic — no `fdupes`/`cpd` tool was run. The assessment is based on reading hot-spot files; subtle copy-paste duplication may exist in unsampled files.
- **Layer violation count (6 modules)** was found via `grep -rn "alias AlertsUIWeb\."` on `lib/alerts_ui/` — high confidence this is exhaustive.
