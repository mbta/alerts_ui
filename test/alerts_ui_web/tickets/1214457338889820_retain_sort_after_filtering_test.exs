defmodule AlertsUIWeb.Tickets.RetainSortAfterFilteringTest do
  @moduledoc """
  Regression test for Asana ticket 1214457338889820
  "📌 Retain sort parameters after filtering"
  https://app.asana.com/1/15492006741476/project/1167196461144361/task/1214457338889820

  Bug: When alerts are sorted by a column, then the user adds a filter or enters a
  term in the search bar, the sort parameters were erased.

  AC: When alerts are sorted by a column, then the user adds a filter or enters a
  term in the search bar, the sorting parameters should be retained.

  These tests drive the real LiveView events (`sort-alerts`, then `apply_filter`)
  and assert that the URL the view patches to after filtering/searching still
  carries the `order_by` / `order_direction` params established by the sort.
  """
  use ExUnit.Case
  use AlertsUIWeb.ConnCase

  import AlertsUI.Support.Factory
  import Mock
  import Phoenix.LiveViewTest

  alias MBTAV3API.Routes.Repo, as: RoutesRepo

  setup do
    insert(:alert, %{
      alert_id: "123",
      active_period_start: ~U[2023-10-12 00:01:00Z],
      header_text: "this is the first alert",
      effect_detail: "DETOUR",
      original_route_selections: ["1", "2"],
      duration_certainty: :UNKNOWN
    })

    insert(:alert, %{
      alert_id: "234",
      active_period_start: ~U[2023-11-12 00:01:00Z],
      header_text: "this is the second alert",
      effect_detail: "SUMMARY",
      original_route_selections: [],
      duration_certainty: :UNKNOWN
    })

    :ok
  end

  @tag :logged_in_user
  test "sort survives entering a search term", %{conn: conn} do
    with_mock(RoutesRepo, [], all: fn -> [] end, get: fn route_id -> %{name: route_id} end) do
      {:ok, view, _html} = live(conn, "/alerts")

      # 1. Sort by a column.
      render_click(view, "sort-alerts", %{"order" => "active_period_start"})
      sort_path = assert_patch(view)
      assert sort_path =~ "order_by=active_period_start"
      assert sort_path =~ "order_direction="

      sort_query = sort_path |> URI.parse() |> Map.get(:query) |> URI.decode_query()
      assert sort_query["order_by"] == "active_period_start"
      direction = sort_query["order_direction"]
      assert direction in ["asc", "desc"]

      # 2. Enter a search term (the search bar fires apply_filter with multi_column_search).
      render_change(view, "apply_filter", %{
        "view_alerts_live" => %{"multi_column_search" => "123"}
      })

      filter_path = assert_patch(view)
      filter_query = filter_path |> URI.parse() |> Map.get(:query) |> URI.decode_query()

      # The search term is now applied...
      assert filter_query["filter[multi_column_search]"] == "123"
      # ...AND the sort parameters are RETAINED (the bug: these used to be erased).
      assert filter_query["order_by"] == "active_period_start"
      assert filter_query["order_direction"] == direction
    end
  end

  @tag :logged_in_user
  test "sort survives applying a modal filter", %{conn: conn} do
    with_mock(RoutesRepo, [], all: fn -> [] end, get: fn route_id -> %{name: route_id} end) do
      {:ok, view, _html} = live(conn, "/alerts")

      render_click(view, "sort-alerts", %{"order" => "active_period_start"})
      sort_path = assert_patch(view)

      direction =
        sort_path
        |> URI.parse()
        |> Map.get(:query)
        |> URI.decode_query()
        |> Map.fetch!("order_direction")

      # Apply a modal filter (a Service Types selection) on top of the sort.
      # service_type is the simplest modal filter field; the value shape mirrors
      # what the Filters modal submits.
      render_change(view, "apply_filter", %{
        "view_alerts_live" => %{"service_type" => ["subway"]}
      })

      filter_path = assert_patch(view)
      filter_query = filter_path |> URI.parse() |> Map.get(:query) |> URI.decode_query()

      # The modal filter is applied (service_type present in the URL)...
      assert filter_query
             |> Map.keys()
             |> Enum.any?(&String.starts_with?(&1, "filter[service_type]"))

      # ...AND the sort parameters are RETAINED (the bug: these used to be erased).
      assert filter_query["order_by"] == "active_period_start"
      assert filter_query["order_direction"] == direction
    end
  end
end
