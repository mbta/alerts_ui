defmodule AlertsUIWeb.Tickets.ClearFilterButtonTest do
  @moduledoc """
  Regression test for Asana ticket 1211955886164861
  "🐛 Issues with clearing filters in filter modal"
  https://app.asana.com/1/15492006741476/project/1167196461144361/task/1211955886164861

  Bug: Multiple issues with clearing filters in the filter modal:
    1. Clicking the clear (ⓧ) icon on a closed filter accordion opened the filter instead
       of clearing it immediately.
    2. Clicking the clear button on one filter re-added a previously cleared filter.
    3. Clicking the clear button on one filter cleared another filter.
    4. Clicking the clear button on one filter cleared ALL filters.

  These tests verify the `reset_filter` event handler clears only the targeted filter and
  leaves all other active filters intact, and that the filter_modal_group component renders
  the clear span correctly (only when a filter is active).

  Verified against dev-green on 2026-06-07.
  """
  use ExUnit.Case
  use AlertsUIWeb.ConnCase

  import AlertsUI.Support.Factory
  import Mock
  import Phoenix.LiveViewTest

  alias MBTAV3API.Routes.Repo, as: RoutesRepo

  setup do
    insert(:alert, %{
      alert_id: "9001",
      header_text: "Orange Line delays",
      effect_detail: "DELAY",
      active_period_start: ~U[2023-10-12 00:01:00Z],
      original_route_selections: ["Orange"],
      duration_certainty: :UNKNOWN
    })

    insert(:alert, %{
      alert_id: "9002",
      header_text: "Commuter Rail detour",
      effect_detail: "DETOUR",
      active_period_start: ~U[2023-10-13 00:01:00Z],
      original_route_selections: ["CR-Lowell"],
      duration_certainty: :UNKNOWN
    })

    :ok
  end

  # Issue 3 & 4: reset_filter with a filter-id clears only that filter
  @tag :logged_in_user
  test "reset_filter with filter-id clears only the targeted filter, leaves others intact",
       %{conn: conn} do
    with_mock(RoutesRepo, [], all: fn -> [] end, get: fn id -> %{name: id} end) do
      {:ok, view, _html} = live(conn, "/alerts")

      # Simulate the user selecting Service Types = "2" (Commuter Rail) and Effects = "Delay"
      # by editing the filter form (as the modal would on phx-change)
      render_change(view, "edit_filter", %{
        "view_alerts_live" => %{
          "service_type" => ["2"],
          "effects" => ["Delay"]
        }
      })

      # Now click the clear button for service_type only
      render_click(view, "reset_filter", %{"filter-id" => "service_type"})

      html = render(view)
      {:ok, doc} = Floki.parse_document(html)

      # The service_type select should be back to "All" (default)
      service_type_options = Floki.find(doc, "#view_alerts_live_service_type option[selected]")
      service_type_values = Floki.attribute(service_type_options, "value")

      assert service_type_values == ["default"] or service_type_values == [],
             "Expected service_type to be cleared (default selected), got: #{inspect(service_type_values)}"

      # The Effects filter should still have "Delay" selected (not cleared)
      effects_options = Floki.find(doc, "#view_alerts_live_effects option[selected]")
      effects_values = Floki.attribute(effects_options, "value")

      assert "Delay" in effects_values,
             "Expected Effects to still have Delay selected after clearing service_type, got: #{inspect(effects_values)}"
    end
  end

  # Issue 3 & 4: reset_filter with routes filter-id does not clear service_type or effects
  @tag :logged_in_user
  test "clearing routes filter leaves service_type and effects filters untouched",
       %{conn: conn} do
    with_mock(RoutesRepo, [], all: fn -> [] end, get: fn id -> %{name: id} end) do
      {:ok, view, _html} = live(conn, "/alerts")

      # Set all three filters
      render_change(view, "edit_filter", %{
        "view_alerts_live" => %{
          "service_type" => ["2"],
          "routes" => ["Orange"],
          "effects" => ["Delay"]
        }
      })

      # Clear only the routes filter
      render_click(view, "reset_filter", %{"filter-id" => "routes"})

      html = render(view)
      {:ok, doc} = Floki.parse_document(html)

      # Routes should be back to default
      routes_options = Floki.find(doc, "#view_alerts_live_routes option[selected]")
      routes_values = Floki.attribute(routes_options, "value")

      assert routes_values == ["default"] or routes_values == [],
             "Expected routes to be cleared, got: #{inspect(routes_values)}"

      # Service Types should still be "2"
      service_type_options = Floki.find(doc, "#view_alerts_live_service_type option[selected]")
      service_type_values = Floki.attribute(service_type_options, "value")

      assert "2" in service_type_values,
             "Expected service_type to still be '2' after clearing routes, got: #{inspect(service_type_values)}"

      # Effects should still be "Delay"
      effects_options = Floki.find(doc, "#view_alerts_live_effects option[selected]")
      effects_values = Floki.attribute(effects_options, "value")

      assert "Delay" in effects_values,
             "Expected effects to still have Delay after clearing routes, got: #{inspect(effects_values)}"
    end
  end

  # Issue 4 specific: reset_filter on one filter doesn't wipe all three
  # Uses service_type and effects only (routes requires mocked API data for selectable options)
  @tag :logged_in_user
  test "reset_filter does not clear all filters (issue 4 regression)", %{conn: conn} do
    with_mock(RoutesRepo, [], all: fn -> [] end, get: fn id -> %{name: id} end) do
      {:ok, view, _html} = live(conn, "/alerts")

      # Set service_type and effects — both use static data available without API mocking
      render_change(view, "edit_filter", %{
        "view_alerts_live" => %{
          "service_type" => ["subway"],
          "effects" => ["Delay"]
        }
      })

      # Also set effects again to ensure both are recorded
      render_change(view, "edit_filter", %{
        "view_alerts_live" => %{
          "effects" => ["Delay"]
        }
      })

      # Clear only service_type
      render_click(view, "reset_filter", %{"filter-id" => "service_type"})

      html = render(view)
      {:ok, doc} = Floki.parse_document(html)

      # Effects must still be selected — the original bug would clear all
      effects_options = Floki.find(doc, "#view_alerts_live_effects option[selected]")
      effects_values = Floki.attribute(effects_options, "value")

      assert "Delay" in effects_values,
             "Effects should still have Delay selected after clearing service_type (issue 4 regression), got: #{inspect(effects_values)}"

      # Service Types should be cleared
      service_type_options = Floki.find(doc, "#view_alerts_live_service_type option[selected]")
      service_type_values = Floki.attribute(service_type_options, "value")

      refute "subway" in service_type_values,
             "Service Types should have been cleared, but still shows 'subway': #{inspect(service_type_values)}"
    end
  end

  # The clear button span should only appear in the rendered HTML when a filter has a value
  @tag :logged_in_user
  test "clear button span renders only for active filters", %{conn: conn} do
    with_mock(RoutesRepo, [], all: fn -> [] end, get: fn id -> %{name: id} end) do
      {:ok, view, html} = live(conn, "/alerts")

      # Initially no filters — no clear buttons
      {:ok, doc0} = Floki.parse_document(html)

      service_type_clear_initial = Floki.find(doc0, "#service_type-clear-filter-button")
      routes_clear_initial = Floki.find(doc0, "#routes-clear-filter-button")
      effects_clear_initial = Floki.find(doc0, "#effects-clear-filter-button")

      assert service_type_clear_initial == [],
             "Service Types clear button should NOT be present when no filter is set"

      assert routes_clear_initial == [],
             "Routes clear button should NOT be present when no filter is set"

      assert effects_clear_initial == [],
             "Effects clear button should NOT be present when no filter is set"

      # After setting service_type, its clear button should appear
      render_change(view, "edit_filter", %{
        "view_alerts_live" => %{"service_type" => ["2"]}
      })

      html2 = render(view)
      {:ok, doc2} = Floki.parse_document(html2)

      service_type_clear = Floki.find(doc2, "#service_type-clear-filter-button")

      assert service_type_clear != [],
             "Service Types clear button should appear after setting a filter"

      # Routes and effects should still have NO clear button
      routes_clear = Floki.find(doc2, "#routes-clear-filter-button")
      effects_clear = Floki.find(doc2, "#effects-clear-filter-button")

      assert routes_clear == [],
             "Routes clear button should NOT appear when routes filter is unset"

      assert effects_clear == [],
             "Effects clear button should NOT appear when effects filter is unset"
    end
  end

  # Issue 2: clearing one filter via reset_filter then clearing another doesn't re-select the first
  @tag :logged_in_user
  test "clearing filters in sequence does not re-add previously cleared filters", %{conn: conn} do
    with_mock(RoutesRepo, [], all: fn -> [] end, get: fn id -> %{name: id} end) do
      {:ok, view, _html} = live(conn, "/alerts")

      # Set service_type and effects, apply them (as if user clicked Apply)
      render_change(view, "edit_filter", %{
        "view_alerts_live" => %{
          "service_type" => ["2"],
          "effects" => ["Delay"]
        }
      })

      render_click(view, "apply_filter", %{
        "view_alerts_live" => %{
          "service_type" => ["2"],
          "effects" => ["Delay"]
        }
      })

      # Re-open modal: clear service_type
      render_click(view, "reset_filter", %{"filter-id" => "service_type"})

      # Now clear effects
      render_click(view, "reset_filter", %{"filter-id" => "effects"})

      html = render(view)
      {:ok, doc} = Floki.parse_document(html)

      # service_type should NOT have come back
      service_type_options = Floki.find(doc, "#view_alerts_live_service_type option[selected]")
      service_type_values = Floki.attribute(service_type_options, "value")

      service_type_clear = Floki.find(doc, "#service_type-clear-filter-button")

      assert service_type_clear == [],
             "Service Types clear button should NOT re-appear after being cleared (issue 2 regression)"

      assert service_type_values == ["default"] or service_type_values == [] or
               not ("2" in service_type_values),
             "Service Types value should NOT be re-set to '2' after clearing (issue 2 regression), got: #{inspect(service_type_values)}"
    end
  end
end
