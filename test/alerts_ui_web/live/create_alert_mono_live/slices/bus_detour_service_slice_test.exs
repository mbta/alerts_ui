defmodule AlertsUIWeb.CreateAlertMonoLive.Slices.BusDetourServiceSliceTest do
  use ExUnit.Case, async: false
  use AlertsUIWeb.ConnCase
  import Mock
  import Phoenix.LiveViewTest
  import Test.Support.Helpers

  alias MBTAV3API.Routes.Repo, as: RoutesRepo
  alias MBTAV3API.Routes.Route
  alias MBTAV3API.RoutePatterns.Repo, as: RoutePatternsRepo
  alias MBTAV3API.Stops.Repo, as: StopsRepo
  alias MBTAV3API.Stops.Stop

  @route_one %Route{
    direction_names: %{0 => "Outbound", 1 => "Inbound"},
    sort_order: 1,
    id: "1",
    type: 3,
    name: "1"
  }

  @route_two %Route{
    direction_names: %{0 => "Outbound", 1 => "Inbound"},
    sort_order: 1,
    id: "2",
    type: 3,
    name: "2"
  }

  @stop_one %Stop{
    id: "72",
    type: 3,
    name: "Mass Ave at Pearl St"
  }

  @tag :logged_in_user
  test "bus detour slice is displayed when bus detour is selected", %{conn: conn} do
    with_mocks([
      {RoutesRepo, [],
       [
         by_type: fn _ -> [@route_one] end,
         get: fn _, _ -> @route_one end
       ]},
      {StopsRepo, [], [by_route: fn _, _, _ -> [@stop_one] end]}
    ]) do
      conn = put_resp_cookie(conn, "show_new_bus_detours", "true")
      {:ok, view, _html} = live(conn, "/alerts/new")
      view = get_to_submission_page_refactor(conn, view, "Bus", "Detour")

      assert render_async(view) =~ "Bus Detour affected service"
    end
  end

  @tag :logged_in_user
  test "detour select is disabled until route is selected", %{conn: conn} do
    with_mocks([
      {RoutesRepo, [],
       [
         by_type: fn _ -> [@route_two] end,
         get: fn _, _ -> @route_two end
       ]},
      {StopsRepo, [], [by_route: fn _, _, _ -> [@stop_one] end]}
    ]) do
      conn = put_resp_cookie(conn, "show_new_bus_detours", "true")
      {:ok, view, _html} = live(conn, "/alerts/new")
      view = get_to_submission_page_refactor(conn, view, "Bus", "Detour")

      refute view |> element("#alert_data_skate_detour_id_selector") |> render_async =~
               "No active detours in Skate"

      view
      |> element("form")
      |> render_change(%{
        "_target" => ["alert_data", "single_route_id"],
        "alert_data" => %{"route_ids" => ["2"], "single_route_id" => "2"}
      })

      assert view |> element("#alert_data_skate_detour_id_selector") |> render_async =~
               "No active detours in Skate"
    end
  end

  @tag :logged_in_user
  test "detour select is displayed if one matches selected route", %{conn: conn} do
    with_mocks([
      {RoutesRepo, [],
       [
         by_type: fn _ -> [@route_one] end,
         get: fn _, _ -> @route_one end
       ]},
      {StopsRepo, [], [by_route: fn _, _, _ -> [@stop_one] end]}
    ]) do
      conn = put_resp_cookie(conn, "show_new_bus_detours", "true")
      {:ok, view, _html} = live(conn, "/alerts/new")
      view = get_to_submission_page_refactor(conn, view, "Bus", "Detour")

      render_async(view)

      view
      |> element("form")
      |> render_change(%{
        "_target" => ["alert_data", "single_route_id"],
        "alert_data" => %{"route_ids" => ["1"], "single_route_id" => "1"}
      })

      assert view |> element("#alert_data_skate_detour_id_selector") |> render_async =~ "Inbound"

      assert view |> element("#alert_data_skate_detour_id_selector") |> render_async =~
               "Massachusetts"
    end
  end

  @tag :logged_in_user
  test "selecting a detour selects its direction and stop, and disables those selectors", %{
    conn: conn
  } do
    with_mocks([
      {RoutesRepo, [],
       [
         by_type: fn _ -> [@route_one] end,
         get: fn _, _ -> @route_one end
       ]},
      {StopsRepo, [], [by_route: fn _, _, _ -> [@stop_one] end]}
    ]) do
      conn = put_resp_cookie(conn, "show_new_bus_detours", "true")
      {:ok, view, _html} = live(conn, "/alerts/new")
      view = get_to_submission_page_refactor(conn, view, "Bus", "Detour")

      render_async(view)

      view
      |> element("form")
      |> render_change(%{
        "_target" => ["alert_data", "single_route_id"],
        "alert_data" => %{"route_ids" => ["1"], "single_route_id" => "1"}
      })

      render_async(view)

      view
      |> element("form")
      |> render_change(%{
        "_target" => ["alert_data", "skate_detour_id"],
        "alert_data" => %{"skate_detour_id" => 7}
      })

      render_async(view)

      assert view |> element("#alert_data_direction") |> render_async =~ ~s(disabled="")

      assert view |> element("#alert_data_direction") |> render_async =~
               ~s(<option selected="" value="1">Inbound</option>)

      assert view |> element("#alert_data_stop_names_and_ids_selector") |> render_async =~
               ~s(disabled="")

      assert view |> element("#alert_data_stop_names_and_ids_selector") |> render_async =~
               ~s(title="Stop ID 72" selected="" value="Mass Ave at Pearl St \(inbound\)|72">Mass Ave at Pearl St \(inbound\))

      assert view |> element("#alert_data_header_text") |> render_async =~
               "Route 1 inbound is detoured, skipping Mass Ave at Pearl St (inbound). The closest stops with service are ___ and ___."
    end
  end

  @tag :logged_in_user
  test "if a skate detour is selected, the skate detour id is persisted", %{conn: conn} do
    with_mocks([
      {RoutesRepo, [],
       [
         by_type: fn _ -> [@route_one] end,
         get: fn _, _ -> @route_one end
       ]},
      {StopsRepo, [], [by_route: fn _, _, _ -> [@stop_one] end, all: fn _, _ -> [@stop_one] end]},
        {RoutePatternsRepo, [],
         [
           by_route_id: fn _, _ -> [] end
         ]}
    ]) do
      conn = put_resp_cookie(conn, "show_new_bus_detours", "true")
      {:ok, view, _html} = live(conn, "/alerts/new")
      view = get_to_submission_page_refactor(conn, view, "Bus", "Detour")

      render_async(view)

      view
      |> element("form")
      |> render_change(%{
        "_target" => ["alert_data", "single_route_id"],
        "alert_data" => %{"route_ids" => ["1"], "single_route_id" => "1"}
      })

      render_async(view)

      view
      |> element("form")
      |> render_change(%{
        "_target" => ["alert_data", "skate_detour_id"],
        "alert_data" => %{"skate_detour_id" => 7}
      })

      render_async(view)

      open_review_modal(view)
      submit_alert(view)

      new_alert = parse_alert_created_output(view)

      assert new_alert.skate_detour_id == 7
    end
  end
end
