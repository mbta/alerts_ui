# Async Selections Loading — Mono Alert Creation Flow

## Context

The mono alert creation flow (`create_alert_mono_live/`) loads routes, stops, facilities, and
schedules from the MBTA API asynchronously. The old approach used Phoenix's `assign_async/3`,
which temporarily replaced `socket.assigns.selections` with an `%AsyncResult{}`. A workaround
then immediately overwrote that AsyncResult with an empty `%Selections{}`, causing every API
call to visibly clear the UI — for example, the subway line toggle group would disappear during
any reload, even a direction change that leaves the available routes unchanged.

## Design

### Core Invariant

`socket.assigns.selections` is **always** one of the three concrete `%Selections{}` structs.
It is never an `%AsyncResult{}`. The `loading:` boolean field in the struct indicates whether
a fetch is in progress.

```
Idle:    %Selections{loading: false, route_id_options: [A, B, C], ...}
Loading: %Selections{loading: true,  route_id_options: [A, B, C], ...}  ← same data, flag set
Done:    %Selections{loading: false, route_id_options: [X, Y, Z], ...}  ← new data
```

### Mechanism: `start_async` + `handle_async`

Replace `assign_async/3` with `start_async/3` (which does NOT touch assigns) combined with
an explicit `loading: true` write on the existing struct.

**In each service slice's `async_assign_selections/2`:**

```elixir
prev = case Map.get(socket.assigns, :selections) do
  %Selections{} = s -> s
  _ -> %Selections{}
end

socket
|> assign(:selections, %{prev | loading: true})    # preserve data, set flag
|> start_async(:fetch_selections, fn -> new_sel end)  # returns plain struct
```

**In the main LiveView:**

```elixir
def handle_async(:fetch_selections, {:ok, new_sel}, socket) do
  {:noreply, assign(socket, :selections, new_sel)}
end

def handle_async(:fetch_selections, {:exit, reason}, socket) do
  Logger.error("Selections load failed: #{inspect(reason)}")
  case socket.assigns[:selections] do
    %{loading: _} = sel -> {:noreply, assign(socket, :selections, %{sel | loading: false})}
    _ -> {:noreply, socket}
  end
end
```

### Helper cleanup

- **Deleted `assign_unwrapped_selections/2`** — no longer needed; `selections` is always a
  plain struct.
- **Updated `selections_loading?/1`** — now matches `%{loading: true}` (any struct) instead
  of `%AsyncResult{loading: true}`.
- **Simplified `assigns/3` in each Slice impl** — removed `assign_unwrapped_selections` call.

### No template changes needed

Templates already check `selections_loading?(@selections)` and `@selections.loading`.

## Files Modified

| File | Change |
|---|---|
| `slices/affected_service_slice.ex` | `start_async` + preserve prev struct |
| `slices/stop_route_service_slice.ex` | Same |
| `slices/access_affected_service_slice.ex` | Same |
| `create_alert_mono_live.ex` | Added `handle_async/3` clauses |
| `helpers/selections.ex` | Removed `assign_unwrapped_selections/2`; updated `selections_loading?/1` |
| `slices/delivery_slice_test.exs` | Added missing `RoutesRepo` mock (exposed by correct async behavior) |

## Side effect: test correctness improvement

The old code accidentally masked missing API mocks in tests because `render_async` skipped
waiting for the async task once the AsyncResult was overwritten. With `start_async`,
`render_async` correctly waits for the background task, exposing one delivery slice test that
was missing a `RoutesRepo` mock. The mock was added.
