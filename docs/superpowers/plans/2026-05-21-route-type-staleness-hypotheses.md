# Route Type Staleness — Hypothesis Proof Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prove or disprove each of the five hypotheses about why page-2 service selections survive a route-type change on page 1.

**Architecture:** Each task writes a test (or one static check) that makes a single, falsifiable assertion. Tests that assert _correct_ behavior will FAIL when the hypothesis is confirmed and PASS when it is denied — the test result IS the evidence. No code is fixed; failures are the expected/desired outcome for H1–H4.

**Tech Stack:** ExUnit, Phoenix.LiveViewTest, Ecto.Changeset, `AlertsUIWeb.CreateAlertMonoLive.AlertData` (called directly, same pattern as `alert_data_test.exs`)

---

## Background — data-flow summary

Route type and effect name live in the URL path
(`/alerts/mono/new/:route_type/:effect_name`). On every `handle_params`/`validate`
call, `sync_socket/2` → `AlertData.sync/3` is invoked:

```
cast(form.source, params["alert_data"] || %{}, form_fields)
→ transform/3   (runs each Slice's transform, including UrlSlice and AffectedServiceSlice)
→ validate/3
→ assigns/2
```

`UrlSlice.transform` re-casts `:route_type`, `:effect_name`, `:combination` from URL params.
`AffectedServiceSlice.transform` does **not** clear `:route_ids`, `:trip_ids`, or
`:stop_ids` when route_type changes. `move_progress` back explicitly changes only those
three fields and then calls `push_patch` back to the root URL, after which
`handle_params` calls `sync` with empty `"alert_data"` params.

---

## Files

| Action  | Path |
|---------|------|
| Create  | `test/alerts_ui_web/live/create_alert_mono_live/route_type_change_test.exs` |
| Read    | `lib/alerts_ui_web/live/create_alert_mono_live.ex` (move_progress handler, lines 105-121) |
| Read    | `lib/alerts_ui_web/live/create_alert_mono_live/slices/affected_service_slice.ex` (transform, lines 66-76; @update_selection_targets, lines 204-229) |
| Read    | `lib/alerts_ui_web/live/form_components/affected_service.ex` (adjust_selections/1, lines 423-429) |

---

## Task 1: Prove H1 — `move_progress` back does not clear service selections

**Claim:** When the user returns to page 1 via the step nav, the handler at
`create_alert_mono_live.ex:107` only clears `route_type`/`effect_name`/`combination`;
`route_ids` and `trip_ids` survive.

**Evidence method:** Simulate the exact changeset manipulation the handler performs, then
run `AlertData.sync` with empty URL params (what `handle_params` sees after the
`push_patch`). Assert that `route_ids` is empty — this assertion will **FAIL**,
confirming H1.

**Files:**
- Create: `test/alerts_ui_web/live/create_alert_mono_live/route_type_change_test.exs`

- [ ] **Step 1: Create the test file with the H1 describe block**

```elixir
defmodule AlertsUIWeb.CreateAlertMonoLive.RouteTypeChangeTest do
  use ExUnit.Case, async: false
  use AlertsUIWeb.ConnCase

  import Phoenix.LiveViewTest

  alias AlertsUIWeb.CreateAlertMonoLive.AlertData
  alias AlertsUIWeb.CreateAlertMonoLive.Slice
  alias AlertsUIWeb.CreateAlertMonoLive.Slices.AffectedServiceSlice

  describe "H1: move_progress back does not clear service selections" do
    @tag :logged_in_user
    test "route_ids and trip_ids are cleared when returning to page 1", %{conn: conn} do
      # Mount on page 2: route_type and effect_name already set via URL path segments
      {:ok, view, _html} = live(conn, "/alerts/mono/new/commuter_rail/suspension")
      socket = :sys.get_state(view.pid).socket

      # Simulate the user having selected a commuter rail route on page 2.
      # The `validate` event stores these in the changeset via form submission.
      changeset_with_routes =
        Ecto.Changeset.change(socket.assigns.form.source, %{
          route_ids: ["CR-Worcester"],
          trip_ids: ["trip-1"]
        })

      # Replicate what handle_event("move_progress", %{"value" => "route_type_and_effect"}, ...)
      # does at create_alert_mono_live.ex:107 — only these three fields are cleared:
      cleared_changeset =
        Ecto.Changeset.change(changeset_with_routes, %{
          route_type: nil,
          effect_name: nil,
          combination: nil
        })

      # Replicate what handle_params fires after push_patch to /alerts/mono/new/
      # (no "alert_data" key in URL params → AlertData.sync sees empty cast params)
      {_, after_back_socket} =
        case AlertData.sync(cleared_changeset, socket, %{}) do
          {:ok, s} -> {:ok, s}
          {:error, s} -> {:error, s}
        end

      # EXPECTED (correct behavior): going back should clear page-2 selections
      # ACTUAL   (bug):              they survive — this assertion will FAIL
      assert after_back_socket.assigns.form[:route_ids].value in [nil, []],
             "route_ids should be cleared after move_progress back, got: " <>
               inspect(after_back_socket.assigns.form[:route_ids].value)

      assert after_back_socket.assigns.form[:trip_ids].value in [nil, []],
             "trip_ids should be cleared after move_progress back, got: " <>
               inspect(after_back_socket.assigns.form[:trip_ids].value)
    end
  end
end
```

- [ ] **Step 2: Run the test and capture the failure output**

```bash
mix test test/alerts_ui_web/live/create_alert_mono_live/route_type_change_test.exs --seed 0 2>&1 | tail -30
```

Expected: **FAIL** with `route_ids` = `["CR-Worcester"]` → H1 confirmed.
If the test passes: H1 is false — some other mechanism clears the data.

- [ ] **Step 3: Commit the test file (failing is expected)**

```bash
git add test/alerts_ui_web/live/create_alert_mono_live/route_type_change_test.exs
git commit -m "test(hypothesis): H1 — move_progress back does not clear service selections"
```

---

## Task 2: Prove H2 — `push_route_type` URL change does not clear service selections

**Claim:** After going back, selecting a new route type triggers `push_route_type` →
`handle_params(%{"route_type" => "subway"})` → `AlertData.sync`. Nothing in the sync
pipeline clears `route_ids` from the prior route type.

**Evidence method:** Start from a changeset with commuter-rail `route_ids`, run
`AlertData.sync` with `%{"route_type" => "subway"}` as URL params (what `handle_params`
receives). Assert `route_ids` is empty — this assertion will **FAIL**, confirming H2.

**Files:**
- Modify: `test/alerts_ui_web/live/create_alert_mono_live/route_type_change_test.exs`

- [ ] **Step 1: Add the H2 describe block**

```elixir
  describe "H2: push_route_type URL change does not clear mismatched service selections" do
    @tag :logged_in_user
    test "route_ids from commuter_rail survive a route_type change to subway", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/mono/new/commuter_rail/suspension")
      socket = :sys.get_state(view.pid).socket

      # Simulate having commuter_rail routes selected on page 2
      changeset_with_cr_routes =
        Ecto.Changeset.change(socket.assigns.form.source, %{
          route_ids: ["CR-Worcester"]
        })

      # Simulate push_route_type("subway") → handle_params(%{"route_type" => "subway"})
      # Note: "alert_data" is not a key in URL params — only route_type is
      {_, after_route_change_socket} =
        case AlertData.sync(changeset_with_cr_routes, socket, %{"route_type" => "subway"}) do
          {:ok, s} -> {:ok, s}
          {:error, s} -> {:error, s}
        end

      # Sanity check: route_type did change
      assert after_route_change_socket.assigns.form[:route_type].value != 2,
             "route_type should have changed from commuter_rail (2)"

      # EXPECTED (correct behavior): route_ids should be cleared on route_type change
      # ACTUAL   (bug):              still ["CR-Worcester"] — this assertion will FAIL
      assert after_route_change_socket.assigns.form[:route_ids].value in [nil, []],
             "route_ids should be cleared when route_type changes, got: " <>
               inspect(after_route_change_socket.assigns.form[:route_ids].value)
    end
  end
```

- [ ] **Step 2: Run the test and capture the failure output**

```bash
mix test test/alerts_ui_web/live/create_alert_mono_live/route_type_change_test.exs --seed 0 2>&1 | tail -30
```

Expected: **FAIL** with `route_ids` = `["CR-Worcester"]` and `route_type` ≠ 2 → H2 confirmed.

- [ ] **Step 3: Commit**

```bash
git add test/alerts_ui_web/live/create_alert_mono_live/route_type_change_test.exs
git commit -m "test(hypothesis): H2 — push_route_type does not clear mismatched route_ids"
```

---

## Task 3: Characterize H3 — the `ensure_coherent_selections` placeholder and the `adjust_selections/1` reference

**Claim:** The comment at `affected_service_slice.ex:271` says
`"come back to this - see adjust_selections/1 in original"`. The test checks two things:

1. The transform pipeline as a whole does not clean route_ids on a route_type mismatch
   (confirming the placeholder was never filled in).
2. The referenced `adjust_selections/1` in `form_components/affected_service.ex` only
   strips `"default"` from arrays (select-all deselection) — it was never about
   route_type-based clearing. This refines the H3 narrative.

**Files:**
- Modify: `test/alerts_ui_web/live/create_alert_mono_live/route_type_change_test.exs`

- [ ] **Step 1: Add the H3 describe block**

```elixir
  describe "H3: ensure_coherent_selections placeholder and the original adjust_selections/1" do
    @tag :logged_in_user
    test "full transform pipeline does not clear route_ids mismatched with route_type", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/mono/new/commuter_rail/suspension")
      socket = :sys.get_state(view.pid).socket

      # Build a changeset that exactly mirrors the stale state after H1/H2:
      # route_type is now subway (1) but route_ids still holds a commuter_rail route
      mismatched_changeset =
        Ecto.Changeset.change(socket.assigns.form.source, %{
          route_type: 1,               # subway
          combination: :R,
          route_ids: ["CR-Worcester"]  # commuter_rail — intentionally mismatched
        })

      # Run the full sync (cast → transform → validate → assigns)
      {_, after_sync_socket} =
        case AlertData.sync(mismatched_changeset, socket, %{}) do
          {:ok, s} -> {:ok, s}
          {:error, s} -> {:error, s}
        end

      # EXPECTED (correct behavior): transform should detect mismatch and clear route_ids
      # ACTUAL   (bug):              ensure_coherent_selections is a TODO comment, not code
      # This assertion will FAIL, confirming there is no coherence check in transform
      assert after_sync_socket.assigns.form[:route_ids].value in [nil, []],
             "transform should clear route_ids mismatched with route_type, got: " <>
               inspect(after_sync_socket.assigns.form[:route_ids].value)
    end

    test "adjust_selections/1 in the original code handles select-all, not route_type clearing" do
      # The comment at affected_service_slice.ex:271 points at this function as the
      # "original" to port from. Verify it is NOT about route_type-based clearing
      # so we know ensure_coherent_selections was always a stub, never a port.
      alias AlertsUIWeb.FormComponents.AffectedService

      # The real job of adjust_selections/1: strip "default" (ctrl-click select-all removal)
      assert AffectedService.adjust_selections(%{route_ids: ["default", "CR-Worcester"]}) ==
               %{route_ids: ["CR-Worcester"]},
             "adjust_selections strips 'default' sentinel from arrays"

      # It does NOT inspect or clear route_ids based on route_type
      result =
        AffectedService.adjust_selections(%{
          route_ids: ["CR-Worcester"],
          route_type: 1
        })

      assert result.route_ids == ["CR-Worcester"],
             "adjust_selections does not clear route_ids for mismatched route_type"
    end
  end
```

- [ ] **Step 2: Run the tests and capture output**

```bash
mix test test/alerts_ui_web/live/create_alert_mono_live/route_type_change_test.exs --seed 0 2>&1 | tail -40
```

Expected:
- First test: **FAIL** (`route_ids` survives transform) → H3 scenario confirmed; there is
  nothing to port because `adjust_selections/1` never did this.
- Second test: **PASS** → `adjust_selections/1` is about select-all, not route_type
  coherence. The referenced original is not a blueprint for a fix.

- [ ] **Step 3: Commit**

```bash
git add test/alerts_ui_web/live/create_alert_mono_live/route_type_change_test.exs
git commit -m "test(hypothesis): H3 — ensure_coherent_selections placeholder, adjust_selections scope"
```

---

## Task 4: Prove H4 — `@update_selection_targets` double-definition drops `trip_ids`

**Claim:** `affected_service_slice.ex:204-229` defines `@update_selection_targets` twice.
In Elixir, the second assignment wins. The second definition omits `"trip_ids"` and
`"trip_search_term"`, so the guard in `update_selections?/1` never matches a `trip_ids`
field change. Consequence: when a user selects trips on page 2, the available-option
lists are not refreshed.

**Evidence method:** Call `Slice.assigns/3` with a socket that has non-empty selections,
passing `_target: trip_ids`. If the double-definition bug is real, selections will be
**unchanged**. Contrast with `_target: route_ids`, which **does** reset selections to a
fresh `%Selections{}` struct. The assertion on trip_ids will **FAIL**, confirming H4.

**Files:**
- Modify: `test/alerts_ui_web/live/create_alert_mono_live/route_type_change_test.exs`

- [ ] **Step 1: Add the H4 describe block**

```elixir
  describe "H4: @update_selection_targets double-definition drops trip_ids" do
    @tag :logged_in_user
    test "changing trip_ids does not trigger selection refresh; changing route_ids does", %{
      conn: conn
    } do
      {:ok, view, _html} = live(conn, "/alerts/mono/new/commuter_rail/suspension")
      socket = :sys.get_state(view.pid).socket

      # Replace the socket's :selections with a distinctive non-empty struct so we can
      # detect whether assigns/3 reset it (reset = empty %Selections{}) or left it alone.
      loaded_selections = %AffectedServiceSlice.Selections{
        route_id_options: [{"Framingham/Worcester Line", "CR-Worcester"}]
      }

      socket_with_loaded = Phoenix.Component.assign(socket, :selections, loaded_selections)

      # --- trip_ids field change ---
      # If trip_ids were in @update_selection_targets, async_assign_selections would fire
      # and immediately call assign(:selections, %Selections{}), resetting to empty.
      # Because of the double-definition bug, it does NOT fire.
      trip_result =
        Slice.assigns(
          %AffectedServiceSlice{},
          socket_with_loaded,
          %{"_target" => ["alert_data", "trip_ids"]}
        )

      # EXPECTED (correct behavior): trip_ids change should reset selections to empty struct
      # ACTUAL   (bug):              selections is unchanged — this assertion will FAIL
      assert trip_result.assigns.selections == %AffectedServiceSlice.Selections{},
             "trip_ids change should trigger selection refresh, got: " <>
               inspect(trip_result.assigns.selections)

      # --- route_ids field change (sanity / contrast) ---
      # route_ids IS in the second @update_selection_targets definition,
      # so this DOES fire async_assign_selections → reset to empty %Selections{}.
      route_result =
        Slice.assigns(
          %AffectedServiceSlice{},
          socket_with_loaded,
          %{"_target" => ["alert_data", "route_ids"]}
        )

      # This assertion will PASS, showing the mechanism works for route_ids
      assert route_result.assigns.selections == %AffectedServiceSlice.Selections{},
             "route_ids change should trigger selection refresh"
    end
  end
```

- [ ] **Step 2: Run the test and capture the failure output**

```bash
mix test test/alerts_ui_web/live/create_alert_mono_live/route_type_change_test.exs --seed 0 2>&1 | tail -40
```

Expected: test **FAILS** on the `trip_ids` assertion (selections unchanged) but the
internal `route_ids` assert would pass — confirming the double-definition silently
dropped `trip_ids`. If both pass, H4 is false (Elixir resolved the attribute differently
than expected — unlikely but worth checking).

- [ ] **Step 3: Commit**

```bash
git add test/alerts_ui_web/live/create_alert_mono_live/route_type_change_test.exs
git commit -m "test(hypothesis): H4 — @update_selection_targets double-definition drops trip_ids"
```

---

## Task 5: Characterize H5 — combination state is correctly managed

**Claim (to disprove):** H5 speculated that a stale `combination` during the
`move_progress` → new-route-type transition could send the wrong service slice.
`UrlSlice.transform` runs on every `sync` call and re-derives `combination` from URL
params, so this should not be an independent root cause.

**Evidence method:** Assert that `combination` is nil after going back (correct) and
correctly set after a new `route_type` + `effect_name` pair is chosen. All assertions
should **PASS**, ruling H5 out as an independent cause.

**Files:**
- Modify: `test/alerts_ui_web/live/create_alert_mono_live/route_type_change_test.exs`

- [ ] **Step 1: Add the H5 describe block**

```elixir
  describe "H5: combination is correctly managed by UrlSlice.transform (should NOT be a root cause)" do
    @tag :logged_in_user
    test "combination is nil after move_progress back, correctly set when new route+effect chosen", %{
      conn: conn
    } do
      {:ok, view, _html} = live(conn, "/alerts/mono/new/commuter_rail/suspension")
      socket = :sys.get_state(view.pid).socket

      # Baseline: combination should be non-nil on page 2
      initial_combination = socket.assigns.form[:combination].value
      refute is_nil(initial_combination),
             "combination should be set when route_type and effect_name are in URL"

      # --- Step A: simulate move_progress back ---
      cleared =
        Ecto.Changeset.change(socket.assigns.form.source, %{
          route_type: nil,
          effect_name: nil,
          combination: nil
        })

      {_, after_back_socket} =
        case AlertData.sync(cleared, socket, %{}) do
          {:ok, s} -> {:ok, s}
          {:error, s} -> {:error, s}
        end

      # combination should be nil — no effect selected yet
      assert is_nil(after_back_socket.assigns.form[:combination].value),
             "combination should be nil after returning to page 1"

      # --- Step B: user selects new route_type "subway" (no effect yet) ---
      {_, after_route_type_socket} =
        case AlertData.sync(
               after_back_socket.assigns.form.source,
               after_back_socket,
               %{"route_type" => "subway"}
             ) do
          {:ok, s} -> {:ok, s}
          {:error, s} -> {:error, s}
        end

      # route_type should be subway (1)
      assert after_route_type_socket.assigns.form[:route_type].value == 1,
             "route_type should be 1 (subway) after URL change, got: " <>
               inspect(after_route_type_socket.assigns.form[:route_type].value)

      # combination should still be nil (no effect chosen yet) — UrlSlice handles nil cleanly
      assert is_nil(after_route_type_socket.assigns.form[:combination].value),
             "combination should remain nil until an effect is also chosen, got: " <>
               inspect(after_route_type_socket.assigns.form[:combination].value)

      # --- Step C: user selects new effect "detour" for subway ---
      {_, after_effect_socket} =
        case AlertData.sync(
               after_route_type_socket.assigns.form.source,
               after_route_type_socket,
               %{"route_type" => "subway", "effect_name" => "detour"}
             ) do
          {:ok, s} -> {:ok, s}
          {:error, s} -> {:error, s}
        end

      # combination should now be non-nil and consistent with subway + detour
      combination_after = after_effect_socket.assigns.form[:combination].value
      refute is_nil(combination_after),
             "combination should be set once route_type and effect_name are both in URL"

      # combination should match what subway+detour produces (not the old commuter_rail value)
      refute combination_after == initial_combination,
             "combination should reflect the new route_type+effect, not the old commuter_rail one"
    end
  end
```

- [ ] **Step 2: Run the test and capture the output**

```bash
mix test test/alerts_ui_web/live/create_alert_mono_live/route_type_change_test.exs --seed 0 2>&1 | tail -40
```

Expected: **PASS** → `UrlSlice.transform` correctly manages `combination` at every step.
H5 is **not** an independent root cause.

If any assertion fails: `combination` is being mishandled and H5 needs re-examination.

- [ ] **Step 3: Commit**

```bash
git add test/alerts_ui_web/live/create_alert_mono_live/route_type_change_test.exs
git commit -m "test(hypothesis): H5 — combination is correctly managed, not a root cause"
```

---

## Task 6: Run all five hypothesis tests together and record results

- [ ] **Step 1: Run the full test file**

```bash
mix test test/alerts_ui_web/live/create_alert_mono_live/route_type_change_test.exs --seed 0 2>&1
```

- [ ] **Step 2: Record outcomes against the hypothesis table**

| Hypothesis | Expected test result | Meaning |
|---|---|---|
| H1 — `move_progress` back leaves service data | **FAIL** | Confirmed root cause |
| H2 — `push_route_type` leaves service data | **FAIL** | Confirmed root cause |
| H3a — transform has no coherence check | **FAIL** | Confirms no safety net |
| H3b — `adjust_selections/1` is about select-all only | **PASS** | Refines H3 narrative |
| H4 — `trip_ids` not in `@update_selection_targets` | **FAIL** | Confirmed secondary bug |
| H5 — `combination` is correctly managed | **PASS** | Rules out H5 as root cause |

- [ ] **Step 3: If any outcome differs from expected, note it with the actual output**

Divergences to watch for:
- H1 or H2 passes: Something else is clearing data. Grep for additional `cast` or `change` calls between `move_progress` and the next `sync`.
- H4 passes (both selectors reset): The Elixir compiler may have merged the two attribute definitions differently; check the compiled bytecode with `:code.get_object_code(AlertsUIWeb.CreateAlertMonoLive.Slices.AffectedServiceSlice)`.
- H5 fails: A nil-guard is missing in `UrlSlice.new_url_params/2`; read `url_slice.ex:80-133` again.

---

## Self-Review

**Spec coverage:**
- H1 → Task 1 ✓
- H2 → Task 2 ✓
- H3 (both parts) → Task 3 ✓
- H4 → Task 4 ✓
- H5 → Task 5 ✓
- Summary run → Task 6 ✓

**Placeholder scan:** None — all test code is complete.

**Type consistency:**
- `AffectedServiceSlice.Selections` used consistently in Task 4.
- `AlertData.sync/3` called identically in Tasks 1–5.
- `Ecto.Changeset.change/2` used (not `cast/3`) to directly set fields without going through field casting — correct for simulating what `Ecto.Changeset.change/2` does inside `move_progress`.
