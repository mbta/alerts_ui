# Test Quality

_Generated: 2026-05-14T15:50:00-05:00_
_Repos covered: alerts_ui_

## Summary

The `alerts_ui` test suite is substantial and well-structured: 102 test files, ~29,100 LOC of tests, ~1,210 test cases, covering the business logic and legacy UI flows with high-quality LiveView integration tests and real-database fixtures. Coverage reports from CI show 100% line coverage for all 202 measured modules. However, the measured coverage is significantly narrowed by a 33-module `ignore_modules` exclusion list in `mix.exs`, and the entire `create_alert_mono_live/` directory — the newer, primary alert-creation flow at 3,119 LOC — is completely absent from both the test directory and the coverage report. The `stream_data` property-testing dependency is declared but unused. No flakiness markers or skipped tests exist, which is a genuine positive signal.

**Overall grade:** B

## Framework anchors

- ISO/IEC 25010 §6.5.4 — Testability sub-characteristic
- DORA / Accelerate — Continuous testing as a delivery practice
- Test pyramid (Mike Cohn) — unit / integration / e2e proportions

## Findings

### F1 — `create_alert_mono_live/` has zero test coverage (3,119 LOC, 19 files)

- **Severity:** Critical
- **Location:** `lib/alerts_ui_web/live/create_alert_mono_live/` (19 files, 3,119 LOC); no corresponding test directory exists
- **Evidence:** `find test/ -name "*mono*"` returns no results. None of the `create_alert_mono_live` module names appear in `cover/*.html`. Searching the test directory for `CreateAlertMonoLive` returns zero matches. The 19 modules — including `AlertData`, `Slice` protocol implementations, and all 10 `*Slice` modules — are entirely absent from coverage.
- **Impact:** The newer, stated-successor alert-creation flow has no regression safety net. Any change to `AlertData`, any new `Slice` implementation, or any edge case in the combination logic can break production alert creation without test failure. As this flow is actively developed (it is the intended replacement for the legacy flow), the coverage gap grows with each feature.

### F2 — 33 modules excluded from coverage measurement, including critical production modules

- **Severity:** High
- **Location:** `mix.exs:19–58` (`test_coverage: [ignore_modules: [...]]`)
- **Evidence:** The exclusion list contains 33 entries including `AlertsUIWeb.SharedComponents` (1,583 LOC, top churn file), `AlertsUIWeb.CoreComponents` (764 LOC), `AlertsUIWeb.Router`, `AlertsUI.IBIAlertImporter` (1,005 LOC), `AlertsUI.IBIAlertImportParser`, and all 10 GTFS protobuf definition modules. The 100% coverage number applies only to the remaining 202 measured modules — the true system-wide coverage is lower.
- **Impact:** Coverage CI checks give a false green signal. Changes to `SharedComponents` (the most-churned file at 107 times in 2 years) and `IBIAlertImporter` have no measured test coverage at all. The team may be unaware that these exclusions exist.

### F3 — Heavy reliance on `Mock` library for MBTA API boundary mocking

- **Severity:** Medium
- **Location:** 289 mock-related lines across `alert_builder_test.exs`, `create_alert_live_test.exs`, `access_affected_service_test.exs`, `alert_details_test.exs`, `view_alerts_live_test.exs`, and others
- **Evidence:** Tests use `with_mock(RoutesRepo, ...)`, `with_mock(StopsRepo, ...)`, `with_mock(FacilitiesRepo, ...)` to stub the MBTA v3 API repos. Example: `alert_builder_test.exs:30-33` — `with_mocks([{RoutePatternsRepo, [], [by_route_id: fn ... -> [] end]}, ...])`.
- **Impact:** Module-level mocking with `mock` patches at the global module level, making test isolation dependent on test execution order and not concurrency-safe without `async: false`. More significantly, when the MBTA API shape changes (new fields, changed response structures), mocked tests pass while real integration fails. No behaviour/mock contracts (Mox) are in use. (ISO/IEC 25010 §6.5.4 — testability)

### F4 — No end-to-end tests; E2E layer entirely absent

- **Severity:** Medium
- **Location:** No `cypress/`, `playwright/`, `e2e/`, or BDD test directories
- **Evidence:** Full directory scan finds no E2E tooling. CI workflow (`elixir.yml`) runs only Elixir tests — no browser automation step.
- **Impact:** Multi-step alert creation flows (select route type → fill details → preview → submit) have no automated validation that the assembled LiveView renders and submits correctly end-to-end. Regressions in the user-facing form flow are only caught manually.

### F5 — `stream_data` dependency declared but no property tests exist

- **Severity:** Low
- **Location:** `mix.exs` (stream_data ~> 1.3.0 in test env); `test/` directory
- **Evidence:** `grep -rn "StreamData\|use ExUnitProperties\|property "` across all test files returns zero results. `stream_data` is a dependency but no property-based tests have been written.
- **Impact:** The alert combination/timing logic (many interacting boolean flags in `auto_text_duration.ex`) is an ideal candidate for property testing. The investment in the dependency was not followed through. Either the dependency should be used or removed.

### F6 — `alert_builder_test.exs` is 3,745 LOC — largest test file in codebase

- **Severity:** Low
- **Location:** `test/alerts_ui/alert_builder_test.exs` (3,745 LOC)
- **Evidence:** The file is 3× the size of its 1,215-LOC source. It has no subdivision into separate test modules for sub-functions. All 23 source functions are tested in a single flat file with heavy `with_mocks` nesting.
- **Impact:** Difficult to navigate; running a targeted subset of tests requires line numbers rather than test name patterns. Mirrors the source file's own maintainability concerns (see maintainability F2).

## Metrics

| Repo | Metric | Value | Notes |
|------|--------|-------|-------|
| alerts_ui | Total test files | 102 | `.exs` files under `test/` |
| alerts_ui | Test LOC | ~29,100 | `find` + `wc -l` |
| alerts_ui | Source LOC (production) | ~63,200 | Elixir + templates + JS |
| alerts_ui | Test-to-code ratio | 0.46 | Informative only; not a quality proxy |
| alerts_ui | Total test cases | ~1,210 | Count of `test "` patterns |
| alerts_ui | Unit layer | Yes | `use AlertsUI.DataCase` — 92 files; pure ExUnit — 12 files |
| alerts_ui | Integration layer | Yes | LiveView tests with real DB; `live/` + `live_isolated_component` |
| alerts_ui | E2E layer | No | No browser automation |
| alerts_ui | Coverage % (measured) | 100% | Per CI HTML reports; applies to 202 of ~235+ non-test modules |
| alerts_ui | Modules excluded from coverage | 33 | `mix.exs:ignore_modules` |
| alerts_ui | `create_alert_mono_live` coverage | 0% | 19 files, 3,119 LOC entirely untested |
| alerts_ui | Skipped tests | 0 | No `@tag :skip` or `@moduletag :skip` found |
| alerts_ui | Flakiness markers | 0 | No retry annotations or flaky comments |
| alerts_ui | Property-based tests | 0 | `stream_data` declared but unused |

## Recommendations

- **R1** — Add tests for `create_alert_mono_live/` — start with `AlertData` changeset validation and the `AffectedServiceSlice` / `AlertDetailsSlice` `Slice` protocol implementations, which contain the most business logic. Target the `mount/3` → `extract/3` → `validate/3` flow per slice. [Horizon: now] [Risk reduction: Hi]
- **R2** — Audit and justify the `ignore_modules` exclusion list in `mix.exs`. Remove entries that can be tested (e.g. `SharedComponents`, `IBIAlertImporter`) or move them to a separate tracked exclusion config with a comment explaining why each is excluded. [Horizon: next] [Risk reduction: Hi]
- **R3** — Replace `Mock`-library module patching with `Mox` behaviours for the MBTA API repos (`RoutesRepo`, `StopsRepo`, `FacilitiesRepo`, etc.). Define explicit behaviour specs so mock contracts are compile-time checked and tests can safely run `async: true`. [Horizon: next] [Risk reduction: Med]
- **R4** — Write at least one property-based test for `AutoTextDuration.build_onetime_string/1` using the existing `stream_data` dependency to enumerate the 5-flag boolean space and confirm no clause is missing. [Horizon: later] [Risk reduction: Med]
- **R5** — Either add a basic Playwright smoke test for the mono alert-creation flow (route-type → effect → submit) or remove the E2E gap acknowledgment from the risk register once the mono flow's unit tests are established. [Horizon: later] [Risk reduction: Lo]

## Confidence

- **Coverage percentages** are read directly from `cover/*.html` generated by the most recent local `mix test --cover` run. The 100% values are high confidence for the measured modules, but the exclusion list substantially limits what is measured. The audit notes this but cannot recalculate the actual system-wide percentage without re-running the test suite.
- **Test case count** (~1,210) is from `grep -c 'test "'` — this undercounts describe-block tests that use non-string patterns, so treat as a floor estimate.
- **`create_alert_mono_live` zero-coverage assessment** is confirmed by: absence from test directory, absence from `cover/` HTML files, and exhaustive grep. High confidence.
- **Mock usage count** (289 lines) counts all lines containing `mock` or `Mock`, which includes some alias lines and comments. Actual `with_mock()`/`with_mocks()` call count is lower; the signal (pervasive mocking) is directionally accurate.
