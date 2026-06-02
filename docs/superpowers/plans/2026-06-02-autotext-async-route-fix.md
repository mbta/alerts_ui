# Autotext Async Route Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the race condition that causes bus Multi-Route Detour header text to omit route names after a stop is selected.

**Architecture:** Replace the `send/2`-based auto-select notification (which fires before `available_routes` lands in the socket) with a `pending_auto_select_route_ids` field on `%Selections{}` that is consumed in `handle_async` after the new selections are already assigned.

**Tech Stack:** Elixir, Phoenix LiveView, ExUnit, Mock (`:mock` library), Floki (HTML parsing in tests)

---

## File Map

| File | Change |
|------|--------|
| `lib/alerts_ui_web/live/create_alert_mono_live/slices/stop_route_service_slice.ex` | Add `pending_auto_select_route_ids` field to `Selections`; remove `send`; set field in async return value |
| `lib/alerts_ui_web/live/create_alert_mono_live.ex` | Update `handle_async(:fetch_selections, ...)` to apply pending auto-select; remove `handle_info({:sr_auto_select_routes, ...})` |
| `test/alerts_ui_web/live/create_alert_mono_live/slices/stop_route_service_slice_test.exs` | Add regression test; verify existing tests still pass |

---

## Task 1: Write the failing regression test

**Files:**
- Modify: `test/alerts_ui_web/live/create_alert_mono_live/slices/stop_route_service_slice_test.exs`

This test must be written FIRST and must FAIL before the implementation is changed. That is how we know it actually exercises the bug.

- [ ] **Step 1: Add the test inside the existing `describe "component"` block**

Open `test/alerts_ui_web/live/create_alert_mono_live/slices/stop_route_service_slice_test.exs`. The file already has `@bus_route_one`, `@stop`, and the test module imports. Add this test inside the `describe "component" do` block (around line 89, alongside the other component tests):

```elixir
@tag :logged_in_user
test "bus multi-route detour header text includes route and stop name after stop selection",
     %{conn: conn} do
  with_mocks([
    {RoutesRepo, [],
     [
       by_type: fn _ -> [@bus_route_one] end,
       by_stop: fn _ -> [@bus_route_one] end,
       by_stop: fn _, _ -> [@bus_route_one] end
     ]},
    {StopsRepo, [],
     [
       by_route: fn _, _, _ -> [@stop] end
     ]}
  ]) do
    {:ok, view, _html} = live(conn, "/alerts/mono/new")
    get_to_submission_page_refactor(view, "Bus", "Multi-route detour")
    render_async(view)

    view
    |> element("form")
    |> render_change(%{
      "_target" => ["alert_data", "stop_ids"],
      "alert_data" => %{"stop_ids" => ["place-aqucl"]}
    })

    render_async(view)

    assert view |> element("#header_input") |> render() =~ "Blue Line"
    assert view |> element("#header_input") |> render() =~ "Aquarium"
  end
end
```

**Why this test catches the bug:** After selecting a stop, `render_async` waits for all async tasks and messages to settle. Before the fix, `handle_info({:sr_auto_select_routes, ...})` fires before `available_routes` is in the socket, so the autotext is generated with routes = []. The header text contains "Aquarium" (from the stop) but not "Blue Line" (from the route). Both assertions must pass after the fix.

---

## Task 2: Run the test and confirm it fails

**Files:** (none changed)

- [ ] **Step 1: Run just the new test**

```bash
mix test test/alerts_ui_web/live/create_alert_mono_live/slices/stop_route_service_slice_test.exs --only "bus multi-route detour header text"
```

Expected: **1 test, 1 failure.** The failure should be on `assert ... =~ "Blue Line"` (route name absent from header). If it fails on "Aquarium" instead, the stop is not being picked up either — that would indicate a different problem. If the test *passes*, the bug was already fixed elsewhere and something is wrong with the test setup.

---

## Task 3: Add `pending_auto_select_route_ids` to `Selections`

**Files:**
- Modify: `lib/alerts_ui_web/live/create_alert_mono_live/slices/stop_route_service_slice.ex:37-56`

- [ ] **Step 1: Add the new field to the `Selections` struct (line ~42)**

The struct currently ends with `loading: false`. Add `pending_auto_select_route_ids: nil` after it:

```elixir
defstruct available_filter_routes: nil,
          available_routes: nil,
          available_stops: nil,
          filter_title_value: "All routes",
          modal_route_id_options: [],
          on_filter_accept: &StopRouteServiceSlice.on_filter_accept/1,
          on_filter_clear: &StopRouteServiceSlice.on_filter_clear/1,
          retained_stops: [],
          route_id_options: [],
          selected_stops: [],
          selected_route_id: nil,
          show_stop_ids?: true,
          stop_id_options: [],
          loading: false,
          pending_auto_select_route_ids: nil
```

---

## Task 4: Update the async task — remove `send`, set the new field

**Files:**
- Modify: `lib/alerts_ui_web/live/create_alert_mono_live/slices/stop_route_service_slice.ex:87-200`

The relevant section is in `async_assign_selections/2`. The current code (around lines 95–96 and 175–189) does:

```elixir
auto_select_routes = match?(%{"_target" => ["alert_data", "stop_ids"]}, params)
lv_pid = self()
```

…and then inside `start_async`:

```elixir
if auto_select_routes do
  send(lv_pid, {:sr_auto_select_routes, Enum.map(available_routes, & &1.id)})
end

%Selections{
  available_filter_routes: available_filter_routes,
  available_routes: available_routes,
  available_stops: available_stops,
  filter_title_value: filter_title_value,
  modal_route_id_options: modal_route_id_options,
  route_id_options: route_id_options,
  selected_route_id: modal_route_id,
  selected_stops: selected_stops,
  stop_id_options: stop_id_options
}
```

- [ ] **Step 1: Remove `lv_pid = self()`**

Delete the line `lv_pid = self()` (currently around line 96 in the function).

- [ ] **Step 2: Replace the `send` + return with `pending_auto_select_route_ids`**

Replace the `if auto_select_routes do send(...) end` block and the `%Selections{}` return with:

```elixir
pending_auto_select_route_ids =
  if auto_select_routes, do: Enum.map(available_routes, & &1.id), else: nil

%Selections{
  available_filter_routes: available_filter_routes,
  available_routes: available_routes,
  available_stops: available_stops,
  filter_title_value: filter_title_value,
  modal_route_id_options: modal_route_id_options,
  route_id_options: route_id_options,
  selected_route_id: modal_route_id,
  selected_stops: selected_stops,
  stop_id_options: stop_id_options,
  pending_auto_select_route_ids: pending_auto_select_route_ids
}
```

---

## Task 5: Update `handle_async` to consume the pending auto-select

**Files:**
- Modify: `lib/alerts_ui_web/live/create_alert_mono_live.ex:265-278`

The current implementation (around line 265):

```elixir
@impl true
def handle_async(:fetch_selections, {:ok, new_selections}, socket) do
  {:noreply, assign(socket, :selections, new_selections)}
end
```

- [ ] **Step 1: Replace `handle_async(:fetch_selections, {:ok, ...})` with the new implementation**

```elixir
@impl true
def handle_async(:fetch_selections, {:ok, new_selections}, socket) do
  socket = assign(socket, :selections, %{new_selections | pending_auto_select_route_ids: nil})

  socket =
    case new_selections.pending_auto_select_route_ids do
      nil ->
        socket

      route_ids ->
        sync_socket(socket, %{"alert_data" => %{"route_ids" => route_ids}})
    end

  {:noreply, socket}
end
```

**Why `pending_auto_select_route_ids: nil` is cleared before `sync_socket`:** `sync_socket` triggers a re-render. If the field were still set in `socket.assigns.selections`, a subsequent async reload could re-read a stale value. Clearing it first is a safety measure with no visible effect on this call.

**Why no `route_ids in [nil, []]` guard:** Per the product decision, auto-select should always override routes when the stop selection changes.

---

## Task 6: Remove the now-obsolete `handle_info` handler

**Files:**
- Modify: `lib/alerts_ui_web/live/create_alert_mono_live.ex:281-287`

The current handler (around line 281):

```elixir
@impl true
def handle_info({:sr_auto_select_routes, route_ids}, socket) do
  if socket.assigns.form[:route_ids].value in [nil, []] do
    {:noreply, sync_socket(socket, %{"alert_data" => %{"route_ids" => route_ids}})}
  else
    {:noreply, socket}
  end
end
```

- [ ] **Step 1: Delete the entire `handle_info({:sr_auto_select_routes, ...})` clause**

Nothing else sends `{:sr_auto_select_routes, ...}` — `grep -r "sr_auto_select_routes"` in the project returns only this handler and the (now-removed) `send` call. Safe to delete entirely.

---

## Task 7: Run the regression test and confirm it passes

**Files:** (none changed)

- [ ] **Step 1: Run just the regression test**

```bash
mix test test/alerts_ui_web/live/create_alert_mono_live/slices/stop_route_service_slice_test.exs --only "bus multi-route detour header text"
```

Expected: **1 test, 0 failures.**

---

## Task 8: Run the full slice test file

**Files:** (none changed)

- [ ] **Step 1: Run all tests in the affected test file**

```bash
mix test test/alerts_ui_web/live/create_alert_mono_live/slices/stop_route_service_slice_test.exs
```

Expected: all tests pass. Particular tests to watch:

- `"route options are all selected by default and correctly create informed entities"` — previously exercised the `handle_info` path; now goes through `handle_async`. Behavior is identical from the test's perspective.
- `"route options are all selected by default and allows user entry"` — same as above.
- `"publishing a bus multi-route detour AFTER selecting and deselecting will put up a flash error"` — passes empty stop_ids with `_target: stop_ids`, triggering auto-select. The async task may call `RoutesRepo.by_stop([], ...)`, which is not mocked in that test. If Mock raises on unmocked calls, add `by_stop: fn _ -> [] end, by_stop: fn _, _ -> [] end` to the RoutesRepo mock in that test.

---

## Task 9: Run the full test suite

**Files:** (none changed)

- [ ] **Step 1: Run the full suite**

```bash
mix test
```

Expected: all tests pass (suite is green before this change).

- [ ] **Step 2: If the suite is not green, address failures**

If `"publishing a bus multi-route detour..."` fails with a Mock error about `by_stop`, update its mock block:

```elixir
with_mocks([
  {RoutesRepo, [],
   [
     by_type: fn _ -> [@route, @route_two] end,
     by_stop: fn _ -> [] end,
     by_stop: fn _, _ -> [] end
   ]},
  {StopsRepo, [], [by_route: fn _, _, _ -> [@stop] end]}
]) do
```

---

## Task 10: Commit

- [ ] **Step 1: Stage and commit all changes**

```bash
git add \
  lib/alerts_ui_web/live/create_alert_mono_live/slices/stop_route_service_slice.ex \
  lib/alerts_ui_web/live/create_alert_mono_live.ex \
  test/alerts_ui_web/live/create_alert_mono_live/slices/stop_route_service_slice_test.exs

git commit -m "$(cat <<'EOF'
Fix autotext race: move SR auto-select into handle_async

handle_info({:sr_auto_select_routes, ...}) fired before available_routes
landed in socket assigns, causing route names to be absent from bus
Multi-Route Detour header text. Moving the auto-select trigger into
handle_async (after selections are assigned) ensures the autotext
generator sees the correct routes.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Self-Review

**Spec coverage check:**
- ✅ Add `pending_auto_select_route_ids` to `Selections` → Task 3
- ✅ Remove `send` from async task; set field instead → Task 4
- ✅ Update `handle_async` to assign selections first, then call `sync_socket` → Task 5
- ✅ Remove `handle_info({:sr_auto_select_routes, ...})` → Task 6
- ✅ New regression test: header includes route name and stop name after stop selection → Task 1
- ✅ Behavior change: no nil/empty guard on auto-select → Task 5 (no guard in new `case`)
- ✅ Existing tests verified → Tasks 8–9

**Placeholder scan:** All steps have exact code. No TBDs.

**Type consistency:**
- `pending_auto_select_route_ids` is `[String.t()] | nil` — used consistently as a list of string IDs (Selections struct, async return, case match in handle_async).
- `%{new_selections | pending_auto_select_route_ids: nil}` — valid struct update since `Selections` is a plain `defstruct`.
- `sync_socket(socket, %{"alert_data" => %{"route_ids" => route_ids}})` — same call signature as the removed `handle_info`; `route_ids` is `[String.t()]`.
