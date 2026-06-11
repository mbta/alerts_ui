defmodule AlertsUIWeb.CreateAlertMonoLive.Slices.StopRouteServiceSliceTest do
  use ExUnit.Case, async: false
  use AlertsUIWeb.ConnCase
  import AlertsUI.Support.Factory
  import Phoenix.LiveViewTest
  import Mock
  import Test.Support.Helpers
  alias AlertsUI.Alerts
  alias AlertsUIWeb.CreateAlertMonoLive.Slices.StopRouteServiceSlice
  alias MBTAV3API.RoutePatterns.Repo, as: RoutePatternsRepo
  alias MBTAV3API.Routes.Repo, as: RoutesRepo
  alias MBTAV3API.Routes.Route
  alias MBTAV3API.Schedules.Repo, as: SchedulesRepo
  alias MBTAV3API.Stops.Repo, as: StopsRepo
  alias MBTAV3API.Stops.Stop

  describe "stop_id_options/5 preservation logic" do
    test "a stop that was selected but is no longer in available_stops disappears when selected_stops is empty" do
      available_stops = [%Stop{id: "place-dwnxg", name: "Downtown Crossing"}]

      options =
        StopRouteServiceSlice.stop_id_options(
          available_stops,
          [],
          nil,
          1,
          ["place-pktrm"]
        )

      option_values = Enum.map(options, &Keyword.get(&1, :value))

      refute "place-pktrm" in option_values,
             "Expected Park Street to be absent from options, but it appeared — " <>
               "this would mean preservation is working, disproving the hypothesis"
    end

    test "a stop that was selected IS preserved when it is present in selected_stops" do
      park_street = %Stop{id: "place-pktrm", name: "Park Street"}
      available_stops = [%Stop{id: "place-dwnxg", name: "Downtown Crossing"}]

      options =
        StopRouteServiceSlice.stop_id_options(
          available_stops,
          [park_street],
          nil,
          1,
          ["place-pktrm"]
        )

      option_values = Enum.map(options, &Keyword.get(&1, :value))

      assert "place-pktrm" in option_values,
             "Expected Park Street to be preserved in options when selected_stops is populated"
    end
  end

  # Subway routes (type 1) for "Station closure" → combination :SR
  @route %Route{sort_order: 1, id: "Blue", name: "Blue Line", type: 1}
  @route_two %Route{sort_order: 2, id: "Red", name: "Red Line", type: 1}

  describe "route_id_options/4 filtering" do
    test "selected routes remain visible even when they don't match the search term" do
      routes = [@route, @route_two]

      options = StopRouteServiceSlice.route_id_options(routes, ["Blue", "Red"], "Blue", 1)
      values = Enum.map(options, &Keyword.get(&1, :value))

      assert "Blue" in values
      assert "Red" in values
    end

    test "unselected routes are hidden when they don't match the search term" do
      routes = [@route, @route_two]

      options = StopRouteServiceSlice.route_id_options(routes, ["Blue"], "Blue", 1)
      values = Enum.map(options, &Keyword.get(&1, :value))

      assert "Blue" in values
      refute "Red" in values
    end
  end

  @shuttle_route %Route{
    sort_order: 99,
    id: "Shuttle-BlueLine",
    name: "Blue Line Shuttle",
    description: :rail_replacement_bus,
    type: 1
  }
  @stop %Stop{id: "place-aqucl", name: "Aquarium"}
  @stop_two %Stop{id: "place-pktrm", name: "Park Street"}
  @stop_two_but_different %Stop{id: "place-pktrm-inbound", name: "Park Street"}
  # Bus route (type 3) used for direction-ordering tests (SR combination via Multi-route detour)
  @bus_route_one %Route{sort_order: 1, id: "Blue", name: "Blue Line", type: 3}

  defp base_mocks do
    [
      {RoutesRepo, [],
       [
         by_type: fn _ -> [@route] end,
         by_stop: fn _ -> [@route] end,
         by_stop: fn _, _ -> [@route] end
       ]},
      {StopsRepo, [],
       [
         by_route_type: fn _, _ -> [@stop] end,
         by_route: fn _, _, _ -> [@stop] end
       ]}
    ]
  end

  describe "component" do
    @tag :logged_in_user
    test "renders", %{conn: conn} do
      with_mocks(base_mocks()) do
        {:ok, view, _html} = live(conn, "/alerts/mono/new")
        get_to_submission_page_refactor(view, "Subway", "Station closure")
        render_async(view)
        assert render(view) =~ ~s(id="stop_route_service_view")
      end
    end

    @tag :logged_in_user
    test "route options are disabled until a stop is chosen", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _ -> [@route, @shuttle_route] end,
           by_stop: fn _ -> [@route, @shuttle_route] end,
           by_stop: fn _, _ -> [@route, @shuttle_route] end
         ]},
        {StopsRepo, [],
         [
           by_route_type: fn _, _ -> [@stop] end,
           by_route: fn _, _, _ -> [@stop] end
         ]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/mono/new")
        get_to_submission_page_refactor(view, "Subway", "Station closure")
        render_async(view)
        {:ok, document} = view |> render() |> Floki.parse_document()

        assert document_has_element?(
                 document,
                 "select[id=\"alert_data_route_ids\"][disabled]"
               )
      end
    end

    @tag :logged_in_user
    test "shuttle routes are filtered out of routes filter list", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _ -> [@route, @shuttle_route] end,
           by_stop: fn _ -> [@route, @shuttle_route] end,
           by_stop: fn _, _ -> [@route, @shuttle_route] end
         ]},
        {StopsRepo, [],
         [
           by_route_type: fn _, _ -> [@stop] end,
           by_route: fn _, _, _ -> [@stop] end
         ]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/mono/new")
        get_to_submission_page_refactor(view, "Subway", "Station closure")
        render_async(view)

        refute render(view) =~ "Shuttle"
      end
    end

    # Uses Bus + "Multi-route detour" because bus route loading filters rail_replacement_bus
    # routes from the impacted routes list after stop selection.
    @tag :logged_in_user
    test "shuttle routes are filtered when stop selected", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _ -> [@bus_route_one, @shuttle_route] end,
           by_stop: fn _ -> [@bus_route_one, @shuttle_route] end,
           by_stop: fn _, _ -> [@bus_route_one, @shuttle_route] end
         ]},
        {StopsRepo, [],
         [
           by_route: fn _, _, _ -> [@stop] end
         ]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/mono/new")
        get_to_submission_page_refactor(view, "Bus", "Multi-route detour")

        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "stop_ids"],
          "alert_data" => %{"stop_ids" => ["place-aqucl"]}
        })

        render_async(view)

        refute render(view) =~ "Shuttle"
      end
    end

    @tag :logged_in_user
    test "route options are populated after stop selection and allows user entry", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _ -> [@route, @shuttle_route] end,
           by_stop: fn _ -> [@route, @route_two] end,
           by_stop: fn _, _ -> [@route, @route_two] end
         ]},
        {StopsRepo, [],
         [
           by_route_type: fn _, _ -> [@stop] end,
           by_route: fn _, _, _ -> [@stop] end
         ]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/mono/new")
        get_to_submission_page_refactor(view, "Subway", "Station closure")

        assert view |> render_async() =~ ~s(value="place-aqucl">)

        # Select a stop — both routes become available in the route selector
        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "stop_ids"],
          "alert_data" => %{"stop_ids" => ["place-aqucl"]}
        })

        assert view |> render_async() =~ ~s(value="place-aqucl")
        assert view |> render_async() =~ ~s(value="Blue">)
        assert view |> render_async() =~ ~s(value="Red">)

        # User explicitly selects the Red route only
        view
        |> element("form")
        |> render_change(%{
          "alert_data" => %{"route_ids" => ["Red"]}
        })

        {:ok, document} =
          view
          |> render_async()
          |> Floki.parse_document()

        refute document_has_element?(
                 document,
                 "#alert_data_route_ids > option[value=\"Blue\"][selected=\"selected\"]"
               )

        assert document_has_element?(
                 document,
                 "#alert_data_route_ids > option[value=\"Red\"][selected=\"selected\"]"
               )
      end
    end

    @tag :logged_in_user
    test "stop search works", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _ -> [@route, @route_two] end,
           by_stop: fn _ -> [@route, @route_two] end,
           by_stop: fn _, _ -> [@route, @route_two] end
         ]},
        {StopsRepo, [],
         [
           by_route_type: fn _, _ -> [@stop, @stop_two] end,
           by_route: fn _, _, _ -> [@stop, @stop_two] end
         ]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/mono/new")
        get_to_submission_page_refactor(view, "Subway", "Station closure")
        render_async(view)

        {:ok, document} = view |> render() |> Floki.parse_document()

        assert document_has_element?(
                 document,
                 "option[value=\"place-aqucl\"]"
               )

        assert document_has_element?(
                 document,
                 "option[value=\"place-pktrm\"]"
               )

        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "stop_search_term"],
          "alert_data" => %{"stop_search_term" => "Aqua"}
        })

        render_async(view)

        {:ok, document} = view |> render() |> Floki.parse_document()

        assert document_has_element?(
                 document,
                 "option[value=\"place-aqucl\"]"
               )

        refute document_has_element?(
                 document,
                 "option[value=\"place-pktrm\"]"
               )
      end
    end

    @tag :logged_in_user
    test "stop search can clear", %{conn: conn} do
      with_mocks(base_mocks()) do
        {:ok, view, _html} = live(conn, "/alerts/mono/new")
        get_to_submission_page_refactor(view, "Subway", "Station closure")
        render_async(view)

        {:ok, document} = view |> render() |> Floki.parse_document()

        assert document_has_element?(
                 document,
                 "option[value=\"place-aqucl\"]"
               )

        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "stop_search_term"],
          "alert_data" => %{"stop_search_term" => "x"}
        })

        render_async(view)

        {:ok, document} = view |> render() |> Floki.parse_document()

        refute document_has_element?(
                 document,
                 "option[value=\"place-aqucl\"]"
               )

        render_click(view, "reset_search_filter", %{"name" => "alert_data[stop_search_term]"})
        render_async(view)

        {:ok, document} = view |> render() |> Floki.parse_document()

        assert document_has_element?(
                 document,
                 "option[value=\"place-aqucl\"]"
               )
      end
    end

    # Uses Bus + "Multi-route detour" because bus route loading adds direction suffixes
    # to stop names, which is required to test direction-based ordering.
    @tag :logged_in_user
    test "stop order is by name when not filtering and by direction when filtering", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           by_stop: fn _ -> [@bus_route_one] end,
           by_stop: fn _, _ -> [@bus_route_one] end,
           by_type: fn _ -> [@bus_route_one] end
         ]},
        {StopsRepo, [],
         [
           by_route: fn
             "Blue", 0, _opts -> [@stop, @stop_two]
             "Blue", 1, _opts -> [@stop, @stop_two_but_different]
           end
         ]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/mono/new")
        get_to_submission_page_refactor(view, "Bus", "Multi-route detour")
        render_async(view)

        assert view
               |> element("select#alert_data_stop_ids")
               |> render_async() =~
                 ~r/value="place-aqucl".*value="place-pktrm-inbound".*value="place-pktrm"/

        # Add route filter
        view
        |> element("form")
        |> render_change(%{
          "alert_data" => %{"modal_route_id" => "Blue"}
        })

        # Submit filter
        render_click(view, "accept_filter")

        {:ok, document} =
          view
          |> render_async()
          |> Floki.parse_document()

        assert document_has_element?(
                 document,
                 "select#alert_data_stop_ids > option[value=\"place-pktrm-inbound\"]"
               )

        assert document_has_element?(
                 document,
                 "select#alert_data_stop_ids > option[value=\"place-aqucl\"]"
               )

        assert document_has_element?(
                 document,
                 "select#alert_data_stop_ids > option[value=\"place-pktrm\"]"
               )
      end
    end

    @tag :logged_in_user
    test "modal route search works", %{conn: conn} do
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
        {:ok, view, _html} = live(conn, "/alerts/mono/new")
        get_to_submission_page_refactor(view, "Subway", "Station closure")
        render_async(view)

        {:ok, document} = view |> render() |> Floki.parse_document()

        assert document_has_element?(
                 document,
                 "select#alert_data_modal_route_id > option[value=\"Blue\"]"
               )

        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "modal_route_search_term"],
          "alert_data" => %{"modal_route_search_term" => "Red"}
        })

        render_async(view)

        {:ok, document} = view |> render() |> Floki.parse_document()

        refute document_has_element?(
                 document,
                 "select#alert_data_modal_route_id > option[value=\"Blue\"]"
               )

        assert document_has_element?(
                 document,
                 "select#alert_data_modal_route_id > option[value=\"Red\"]"
               )
      end
    end

    @tag :logged_in_user
    test "modal route search can clear", %{conn: conn} do
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
        {:ok, view, _html} = live(conn, "/alerts/mono/new")
        get_to_submission_page_refactor(view, "Subway", "Station closure")
        render_async(view)

        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "modal_route_search_term"],
          "alert_data" => %{"modal_route_search_term" => "Red"}
        })

        render_async(view)

        {:ok, document} = view |> render() |> Floki.parse_document()

        refute document_has_element?(
                 document,
                 "select#alert_data_modal_route_id > option[value=\"Blue\"]"
               )

        render_click(view, "reset_search_filter", %{
          "name" => "alert_data[modal_route_search_term]"
        })

        render_async(view)

        {:ok, document} = view |> render() |> Floki.parse_document()

        assert document_has_element?(
                 document,
                 "select#alert_data_modal_route_id > option[value=\"Blue\"]"
               )
      end
    end

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
        {:ok, view, _html} = live(conn, "/alerts/mono/new")
        get_to_submission_page_refactor(view, "Subway", "Station closure")

        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "stop_ids"],
          "alert_data" => %{"stop_ids" => ["place-aqucl"]}
        })

        render_async(view)

        {:ok, document} = view |> render() |> Floki.parse_document()

        assert document_has_element?(
                 document,
                 "select#alert_data_route_ids > option[value=\"Blue\"]"
               )

        assert document_has_element?(
                 document,
                 "select#alert_data_route_ids > option[value=\"Red\"]"
               )

        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "route_search_term"],
          "alert_data" => %{"route_search_term" => "Blue"}
        })

        render_async(view)

        {:ok, document} = view |> render() |> Floki.parse_document()

        assert document_has_element?(
                 document,
                 "select#alert_data_route_ids > option[value=\"Blue\"]"
               )

        # Red is auto-selected after stop selection, so it stays visible even when the search doesn't match
        assert document_has_element?(
                 document,
                 "select#alert_data_route_ids > option[value=\"Red\"]"
               )
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
        {:ok, view, _html} = live(conn, "/alerts/mono/new")
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

        assert document_has_element?(
                 document,
                 "select#alert_data_route_ids > option[value=\"Blue\"]"
               )

        assert document_has_element?(
                 document,
                 "select#alert_data_route_ids > option[value=\"Red\"]"
               )
      end
    end

    @tag :logged_in_user
    test "route search hides a route that was deselected by the user", %{conn: conn} do
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
        {:ok, view, _html} = live(conn, "/alerts/mono/new")
        get_to_submission_page_refactor(view, "Subway", "Station closure")

        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "stop_ids"],
          "alert_data" => %{"stop_ids" => ["place-aqucl"]}
        })

        render_async(view)

        # Deselect Red — only Blue is now selected
        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "route_ids"],
          "alert_data" => %{"route_ids" => ["Blue"]}
        })

        render_async(view)

        # Search for "Blue" — Red is not selected so it should be hidden
        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "route_search_term"],
          "alert_data" => %{"route_search_term" => "Blue"}
        })

        render_async(view)

        {:ok, document} = view |> render() |> Floki.parse_document()

        assert document_has_element?(
                 document,
                 "select#alert_data_route_ids > option[value=\"Blue\"]"
               )

        refute document_has_element?(
                 document,
                 "select#alert_data_route_ids > option[value=\"Red\"]"
               )
      end
    end

    @tag :logged_in_user
    test "add route filter on stops works", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _ -> [@route, @route_two] end,
           by_stop: fn _ -> [@route, @route_two] end,
           by_stop: fn _, _ -> [@route, @route_two] end
         ]},
        {StopsRepo, [],
         [
           by_route_type: fn _, _ -> [@stop, @stop_two] end,
           by_route: fn
             "Blue", _, _ -> [@stop]
             _, _, _ -> [@stop, @stop_two]
           end
         ]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/mono/new")
        get_to_submission_page_refactor(view, "Subway", "Station closure")
        render_async(view)

        assert render(view) =~ "place-aqucl"
        assert render(view) =~ "place-pktrm"

        # Set modal route filter
        view
        |> element("form")
        |> render_change(%{
          "alert_data" => %{"modal_route_id" => "Blue"}
        })

        render_click(view, "accept_filter")
        render_async(view)

        assert render(view) =~ ~s(Filter: Blue Line)
        assert render(view) =~ "place-aqucl"
        refute render(view) =~ "place-pktrm"
      end
    end

    @tag :logged_in_user
    test "selections are preserved after route filter applied", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _ -> [@route, @route_two] end,
           by_stop: fn "place-pktrm" -> [@route_two] end
         ]},
        {StopsRepo, [],
         [
           by_route_type: fn _, _ -> [@stop, @stop_two] end,
           by_route: fn
             "Blue", _, _ -> [@stop]
             "Red", _, _ -> [@stop_two]
           end
         ]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/mono/new")
        get_to_submission_page_refactor(view, "Subway", "Station closure")
        render_async(view)

        # Select Park Street
        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "stop_ids"],
          "alert_data" => %{"stop_ids" => ["place-pktrm"]}
        })

        render_async(view)

        # Apply route filter that would ordinarily exclude Park Street (only Blue → Aquarium).
        # Use _target so the modal_route_id change does not trigger an unnecessary async reload
        # that would overwrite the socket's selections state before accept_filter fires.
        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "modal_route_id"],
          "alert_data" => %{"modal_route_id" => "Blue"}
        })

        render_click(view, "accept_filter")
        render_async(view)

        {:ok, document} = view |> render() |> Floki.parse_document()

        assert document_has_element?(
                 document,
                 "select#alert_data_stop_ids > option[value=\"place-pktrm\"][selected=\"selected\"]"
               ),
               "Park Street should be preserved since it was previously selected"

        assert document_has_element?(
                 document,
                 "select#alert_data_stop_ids > option[value=\"place-aqucl\"]"
               ),
               "Aquarium should also appear (from filtered route Blue)"
      end
    end

    @tag :logged_in_user
    test "clear route filter works", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _ -> [@route, @route_two] end,
           by_stop: fn _ -> [@route, @route_two] end,
           by_stop: fn _, _ -> [@route, @route_two] end
         ]},
        {StopsRepo, [],
         [
           by_route_type: fn _, _ -> [@stop, @stop_two] end,
           by_route: fn
             "Blue", _, _ -> [@stop]
             _, _, _ -> [@stop, @stop_two]
           end
         ]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/mono/new")
        get_to_submission_page_refactor(view, "Subway", "Station closure")
        render_async(view)

        # Apply route filter
        view
        |> element("form")
        |> render_change(%{"alert_data" => %{"modal_route_id" => "Blue"}})

        render_click(view, "accept_filter")
        render_async(view)

        assert render(view) =~ ~s(Filter: Blue Line)

        # Clear filter
        render_click(view, "clear_filter", %{"filter-id" => "routes-filter-modal"})
        render_async(view)

        assert render(view) =~ ~s(Filter: All routes)
        assert render(view) =~ "place-pktrm"
      end
    end

    @tag :logged_in_user
    test "works correctly if editing", %{conn: conn} do
      alert_params =
        build(:alert_map, %{
          alert_id: "test-sr-edit",
          effect: :NO_SERVICE,
          effect_detail: "STATION_CLOSURE",
          effect_name: "Station Closure",
          primary_service_type: "1",
          informed_entity: [
            %{route_type: 1, stop_id: "place-aqucl", route_id: "Blue"}
          ],
          original_stop_selections: ["place-aqucl"],
          original_route_selections: ["Blue Line|Blue"]
        })

      {:ok, _} = Alerts.create_or_update_alert(alert_params, build(:user))

      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _ -> [@route] end,
           get: fn _ -> @route end,
           get: fn _, _ -> @route end,
           by_stop: fn _ -> [@route] end,
           by_stop: fn _, _ -> [@route] end
         ]},
        {StopsRepo, [],
         [
           by_route_type: fn _, _ -> [@stop] end,
           by_route: fn _, _, _ -> [@stop] end,
           get_parent: fn _ -> @stop end
         ]},
        {SchedulesRepo, [],
         [
           by_route_ids: fn _, _ -> [] end,
           end_of_rating: fn -> Date.utc_today() end
         ]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/mono/edit/test-sr-edit")
        render_async(view)

        {:ok, document} = view |> render() |> Floki.parse_document()

        assert document_has_element?(
                 document,
                 "option[value=\"place-aqucl\"][selected=\"selected\"]"
               )
      end
    end

    @tag :logged_in_user
    test "form is valid with stop and route selected", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _ -> [@route] end,
           by_stop: fn _ -> [@route] end,
           by_stop: fn _, _ -> [@route] end,
           get: fn _ -> @route end,
           get: fn _, _ -> @route end
         ]},
        {StopsRepo, [],
         [
           by_route_type: fn _, _ -> [@stop] end,
           by_route: fn _, _ -> [@stop] end,
           by_route: fn _, _, _ -> [@stop] end,
           get: fn _ -> @stop end,
           get_parent: fn _ -> nil end
         ]},
        {RoutePatternsRepo, [],
         [
           by_route_id: fn _, _ -> [] end,
           included_stops_by_route_id: fn _, _ -> [] end
         ]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/mono/new")
        get_to_submission_page_refactor(view, "Subway", "Station closure")
        render_async(view)

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
          "alert_data" => %{"route_ids" => ["Blue"]}
        })

        render_async(view)

        view |> element("button#review", "Review and submit") |> render_click()

        # With valid stop + route, no stop/route validation errors should appear
        refute render(view) =~ "You must select a stop"
        refute render(view) =~ "You must select a route"
      end
    end

    @tag :logged_in_user
    test "review modal shows errors when stop and route not selected", %{conn: conn} do
      with_mocks(base_mocks()) do
        {:ok, view, _html} = live(conn, "/alerts/mono/new")
        get_to_submission_page_refactor(view, "Subway", "Station closure")
        render_async(view)

        view |> element("button#review", "Review and submit") |> render_click()

        refute has_element?(view, "#review-modal-container")
        assert render(view) =~ "Please fix the following errors"
      end
    end

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

        header_html = view |> element("#alert_data_header_text") |> render()
        assert header_html =~ "Blue Line"
        assert header_html =~ "Aquarium"
      end
    end
  end

  describe "end-to-end" do
    @tag :logged_in_user
    test "route options are all selected by default and correctly create informed entities", %{
      conn: conn
    } do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _ -> [@route, @route_two] end,
           by_stop: fn _ -> [@route, @route_two] end,
           by_stop: fn _, _ -> [@route, @route_two] end,
           get: fn
             "Blue" -> @route
             _ -> @route_two
           end,
           get: fn
             "Blue", _ -> @route
             _, _ -> @route_two
           end,
           all: fn _ -> [] end
         ]},
        {StopsRepo, [],
         [
           by_route_type: fn _, _ -> [@stop, @stop_two] end,
           by_route: fn _, _ -> [@stop, @stop_two] end,
           by_route: fn _, _, _ -> [@stop, @stop_two] end,
           get: fn _ -> @stop end,
           get_parent: fn _ -> nil end,
           all: fn ["filter[id]": "place-aqucl,place-pktrm"], _opts -> [@stop, @stop_two] end
         ]},
        {RoutePatternsRepo, [],
         [
           by_route_id: fn _, _ -> [] end,
           included_stops_by_route_id: fn _, _ -> [] end
         ]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/mono/new")
        get_to_submission_page_refactor(view, "Subway", "Station closure")
        render_async(view)

        # Select first stop — both routes should auto-select
        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "stop_ids"],
          "alert_data" => %{"stop_ids" => ["place-aqucl"]}
        })

        render_async(view)

        {:ok, document} = view |> render_async() |> Floki.parse_document()
        assert document_has_element?(document, "option[value=\"Blue\"][selected=\"selected\"]")
        assert document_has_element?(document, "option[value=\"Red\"][selected=\"selected\"]")

        # Select second stop
        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "stop_ids"],
          "alert_data" => %{"stop_ids" => ["place-aqucl", "place-pktrm"]}
        })

        render_async(view)

        # Fill in required header text
        view
        |> element("form")
        |> render_change(%{"alert_data" => %{"header_text" => "test alert"}})

        view |> element("button#review", "Review and submit") |> render_click()

        assert has_element?(view, "#review-modal-container")

        view |> element("#review-modal-container button", "Submit") |> render_click()

        flash = assert_redirect(view, "/")

        alert_id =
          flash["info"]
          |> String.replace("New alert #", "")
          |> String.replace(" created", "")

        new_alert = AlertsUI.Alerts.get_by_alert_id(alert_id)

        assert [
                 %{route_id: "Blue", route_type: 1, stop_id: "place-aqucl"},
                 %{route_id: "Red", route_type: 1, stop_id: "place-aqucl"},
                 %{route_id: "Blue", route_type: 1, stop_id: "place-pktrm"},
                 %{route_id: "Red", route_type: 1, stop_id: "place-pktrm"}
               ] =
                 Map.get(new_alert, :informed_entity)

        # Edit the alert and verify informed entities are preserved
        {:ok, view, _html} = live(conn, "/alerts/mono/edit/#{alert_id}")
        render_async(view)

        view
        |> element("form")
        |> render_change(%{"alert_data" => %{"header_text" => "edited alert"}})

        view |> element("button#review", "Review and submit") |> render_click()

        assert has_element?(view, "#review-modal-container")

        view |> element("#review-modal-container button", "Submit") |> render_click()

        assert_redirect(view, "/")

        edited_alert = AlertsUI.Alerts.get_by_alert_id(alert_id)

        assert [
                 %{route_id: "Blue", route_type: 1, stop_id: "place-aqucl"},
                 %{route_id: "Red", route_type: 1, stop_id: "place-aqucl"},
                 %{route_id: "Blue", route_type: 1, stop_id: "place-pktrm"},
                 %{route_id: "Red", route_type: 1, stop_id: "place-pktrm"}
               ] =
                 Map.get(edited_alert, :informed_entity)
      end
    end

    @tag :logged_in_user
    test "selecting a subset of the default routes correctly creates informed entities", %{
      conn: conn
    } do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _ -> [@route, @route_two] end,
           by_stop: fn _ -> [@route, @route_two] end,
           by_stop: fn _, _ -> [@route, @route_two] end,
           get: fn
             "Blue" -> @route
             _ -> @route_two
           end,
           get: fn
             "Blue", _ -> @route
             _, _ -> @route_two
           end
         ]},
        {StopsRepo, [],
         [
           by_route_type: fn _, _ -> [@stop] end,
           by_route: fn _, _ -> [@stop] end,
           by_route: fn _, _, _ -> [@stop] end,
           get: fn _ -> @stop end,
           get_parent: fn _ -> nil end,
           all: fn ["filter[id]": "place-aqucl"], _opts -> [@stop] end
         ]},
        {RoutePatternsRepo, [],
         [
           by_route_id: fn _, _ -> [] end,
           included_stops_by_route_id: fn _, _ -> [] end
         ]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/mono/new")
        get_to_submission_page_refactor(view, "Subway", "Station closure")
        render_async(view)

        # Select stop — both routes should auto-select by default
        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "stop_ids"],
          "alert_data" => %{"stop_ids" => ["place-aqucl"]}
        })

        render_async(view)

        {:ok, document} = view |> render_async() |> Floki.parse_document()
        assert document_has_element?(document, "option[value=\"Blue\"][selected=\"selected\"]")
        assert document_has_element?(document, "option[value=\"Red\"][selected=\"selected\"]")

        # Explicitly select only Red route (subset of defaults)
        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "route_ids"],
          "alert_data" => %{"route_ids" => ["Red"]}
        })

        render_async(view)

        {:ok, document} = view |> render_async() |> Floki.parse_document()
        assert document_has_element?(document, "option[value=\"Blue\"]")
        assert document_has_element?(document, "option[value=\"Red\"][selected=\"selected\"]")

        view
        |> element("form")
        |> render_change(%{"alert_data" => %{"header_text" => "test alert"}})

        view |> element("button#review", "Review and submit") |> render_click()

        assert has_element?(view, "#review-modal-container")

        view |> element("#review-modal-container button", "Submit") |> render_click()

        flash = assert_redirect(view, "/")

        alert_id =
          flash["info"]
          |> String.replace("New alert #", "")
          |> String.replace(" created", "")

        new_alert = AlertsUI.Alerts.get_by_alert_id(alert_id)

        assert [%{route_id: "Red"}] = Map.get(new_alert, :informed_entity)
      end
    end

    @tag :logged_in_user
    test "publishing a bus multi-route detour AFTER selecting and deselecting will put up a flash error for the missing route",
         %{conn: conn} do
      with_mocks([
        {RoutesRepo, [], [by_type: fn _ -> [@route, @route_two] end]},
        {StopsRepo, [], [by_route: fn _, _, _ -> [@stop] end]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/mono/new")
        get_to_submission_page_refactor(view, "Bus", "Multi-route detour")
        render_async(view)

        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "stop_ids"],
          "alert_data" => %{"stop_ids" => [], "route_ids" => []}
        })

        view |> element("button#review", "Review and submit") |> render_click()

        assert has_element?(view, "p.text-text-error", "Select stop(s)")
        assert has_element?(view, "p.text-text-error", "Select route(s)")

        flash_html = view |> element("#flash") |> render()
        assert flash_html =~ "Select stop(s)"
        assert flash_html =~ "Select route(s)"
      end
    end

    @tag :logged_in_user
    test "route options are all selected by default and allows user entry", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _ -> [@route, @route_two] end,
           by_stop: fn _ -> [@route, @route_two] end
         ]},
        {StopsRepo, [],
         [
           by_route_type: fn _, _ -> [@stop] end,
           by_route: fn _, _, _ -> [@stop] end,
           all: fn ["filter[id]": "place-aqucl"], _opts -> [@stop] end
         ]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/mono/new")
        get_to_submission_page_refactor(view, "Subway", "Station closure")
        render_async(view)

        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "stop_ids"],
          "alert_data" => %{"stop_ids" => ["place-aqucl"]}
        })

        render_async(view)

        {:ok, document} = view |> render_async() |> Floki.parse_document()
        assert document_has_element?(document, "option[value=\"Blue\"][selected=\"selected\"]")
        assert document_has_element?(document, "option[value=\"Red\"][selected=\"selected\"]")

        # User deselects Blue, keeping only Red
        view
        |> element("form")
        |> render_change(%{
          "alert_data" => %{"route_ids" => ["Red"]}
        })

        render_async(view)

        {:ok, document} = view |> render_async() |> Floki.parse_document()
        refute document_has_element?(document, "option[value=\"Blue\"][selected=\"selected\"]")
        assert document_has_element?(document, "option[value=\"Red\"][selected=\"selected\"]")
      end
    end

    @tag :logged_in_user
    test "route options are reselected when stop changes", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _ -> [@route, @route_two] end,
           by_stop: fn
             "place-aqucl" -> [@route]
             "place-pktrm" -> [@route_two]
           end
         ]},
        {StopsRepo, [],
         [
           by_route_type: fn _, _ -> [@stop, @stop_two] end,
           by_route: fn "Blue", _direction -> [@stop] end,
           by_route: fn "Red", _direction -> [@stop_two] end,
           all: fn ["filter[id]": "place-aqucl"], _opts -> [@stop, @stop_two] end
         ]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/mono/new")
        get_to_submission_page_refactor(view, "Subway", "Station closure")
        render_async(view)

        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "stop_ids"],
          "alert_data" => %{"stop_ids" => ["place-aqucl"]}
        })

        render_async(view)

        {:ok, document} = view |> render_async() |> Floki.parse_document()
        assert document_has_element?(document, "option[value=\"Blue\"][selected=\"selected\"]")
        refute document_has_element?(document, "option[value=\"Red\"][selected=\"selected\"]")

        # User selects place-pktrm on Red instead
        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "stop_ids"],
          "alert_data" => %{"stop_ids" => ["place-pktrm"]}
        })

        render_async(view)

        {:ok, document} = view |> render_async() |> Floki.parse_document()
        refute document_has_element?(document, "option[value=\"Blue\"][selected=\"selected\"]")
        assert document_has_element?(document, "option[value=\"Red\"][selected=\"selected\"]")
      end
    end

    @tag :logged_in_user
    test "route options are never duplicated", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           # Simulate two different stops on the same route
           by_type: fn _ -> [@route, @route_two] end,
           by_stop: fn _, _ -> [@route] end
         ]},
        {StopsRepo, [],
         [
           by_route_type: fn _, _ -> [@stop, @stop_two] end,
           by_route: fn _routes, _direction, _opts -> [@stop, @stop_two] end,
           all: fn ["filter[id]": "place-aqucl"], _opts -> [@stop, @stop_two] end
         ]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/mono/new")
        get_to_submission_page_refactor(view, "Bus", "Multi-route detour")
        render_async(view)

        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "stop_ids"],
          "alert_data" => %{"stop_ids" => ["place-aqucl", "place-pktrm"]}
        })

        # Make sure it does not say "Blue Line and Blue Line are detoured"
        assert render(view) =~ ~s(Blue Line is detoured, skipping Aquarium and Park Street.)
      end
    end
  end
end
