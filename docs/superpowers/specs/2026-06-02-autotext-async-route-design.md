# Autotext Async Route Fix — Design Spec

**Date:** 2026-06-02
**Author:** Erik Cameron

---

## Problem

When creating a Bus Multi-Route Detour alert in the mono flow, the header text (autotext) should read:

> "Route 57 is detoured ..., skipping Main St @ Elm St."

After selecting a stop, routes are loaded from the API asynchronously. The autotext does update, but because of a message-ordering race condition, it regenerates **before** `available_routes` lands in the socket — so route names are missing from the header text.

### Root Cause

`StopRouteServiceSlice.async_assign_selections/2` uses `start_async` to fetch stops and routes from the API. When auto-select is needed (stop_ids just changed), the async task calls `send(lv_pid, {:sr_auto_select_routes, route_ids})` mid-flight and then returns the full `%Selections{}` struct.

Because the message is sent *during* task execution, it arrives in the LV mailbox before the async result. The LV processes them in order:

1. `handle_info({:sr_auto_select_routes, route_ids})` fires → calls `sync_socket` → `AlertDetailsSlice.transform` builds autotext with `selections.available_routes = nil` → routes absent from header.
2. `handle_async(:fetch_selections, {:ok, new_selections})` fires → assigns `available_routes` to the socket → **no autotext regeneration**.

The Multi-Route Detour template (`"?route_names ?route_form detoured ..., skipping ?stop_names ..."`) requires both routes and stops. Stops are present; routes are not.

---

## Approach: Move Auto-Select into `handle_async`

Replace the `send`-based inter-process communication with a field on the `%Selections{}` return value. `handle_async` consumes that field *after* assigning the new selections (so `available_routes` is already in the socket), then calls `sync_socket` to regenerate autotext.

### Data flow

```
Before:
  async task  →  send(lv_pid, {:sr_auto_select_routes, ids})  →  handle_info  (available_routes = nil)
              ↘  return %Selections{available_routes: routes}  →  handle_async (no autotext regen)

After:
  async task  →  return %Selections{
                   available_routes: routes,
                   pending_auto_select_route_ids: ids   ← new field, nil when not auto-selecting
                 }
              →  handle_async assigns selections, then calls sync_socket
                 (available_routes already in socket → correct autotext)
```

---

## Components and Changes

### 1. `StopRouteServiceSlice.Selections` struct

Add one field:

```elixir
pending_auto_select_route_ids: nil   # [String.t()] | nil
```

`nil` means no auto-select is pending. A list (including `[]`) means auto-select should fire with those IDs.

### 2. `StopRouteServiceSlice.async_assign_selections/2`

- Remove `lv_pid = self()` and the `send(lv_pid, {:sr_auto_select_routes, ...})` call.
- When `auto_select_routes` is true, set `pending_auto_select_route_ids: Enum.map(available_routes, & &1.id)` on the returned `%Selections{}`.
- When `auto_select_routes` is false, leave `pending_auto_select_route_ids: nil` (default).

### 3. `CreateAlertMonoLive.handle_async(:fetch_selections, {:ok, new_selections}, socket)`

Current implementation just assigns the new selections. New implementation:

```elixir
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

The `pending_auto_select_route_ids` field is cleared before `sync_socket` runs so it is not accidentally re-applied on future renders.

**Behavior change:** The `nil/[]` guard from `handle_info` is not carried forward. Routes are always overridden by the auto-select result whenever stop_ids changes. This matches the desired behavior (auto-select fires on every stop change).

### 4. `CreateAlertMonoLive.handle_info({:sr_auto_select_routes, ...})`

Remove this handler entirely. Nothing else sends this message.

---

## Behavior Change: Auto-Select Always Overrides Routes

The old `handle_info` guard (`if socket.assigns.form[:route_ids].value in [nil, []]`) prevented auto-select from overriding a user's manual route selection. Removing that guard means:

- Every time stop_ids changes, routes are reset to whatever serves those stops.
- A user who manually deselected some routes and then **changes the stop selection** will have routes reset.
- A user who manually deselected some routes and then **does not change stops** is unaffected — `pending_auto_select_route_ids` is only set when `_target == ["alert_data", "stop_ids"]`, so other interactions (route deselect, field edits, etc.) never trigger auto-select.

Existing tests that verify manual route deselection is preserved do not change stops afterwards, so they are not broken by this change. They should still pass.

---

## Testing

### New test (regression guard)

**File:** `test/alerts_ui_web/live/create_alert_mono_live/slices/stop_route_service_slice_test.exs`
**Describe block:** `"component"`

```
test "bus multi-route detour header text includes route name after stop selection"
```

Steps:
1. Mock `RoutesRepo.by_type` → `[bus_route]`, `RoutesRepo.by_stop/1` and `RoutesRepo.by_stop/2` → `[bus_route]`.
2. Mock `StopsRepo.by_route` → `[stop]`.
3. Navigate to Bus → Multi-Route Detour.
4. Select a stop via `render_change` with `_target: ["alert_data", "stop_ids"]`.
5. `render_async(view)`.
6. Assert `render(view)` contains the route's short name (e.g., the bus route name) in the header text textarea.

### Existing tests to update

- `"route options are all selected by default and allows user entry"` (end-to-end describe) — currently exercises the `handle_info` path implicitly. After the change it exercises `handle_async`. No assertion changes needed; the behavior is the same from the test's perspective.
- Any test that mocks `RoutesRepo.by_stop` for the auto-select path should continue working since we're using the same data; only the delivery mechanism changes.

### Tests that may need assertions adjusted

- `"publishing a bus multi-route detour AFTER selecting and deselecting will put up a flash error"` — this test passes `route_ids: []` explicitly. Auto-select would normally fire but the mocks return routes that may conflict. Review this test to confirm it still exercises the right scenario.

---

## Files Touched

| File | Change |
|------|--------|
| `lib/alerts_ui_web/live/create_alert_mono_live/slices/stop_route_service_slice.ex` | Add `pending_auto_select_route_ids` field; remove `send`; set field in async task return |
| `lib/alerts_ui_web/live/create_alert_mono_live.ex` | Update `handle_async(:fetch_selections, ...)`; remove `handle_info({:sr_auto_select_routes, ...})` |
| `test/alerts_ui_web/live/create_alert_mono_live/slices/stop_route_service_slice_test.exs` | Add regression test; review affected existing tests |

---

## Out of Scope

- Other alert types (subway, commuter rail, ferry) — their auto-select paths either don't use `pending_auto_select_route_ids` or their header templates don't include `?route_names` in a stop-first way.
- The `handle_async(:fetch_selections, {:exit, reason}, socket)` error path — no autotext changes needed there.
- Any UI changes to how the header text field is displayed.
