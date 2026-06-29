# Fix SR Route Search Filtering Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the route search bar in the SR (stop-route) mono flow so that typing in it actually filters the "Impacted routes" list.

**Architecture:** Two independent bugs compound to produce the symptom. H1: the render template passes `filter_field={@form[:routes_search_term]}` (with "s") but the update trigger list and async read both use `route_search_term` (no "s") — so user input never reaches the server handler that rebuilds `route_id_options`. H2: even if H1 were fixed, `route_id_options` is called with `values_to_keep: route_ids` where `route_ids` contains all auto-selected routes, and `SelectFormatter.apply_search/3` keeps any option whose `value` is in `values_to_keep` — defeating the filter. Both must be fixed. The same H1 typo also exists in `StopRouteAffectedService` (old flow) and is fixed as Task 4.

**Tech Stack:** Elixir/Phoenix LiveView, ExUnit, Mock, Floki

---

### Task 1: Write failing tests

**Files:**
- Modify: `test/alerts_ui_web/live/create_alert_mono_live/slices/stop_route_service_slice_test.exs`

Context: The test file already has a `describe "stop_id_options/5 preservation logic"` block at the top, a `describe "component"` block with integration tests, and a `describe "end-to-end"` block. Module-level route/stop fixtures are: `@route %Route{sort_order: 1, id: "Blue", name: "Blue Line", type: 1}`, `@route_two %Route{sort_order: 2, id: "Red", name: "Red Line", type: 1}`, `@stop %Stop{id: "place-aqucl", name: "Aquarium"}`. The file imports `Mock`, `Phoenix.LiveViewTest`, `Floki`, and uses `ConnCase`.

- [ ] **Step 1: Add unit test for H2 — route_id_options ignores search when all routes selected**

Add a new `describe` block immediately after the closing `end` of `describe "stop_id_options/5 preservation logic"` (after line 55):

```elixir
describe "route_id_options/4 filtering" do
  test "filters by search_term even when all route ids are in the selected list" do
    routes = [@route, @route_two]

    options = StopRouteServiceSlice.route_id_options(routes, ["Blue", "Red"], "Blue", 1)
    values = Enum.map(options, &Keyword.get(&1, :value))

    assert "Blue" in values
    # Before fix: "Red" is retained because values_to_keep includes all route ids
    refute "Red" in values
  end
end
```

- [ ] **Step 2: Run the unit test and verify it fails for the right reason**

```
mix test test/alerts_ui_web/live/create_alert_mono_live/slices/stop_route_service_slice_test.exs --grep "route_id_options"
```

Expected: FAIL — `** (UndefinedFunctionError) function StopRouteServiceSlice.route_id_options/4 is undefined or private`

- [ ] **Step 3: Add integration tests for end-to-end route search**

Add two tests inside the existing `describe "component"` block, after the "modal route search can clear" test (around line 491):

```elixir
@tag :logged_in_user
test "route search filters impacted route options after stop selection", %{conn: conn} do
  with_mocks([
    {RoutesRepo, [],
     [
       by_type: fn _ -> [@route, @route_two] end,
       by_stop: fn _ -> [@route, @route_two] end,
       by_stop: fn _, _ -> [@route, @route_two] end
     ]},
    {StopsRepo, [],
     [
       by_route_type: fn _, _ -> [@stop] end,
       by_route: fn _, _, _ -> [@stop] end
     ]}
  ]) do
    {:ok, view, _html} = live(conn, "/alerts/new")
    get_to_submission_page_refactor(view, "Subway", "Station closure")

    view
    |> element("form")
    |> render_change(%{
      "_target" => ["alert_data", "stop_ids"],
      "alert_data" => %{"stop_ids" => ["place-aqucl"]}
    })

    render_async(view)

    {:ok, document} = view |> render() |> Floki.parse_document()
    assert document_has_element?(document, "select#alert_data_route_ids > option[value=\"Blue\"]")
    assert document_has_element?(document, "select#alert_data_route_ids > option[value=\"Red\"]")

    view
    |> element("form")
    |> render_change(%{
      "_target" => ["alert_data", "route_search_term"],
      "alert_data" => %{"route_search_term" => "Blue"}
    })

    render_async(view)

    {:ok, document} = view |> render() |> Floki.parse_document()
    assert document_has_element?(document, "select#alert_data_route_ids > option[value=\"Blue\"]")
    # Before fix: Red still visible (H1 prevents update trigger; H2 keeps it via values_to_keep)
    refute document_has_element?(document, "select#alert_data_route_ids > option[value=\"Red\"]")
  end
end

@tag :logged_in_user
test "route search can clear", %{conn: conn} do
  with_mocks([
    {RoutesRepo, [],
     [
       by_type: fn _ -> [@route, @route_two] end,
       by_stop: fn _ -> [@route, @route_two] end,
       by_stop: fn _, _ -> [@route, @route_two] end
     ]},
    {StopsRepo, [],
     [
       by_route_type: fn _, _ -> [@stop] end,
       by_route: fn _, _, _ -> [@stop] end
     ]}
  ]) do
    {:ok, view, _html} = live(conn, "/alerts/new")
    get_to_submission_page_refactor(view, "Subway", "Station closure")

    view
    |> element("form")
    |> render_change(%{
      "_target" => ["alert_data", "stop_ids"],
      "alert_data" => %{"stop_ids" => ["place-aqucl"]}
    })

    render_async(view)

    view
    |> element("form")
    |> render_change(%{
      "_target" => ["alert_data", "route_search_term"],
      "alert_data" => %{"route_search_term" => "Blue"}
    })

    render_async(view)

    render_click(view, "reset_search_filter", %{"name" => "alert_data[route_search_term]"})
    render_async(view)

    {:ok, document} = view |> render() |> Floki.parse_document()
    assert document_has_element?(document, "select#alert_data_route_ids > option[value=\"Blue\"]")
    assert document_has_element?(document, "select#alert_data_route_ids > option[value=\"Red\"]")
  end
end
```

- [ ] **Step 4: Run the integration tests and verify they fail**

```
mix test test/alerts_ui_web/live/create_alert_mono_live/slices/stop_route_service_slice_test.exs --grep "route search"
```

Expected: Both FAIL — `refute document_has_element?` on `option[value="Red"]` fails because Red is still visible

- [ ] **Step 5: Commit the failing tests**

```bash
git add test/alerts_ui_web/live/create_alert_mono_live/slices/stop_route_service_slice_test.exs
git commit -m "test: add failing tests for route search filtering in SR slice"
```

---

### Task 2: Fix H2 — Remove values_to_keep from route_id_options

**Files:**
- Modify: `lib/alerts_ui_web/live/create_alert_mono_live/slices/stop_route_service_slice.ex`

Context: `route_id_options/4` is currently `defp` at lines ~244–257. It calls `SelectFormatter.formatted_select_options` with `values_to_keep: route_ids`. `SelectFormatter.apply_search/3` retains any option whose value is in `values_to_keep` regardless of the search term — so when all routes are auto-selected, nothing is ever filtered. The fix is to make the function public (consistent with `stop_id_options/5`) and stop passing `values_to_keep`.

- [ ] **Step 1: Make route_id_options public and remove values_to_keep**

Find the existing `defp route_id_options(...)` function and replace it:

```elixir
def route_id_options(
      available_routes,
      _route_ids,
      route_search_term,
      route_type
    ) do
  SelectFormatter.formatted_select_options(%SelectFormatter{
    options: available_routes,
    search_term: route_search_term,
    route_type: route_type,
    values_to_keep: [],
    option_prefix: "route-selector"
  })
end
```

The `_route_ids` parameter is retained in the signature (with underscore) to keep the call site unchanged in `async_assign_selections`.

- [ ] **Step 2: Run the unit test — it should now pass**

```
mix test test/alerts_ui_web/live/create_alert_mono_live/slices/stop_route_service_slice_test.exs --grep "route_id_options"
```

Expected: PASS

- [ ] **Step 3: Confirm the integration tests still fail (H1 not yet fixed)**

```
mix test test/alerts_ui_web/live/create_alert_mono_live/slices/stop_route_service_slice_test.exs --grep "route search"
```

Expected: FAIL — Red is still not filtered because `route_search_term` change event doesn't trigger `async_assign_selections` yet

- [ ] **Step 4: Run the full slice test file to confirm no regressions**

```
mix test test/alerts_ui_web/live/create_alert_mono_live/slices/stop_route_service_slice_test.exs
```

Expected: All previously-passing tests still pass; only the two new integration tests fail

- [ ] **Step 5: Commit**

```bash
git add lib/alerts_ui_web/live/create_alert_mono_live/slices/stop_route_service_slice.ex
git commit -m "fix: remove values_to_keep from route_id_options to enable search filtering"
```

---

### Task 3: Fix H1 — Correct field name in mono flow render template

**Files:**
- Modify: `lib/alerts_ui_web/live/create_alert_mono_live/slices/stop_route_service_slice.ex`

Context: The `render/1` function renders a `<.filtered_select>` for impacted routes with `filter_field={@form[:routes_search_term]}` (note the extra "s"). The `AlertData` schema defines `field :route_search_term, :string` (no "s"). The `@update_selection_targets` list contains `"route_search_term"` (no "s"). The async read uses `form[:route_search_term].value` (no "s"). As a result, user input flows to the `routes_search_term` form key, which doesn't match the update target, and `async_assign_selections` never fires.

- [ ] **Step 1: Fix the filter_field binding**

In the `render/1` function, find the `<.filtered_select label="Impacted routes" ...>` block and change:

```elixir
filter_field={@form[:routes_search_term]}
```

To:

```elixir
filter_field={@form[:route_search_term]}
```

- [ ] **Step 2: Run the integration tests — both should now pass**

```
mix test test/alerts_ui_web/live/create_alert_mono_live/slices/stop_route_service_slice_test.exs --grep "route search"
```

Expected: PASS for both "route search filters impacted route options" and "route search can clear"

- [ ] **Step 3: Run the full slice test file**

```
mix test test/alerts_ui_web/live/create_alert_mono_live/slices/stop_route_service_slice_test.exs
```

Expected: All tests pass

- [ ] **Step 4: Commit**

```bash
git add lib/alerts_ui_web/live/create_alert_mono_live/slices/stop_route_service_slice.ex
git commit -m "fix: correct filter_field name in SR slice route selector (routes_search_term → route_search_term)"
```

---

### Task 4: Fix H1 — Correct field name in old flow LiveComponent

**Files:**
- Modify: `lib/alerts_ui_web/live/form_components/stop_route_affected_service.ex`

Context: The same `routes_search_term` (with "s") typo exists in this LiveComponent's `render/1` at line ~619. The embedded schema defines `:route_search_term` (no "s") at line 26, and it appears in `@fields` (line 34). The component's `handle_event("validate", ...)` handler builds a changeset by casting `affected_service` params against `@fields` — since `routes_search_term` is not in `@fields`, it is silently dropped and route filtering never works in this flow either.

- [ ] **Step 1: Fix the filter_field binding**

Find the `<.filtered_select label="Impacted routes" ...>` block in the `render/1` function and change:

```elixir
filter_field={@form[:routes_search_term]}
```

To:

```elixir
filter_field={@form[:route_search_term]}
```

- [ ] **Step 2: Run the full test suite**

```
mix test
```

Expected: All tests pass

- [ ] **Step 3: Run full code quality checks**

```
mix check
```

Expected: All checks pass (compile, format, credo, sobelow, tests, dialyzer)

- [ ] **Step 4: Commit**

```bash
git add lib/alerts_ui_web/live/form_components/stop_route_affected_service.ex
git commit -m "fix: correct filter_field name in StopRouteAffectedService route selector"
```
