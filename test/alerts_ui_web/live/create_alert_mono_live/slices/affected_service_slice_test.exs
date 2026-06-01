defmodule AlertsUIWeb.CreateAlertMonoLive.Slices.AffectedServiceSliceTest do
  use ExUnit.Case, async: false
  use AlertsUIWeb.ConnCase

  import AlertsUI.Support.Factory
  import Mock
  import Phoenix.LiveViewTest
  import Test.Support.Helpers

  alias AlertsUI.Alerts
  alias AlertsUI.Models.EnhancedSchedule
  alias AlertsUIWeb.CreateAlertMonoLive.AlertData
  alias AlertsUIWeb.CreateAlertMonoLive.Slice
  alias AlertsUIWeb.CreateAlertMonoLive.Slices.AffectedServiceSlice
  alias MBTAV3API.RoutePatterns.Repo, as: RoutePatternsRepo
  alias MBTAV3API.Routes.Repo, as: RoutesRepo
  alias MBTAV3API.Routes.Route
  alias MBTAV3API.Schedules.Repo, as: SchedulesRepo
  alias MBTAV3API.Schedules.Trip
  alias MBTAV3API.Stops.Repo, as: StopsRepo
  alias MBTAV3API.Stops.Stop

  # Past departure time — kept for Slice.transform/4 unit tests only
  @schedule %EnhancedSchedule{
    route: %Route{id: "CR-Worcester", type: 2, name: "Framingham/Worcester Line"},
    trip: %Trip{id: "trip-595", name: "595", direction_id: 0},
    stop: %Stop{id: "place-sstat", name: "South Station"},
    arrival_time: nil,
    departure_time: ~U[2024-06-01 14:00:00Z]
  }

  # Far-future times survive filter_out_old_trips; departure_time must be non-nil for sort
  @schedule_future %EnhancedSchedule{
    route: %Route{id: "CR-Worcester", type: 2, name: "Framingham/Worcester Line"},
    trip: %Trip{id: "trip-595", name: "595", direction_id: 0},
    stop: %Stop{id: "place-sstat", name: "South Station"},
    arrival_time: ~U[2099-01-01 12:00:00Z],
    departure_time: ~U[2099-01-01 11:00:00Z]
  }

  @schedule_3 %EnhancedSchedule{
    route: %Route{id: "CR-Worcester", type: 2, name: "Framingham/Worcester Line"},
    trip: %Trip{id: "trip-596", name: "596", direction_id: 0},
    stop: %Stop{id: "place-sstat", name: "South Station"},
    arrival_time: ~U[2099-01-01 13:00:00Z],
    departure_time: ~U[2099-01-01 12:00:00Z]
  }

  defp base_changeset(attrs) do
    Ecto.Changeset.cast(
      %AlertData{},
      Map.merge(%{route_type: 2, direction: "0", trip_ids: []}, attrs),
      [:route_type, :direction, :trip_ids, :trip_information_by_id]
    )
  end

  defp socket_with_loaded_schedules(schedules) do
    %{
      assigns: %{
        selections: %AffectedServiceSlice.Selections{available_schedules: schedules}
      }
    }
  end

  defp socket_with_loading_selections do
    %{assigns: %{selections: %AffectedServiceSlice.Selections{loading: true}}}
  end

  @route %Route{
    direction_names: %{0 => "Westbound", 1 => "Eastbound"},
    sort_order: 3,
    id: "CR-Worcester",
    type: 2,
    name: "Framingham/Worcester Line"
  }

  @route_2 %Route{
    direction_names: %{0 => "Westbound", 1 => "Eastbound"},
    sort_order: 4,
    id: "CR-Fairmount",
    type: 2,
    name: "Fairmount Line"
  }

  @bus_route %Route{
    direction_names: %{1 => "Inbound", 0 => "Outbound"},
    sort_order: 3,
    id: "746",
    type: 3,
    name: "SLW"
  }

  @ferry_route %Route{
    direction_names: %{0 => "Outbound", 1 => "Inbound"},
    sort_order: 1,
    id: "Boat-F4",
    type: 4,
    name: "Charlestown Ferry"
  }

  @subway_route %Route{
    direction_names: %{0 => "Southbound", 1 => "Northbound"},
    sort_order: 1,
    id: "Red",
    type: 1,
    name: "Red Line"
  }

  @stop %Stop{id: "place-sstat", name: "South Station"}
  @stop_2 %Stop{id: "place-crtst", name: "Courthouse"}
  @bus_stop %Stop{id: "place-wtcst", name: "World Trade Center"}
  @subway_stop %Stop{id: "place-cntsq", name: "Central"}

  @todays_date DateTime.utc_now()
               |> DateTime.shift_zone!("America/New_York")
               |> DateTime.to_date()

  describe "integration" do
    @tag :logged_in_user
    test "renders for commuter rail delay", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _ -> [@route] end,
           get: fn _, _ -> @route end
         ]},
        {StopsRepo, [], [by_route: fn _, _, _ -> [@stop] end]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/mono/new")
        get_to_submission_page_refactor(view, "Commuter Rail", "Delay")
        render_async(view)
        assert render(view) =~ ~s(id="service_view")
      end
    end

    @tag :logged_in_user
    test "green line renders stop options", %{conn: conn} do
      green_b = %Route{
        id: "Green-B",
        type: 1,
        name: "Green Line B",
        direction_names: %{0 => "Westbound", 1 => "Eastbound"}
      }

      green_line = %Route{
        id: "Green",
        type: 0,
        name: "Green Line",
        direction_names: %{0 => "Westbound", 1 => "Eastbound"}
      }

      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _ -> [green_b] end,
           get: fn _, _ -> green_b end,
           green_line: fn -> green_line end
         ]},
        {StopsRepo, [],
         [
           by_route: fn _, _, _ ->
             [%Stop{id: "stop_1", name: "Stop 1"}, %Stop{id: "stop_2", name: "Stop 2"}]
           end
         ]},
        {SchedulesRepo, [], [by_route_ids: fn _, _ -> [] end]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/mono/new")
        get_to_submission_page_refactor(view, "Subway", "Delay")
        render_async(view)

        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "route_ids"],
          "alert_data" => %{"route_ids" => ["Green-B"]}
        })

        assert render_async(view) =~ ~r/Stop 1.*Stop 2/s
      end
    end

    @tag :logged_in_user
    test "direction options are populated once a route is chosen", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _ -> [@route] end,
           get: fn _, _ -> @route end
         ]},
        {StopsRepo, [], [by_route: fn _, _, _ -> [@stop] end]},
        {SchedulesRepo, [], [by_route_ids: fn _, _ -> [] end]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/mono/new")
        get_to_submission_page_refactor(view, "Commuter Rail", "Delay")
        render_async(view)

        # Before route selection, direction options should not be populated
        refute render(view) =~ "Eastbound"

        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "route_ids"],
          "alert_data" => %{"route_ids" => ["CR-Worcester"]}
        })

        render_async(view)

        assert render(view) =~ "Eastbound"
      end
    end

    @tag :logged_in_user
    test "trip select is shown for commuter rail", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [], [by_type: fn _ -> [@route] end]},
        {StopsRepo, [], [by_route: fn _, _, _ -> [@stop] end]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/mono/new")
        get_to_submission_page_refactor(view, "Commuter Rail", "Delay")
        render_async(view)

        assert has_element?(view, "select#alert_data_trip_ids")
      end
    end

    @tag :logged_in_user
    test "trip select is shown for ferry", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _ -> [@ferry_route] end,
           by_type: fn _, _ -> [@ferry_route] end
         ]},
        {StopsRepo, [], [by_route: fn _, _, _ -> [@stop] end]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/mono/new")
        get_to_submission_page_refactor(view, "Ferry", "Delay")
        render_async(view)

        assert has_element?(view, "select#alert_data_trip_ids")
      end
    end

    @tag :logged_in_user
    test "trip select is not shown for subway", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [], [by_type: fn _ -> [@subway_route] end]},
        {StopsRepo, [], [by_route: fn _, _, _ -> [@stop] end]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/mono/new")
        get_to_submission_page_refactor(view, "Subway", "Delay")
        render_async(view)

        refute has_element?(view, "select#alert_data_trip_ids")
      end
    end

    @tag :logged_in_user
    test "trip select is not shown for bus", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [], [by_type: fn _ -> [@bus_route] end]},
        {StopsRepo, [], [by_route: fn _, _, _ -> [@stop] end]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/mono/new")
        get_to_submission_page_refactor(view, "Bus", "Delay")
        render_async(view)

        refute has_element?(view, "select#alert_data_trip_ids")
      end
    end

    @tag :logged_in_user
    test "trip options are populated when route and direction are selected", %{conn: conn} do
      today = @todays_date |> Date.to_string()
      # Use a future arrival_time so filter_out_old_trips keeps the schedule
      future = DateTime.add(DateTime.utc_now(), 7200)
      schedule = %{@schedule | arrival_time: future}

      with_mocks([
        {RoutesRepo, [], [by_type: fn _ -> [@route] end]},
        {StopsRepo, [], [by_route: fn _, _, _ -> [@stop] end]},
        {SchedulesRepo, [],
         [
           by_route_ids: fn
             ["CR-Worcester"], _ -> [schedule, schedule]
             _, _ -> []
           end,
           end_of_rating: fn -> Date.add(@todays_date, 7) end
         ]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/mono/new")
        get_to_submission_page_refactor(view, "Commuter Rail", "Delay")
        render_async(view)

        # Select route and direction
        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "route_ids"],
          "alert_data" => %{"route_ids" => ["CR-Worcester"]}
        })

        render_async(view)

        view
        |> element("form")
        |> render_change(%{
          "alert_data" => %{
            "route_ids" => ["CR-Worcester"],
            "direction" => "0",
            "modal_date" => today
          }
        })

        render_async(view)

        assert render(view) =~ @schedule.trip.name
      end
    end

    @tag :logged_in_user
    test "filter title updates to all future trips when no date selected", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _ -> [@route] end,
           get: fn _, _ -> @route end
         ]},
        {SchedulesRepo, [],
         [
           by_route_ids: fn _, _ -> [@schedule_future, @schedule_future] end,
           end_of_rating: fn -> Date.add(@todays_date, 7) end
         ]},
        {StopsRepo, [], [by_route: fn _, _, _ -> [@stop] end]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/mono/new")
        get_to_submission_page_refactor(view, "Commuter Rail", "Delay")
        render_async(view)

        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "route_ids"],
          "alert_data" => %{"route_ids" => ["CR-Worcester"]}
        })

        render_async(view)

        # Set modal_date to "default", which maps to "All future trips"
        view
        |> element("form")
        |> render_change(%{
          "alert_data" => %{"modal_date" => "default", "route_ids" => ["CR-Worcester"]}
        })

        render_click(view, "accept_filter")
        render_async(view)

        assert render(view) =~ "Filter: All future trips"
      end
    end

    @tag :logged_in_user
    test "schedule list updates when a different date is selected", %{conn: conn} do
      today = @todays_date |> Date.to_string()
      tomorrow = @todays_date |> Date.add(1) |> Date.to_string()

      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _ -> [@route] end,
           get: fn _, _ -> @route end
         ]},
        {SchedulesRepo, [],
         [
           by_route_ids: fn
             ["CR-Worcester"], opts ->
               case Keyword.get(opts, :date) do
                 ^today -> [@schedule_future, @schedule_future]
                 ^tomorrow -> [@schedule_3, @schedule_3]
                 _ -> []
               end

             _, _ ->
               []
           end,
           end_of_rating: fn -> Date.add(@todays_date, 7) end
         ]},
        {StopsRepo, [], [by_route: fn _, _, _ -> [@stop] end]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/mono/new")
        get_to_submission_page_refactor(view, "Commuter Rail", "Delay")
        render_async(view)

        view
        |> element("form")
        |> render_change(%{
          "alert_data" => %{"route_ids" => ["CR-Worcester"], "modal_date" => today}
        })

        render_async(view)

        assert render(view) =~ @schedule_future.trip.name
        refute render(view) =~ @schedule_3.trip.name

        view
        |> element("form")
        |> render_change(%{
          "alert_data" => %{"modal_date" => tomorrow, "route_ids" => ["CR-Worcester"]}
        })

        render_click(view, "accept_filter")
        render_async(view)

        assert render(view) =~ @schedule_3.trip.name
        refute render(view) =~ @schedule_future.trip.name
      end
    end

    @tag :logged_in_user
    test "filter title updates when a different date is selected", %{conn: conn} do
      today = @todays_date |> Date.to_string()
      today_day_name = Calendar.strftime(@todays_date, "%a %b %0d")
      tomorrow = @todays_date |> Date.add(1) |> Date.to_string()
      tomorrow_day_name = Calendar.strftime(Date.add(@todays_date, 1), "%a %b %0d")

      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _ -> [@route] end,
           get: fn _, _ -> @route end
         ]},
        {SchedulesRepo, [],
         [
           by_route_ids: fn _, _ -> [@schedule_future, @schedule_future] end,
           end_of_rating: fn -> Date.add(@todays_date, 7) end
         ]},
        {StopsRepo, [], [by_route: fn _, _, _ -> [@stop] end]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/mono/new")
        get_to_submission_page_refactor(view, "Commuter Rail", "Delay")
        render_async(view)

        view
        |> element("form")
        |> render_change(%{
          "alert_data" => %{"route_ids" => ["CR-Worcester"], "modal_date" => today}
        })

        render_async(view)

        assert render(view) =~ ~s(Filter: #{today_day_name})
        refute render(view) =~ ~s(Filter: #{tomorrow_day_name})

        view
        |> element("form")
        |> render_change(%{
          "alert_data" => %{"modal_date" => tomorrow, "route_ids" => ["CR-Worcester"]}
        })

        render_click(view, "accept_filter")
        render_async(view)

        refute render(view) =~ ~s(Filter: #{today_day_name})
        assert render(view) =~ ~s(Filter: #{tomorrow_day_name})

        view
        |> element("form")
        |> render_change(%{
          "alert_data" => %{"modal_date" => today, "route_ids" => ["CR-Worcester"]}
        })

        render_click(view, "accept_filter")
        render_async(view)

        assert render(view) =~ ~s(Filter: #{today_day_name})
        refute render(view) =~ ~s(Filter: #{tomorrow_day_name})
      end
    end

    @tag :logged_in_user
    test "clear date filter resets to today", %{conn: conn} do
      today = @todays_date |> Date.to_string()
      today_day_name = Calendar.strftime(@todays_date, "%a %b %0d")
      tomorrow = @todays_date |> Date.add(1) |> Date.to_string()

      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _ -> [@route] end,
           get: fn _, _ -> @route end
         ]},
        {SchedulesRepo, [],
         [
           by_route_ids: fn
             ["CR-Worcester"], opts ->
               case Keyword.get(opts, :date) do
                 ^today -> [@schedule_future, @schedule_future]
                 ^tomorrow -> [@schedule_3, @schedule_3]
                 _ -> []
               end

             _, _ ->
               []
           end,
           end_of_rating: fn -> Date.add(@todays_date, 7) end
         ]},
        {StopsRepo, [], [by_route: fn _, _, _ -> [@stop] end]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/mono/new")
        get_to_submission_page_refactor(view, "Commuter Rail", "Delay")
        render_async(view)

        # Select route + set tomorrow's date
        view
        |> element("form")
        |> render_change(%{
          "alert_data" => %{"modal_date" => tomorrow, "route_ids" => ["CR-Worcester"]}
        })

        render_click(view, "accept_filter")
        render_async(view)

        # Clear the filter
        render_click(view, "clear_filter")
        render_async(view)

        # Should show today's schedules, not tomorrow's
        assert render(view) =~ @schedule_future.trip.name
        refute render(view) =~ @schedule_3.trip.name
        # Filter title back to today
        assert render(view) =~ ~s(Filter: #{today_day_name})
      end
    end

    @tag :logged_in_user
    test "date filter button is disabled until route is selected", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _ -> [@ferry_route] end,
           by_type: fn _, _ -> [@ferry_route] end,
           get: fn _, _ -> @ferry_route end
         ]},
        {SchedulesRepo, [], [by_route_ids: fn _, _ -> [] end]},
        {StopsRepo, [], [by_route: fn _, _, _ -> [@stop] end]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/mono/new")
        get_to_submission_page_refactor(view, "Ferry", "Delay")
        render_async(view)

        assert render_async(view) =~ ~s(id="dates-filter-modal_button" disabled="disabled")

        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "route_ids"],
          "alert_data" => %{"route_ids" => [@ferry_route.id]}
        })

        refute render_async(view) =~ ~s(id="dates-filter-modal_button" disabled="disabled")
      end
    end

    @tag :logged_in_user
    test "stop select is disabled until route is selected", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _ -> [@ferry_route] end,
           by_type: fn _, _ -> [@ferry_route] end,
           get: fn _, _ -> @ferry_route end
         ]},
        {SchedulesRepo, [], [by_route_ids: fn _, _ -> [] end]},
        {StopsRepo, [], [by_route: fn _, _, _ -> [@stop] end]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/mono/new")
        get_to_submission_page_refactor(view, "Ferry", "Delay")
        render_async(view)

        refute render_async(view) =~ "All Stops"

        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "route_ids"],
          "alert_data" => %{"route_ids" => [@ferry_route.id]}
        })

        assert render_async(view) =~ "All Stops"
      end
    end

    @tag :logged_in_user
    test "stop select enables when one route is selected", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _ -> [@bus_route] end,
           get: fn _, _ -> @bus_route end
         ]},
        {StopsRepo, [], [by_route: fn _, _, _ -> [@stop] end]},
        {SchedulesRepo, [], [by_route_ids: fn _, _ -> [] end]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/mono/new")
        get_to_submission_page_refactor(view, "Bus", "Delay")
        render_async(view)

        assert render(view) =~ ~s(id="alert_data_stop_names_and_ids" disabled="disabled")

        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "route_ids"],
          "alert_data" => %{"route_ids" => [@bus_route.id]}
        })

        render_async(view)

        refute render(view) =~ ~s(id="alert_data_stop_names_and_ids" disabled="disabled")
      end
    end

    @tag :logged_in_user
    test "stop select stays enabled when switching between single routes", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _ -> [@route, @route_2] end,
           by_type: fn _, _ -> [@route, @route_2] end,
           get: fn _, _ -> @route end
         ]},
        {SchedulesRepo, [], [by_route_ids: fn _, _ -> [] end]},
        {StopsRepo, [], [by_route: fn _, _, _ -> [@stop] end]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/mono/new")
        get_to_submission_page_refactor(view, "Ferry", "Delay")
        render_async(view)

        assert render_async(view) =~
                 ~s(id="alert_data_stop_names_and_ids" disabled="disabled")

        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "route_ids"],
          "alert_data" => %{"route_ids" => [@route.id]}
        })

        render_async(view)
        refute render(view) =~ ~s(id="alert_data_stop_names_and_ids" disabled="disabled")
        assert render_async(view) =~ "All Stops"

        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "route_ids"],
          "alert_data" => %{"route_ids" => [@route_2.id]}
        })

        render_async(view)
        refute render(view) =~ ~s(id="alert_data_stop_names_and_ids" disabled="disabled")
      end
    end

    @tag :logged_in_user
    test "bus stop names include direction suffix and are ordered outbound then inbound",
         %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _ -> [@bus_route] end,
           get: fn _, _ -> @bus_route end
         ]},
        {StopsRepo, [],
         [
           by_route: fn
             _, 0, _ -> [@stop, @stop_2]
             _, 1, _ -> [@stop_2, @stop]
           end
         ]},
        {SchedulesRepo, [], [by_route_ids: fn _, _ -> [] end]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/mono/new")
        get_to_submission_page_refactor(view, "Bus", "Delay")
        render_async(view)

        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "route_ids"],
          "alert_data" => %{"route_ids" => [@bus_route.id]}
        })

        assert render_async(view) =~
                 ~r/South Station \(outbound\).*Courthouse \(outbound\).*Courthouse \(inbound\).*South Station \(inbound\)/s
      end
    end

    @tag :logged_in_user
    test "stops are preselected when duplicating an alert with existing stop selections",
         %{conn: conn} do
      alert_params =
        build(:alert_map, %{
          alert_id: "test-dup-stops",
          effect: :OTHER_EFFECT,
          effect_detail: "DELAY",
          primary_service_type: "3",
          informed_entity: [
            %{route_type: 3, route_id: @bus_route.id, stop_id: @stop_2.id, direction_id: 0}
          ],
          original_route_selections: ["SLW|746"],
          original_stop_selections: ["Courthouse (outbound)|place-crtst"]
        })

      {:ok, _} = Alerts.create_or_update_alert(alert_params, build(:user))

      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _ -> [@bus_route] end,
           get: fn _ -> @bus_route end,
           get: fn _, _ -> @bus_route end,
           all: fn _ -> [@bus_route] end
         ]},
        {StopsRepo, [],
         [
           by_route: fn _, _, _ -> [@stop, @stop_2] end,
           get_parent: fn _ -> nil end
         ]},
        {SchedulesRepo, [], [by_route_ids: fn _, _ -> [] end]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/mono/duplicate/test-dup-stops")
        render_async(view)

        {:ok, document} = view |> render() |> Floki.parse_document()

        assert document_has_element?(
                 document,
                 "option[value=\"Courthouse (outbound)|place-crtst\"][selected=\"selected\"]"
               )
      end
    end

    @tag :logged_in_user
    test "stop select is disabled when multiple routes are selected", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _ -> [@ferry_route] end,
           by_type: fn _, _ -> [@ferry_route] end,
           get: fn _, _ -> @ferry_route end
         ]},
        {SchedulesRepo, [], [by_route_ids: fn _, _ -> [] end]},
        {StopsRepo, [], [by_route: fn _, _, _ -> [@stop] end]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/mono/new")
        get_to_submission_page_refactor(view, "Ferry", "Delay")
        render_async(view)

        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "route_ids"],
          "alert_data" => %{"route_ids" => [@ferry_route.id, "Boat-F1"]}
        })

        render_async(view)

        assert render(view) =~ ~s(id="alert_data_stop_names_and_ids" disabled="disabled")
      end
    end

    @tag :logged_in_user
    test "route search filter results", %{conn: conn} do
      today = @todays_date |> Date.to_string()

      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _ -> [@route] end,
           get: fn _, _ -> @route end
         ]},
        {SchedulesRepo, [],
         [
           by_route_ids: fn _, _ -> [@schedule_future, @schedule_future] end,
           end_of_rating: fn -> Date.add(@todays_date, 7) end
         ]},
        {StopsRepo, [], [by_route: fn _, _, _ -> [@stop] end]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/mono/new")
        get_to_submission_page_refactor(view, "Commuter Rail", "Delay")
        render_async(view)

        assert view
               |> element("#service_view")
               |> render_async =~ ~s(value=\"#{@route.id}\")

        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "route_search_term"],
          "alert_data" => %{"route_search_term" => "xxxxxx"}
        })

        refute view
               |> element("#service_view")
               |> render_async =~ ~s(value=\"#{@route.id}\")
      end
    end

    @tag :logged_in_user
    test "trip and stop search filter results", %{conn: conn} do
      today = @todays_date |> Date.to_string()

      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _ -> [@route] end,
           get: fn _, _ -> @route end
         ]},
        {SchedulesRepo, [],
         [
           by_route_ids: fn _, _ -> [@schedule_future, @schedule_future] end,
           end_of_rating: fn -> Date.add(@todays_date, 7) end
         ]},
        {StopsRepo, [], [by_route: fn _, _, _ -> [@stop] end]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/mono/new")
        get_to_submission_page_refactor(view, "Commuter Rail", "Delay")
        render_async(view)

        view
        |> element("form")
        |> render_change(%{
          "alert_data" => %{
            "route_ids" => ["CR-Worcester"],
            "modal_date" => today
          }
        })

        render_async(view)

        {:ok, document} = view |> render_async() |> Floki.parse_document()
        assert document_has_element?(document, "option[value=\"trip-595\"]")
        assert document_has_element?(document, "option[value=\"South Station|place-sstat\"]")

        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "trip_search_term"],
          "alert_data" => %{"trip_search_term" => "xxxxxx"}
        })

        render_async(view)

        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "stop_search_term"],
          "alert_data" => %{"stop_search_term" => "xxxxxx"}
        })

        render_async(view)

        {:ok, document} = view |> render_async() |> Floki.parse_document()
        refute document_has_element?(document, "option[value=\"trip-595\"]")
        refute document_has_element?(document, "option[value=\"South Station|place-sstat\"]")
      end
    end

    @tag :logged_in_user
    test "trip and stop search can be cleared", %{conn: conn} do
      today = @todays_date |> Date.to_string()

      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _ -> [@route] end,
           get: fn _, _ -> @route end
         ]},
        {SchedulesRepo, [],
         [
           by_route_ids: fn _, _ -> [@schedule_future, @schedule_future] end,
           end_of_rating: fn -> Date.add(@todays_date, 7) end
         ]},
        {StopsRepo, [], [by_route: fn _, _, _ -> [@stop] end]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/mono/new")
        get_to_submission_page_refactor(view, "Commuter Rail", "Delay")
        render_async(view)

        view
        |> element("form")
        |> render_change(%{
          "alert_data" => %{
            "route_ids" => ["CR-Worcester"],
            "modal_date" => today
          }
        })

        render_async(view)

        {:ok, document} = view |> render_async() |> Floki.parse_document()
        assert document_has_element?(document, "option[value=\"trip-595\"]")
        assert document_has_element?(document, "option[value=\"South Station|place-sstat\"]")

        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "trip_search_term"],
          "alert_data" => %{"trip_search_term" => "xxxxxx"}
        })

        render_async(view)

        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "stop_search_term"],
          "alert_data" => %{"stop_search_term" => "xxxxxx"}
        })

        render_async(view)

        {:ok, document} = view |> render_async() |> Floki.parse_document()
        refute document_has_element?(document, "option[value=\"trip-595\"]")
        refute document_has_element?(document, "option[value=\"South Station|place-sstat\"]")

        # Clear trip search
        render_click(view, "reset_search_filter", %{"name" => "alert_data[trip_search_term]"})
        render_async(view)

        {:ok, document} = view |> render_async() |> Floki.parse_document()
        assert document_has_element?(document, "option[value=\"trip-595\"]")
        refute document_has_element?(document, "option[value=\"South Station|place-sstat\"]")

        # Clear stop search
        render_click(view, "reset_search_filter", %{"name" => "alert_data[stop_search_term]"})
        render_async(view)

        {:ok, document} = view |> render_async() |> Floki.parse_document()
        assert document_has_element?(document, "option[value=\"South Station|place-sstat\"]")
      end
    end

    @tag :logged_in_user
    test "shows field validation error on review attempt with no route selected", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [], [by_type: fn _ -> [@bus_route] end]},
        {StopsRepo, [], [by_route: fn _, _, _ -> [@stop] end]},
        {SchedulesRepo, [], [by_route_ids: fn _, _ -> [] end]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/mono/new")
        get_to_submission_page_refactor(view, "Bus", "Detour")
        render_async(view)

        refute render_async(view) =~ "text-text-error"

        open_review_modal(view)

        assert render_async(view) =~ "text-text-error"
      end
    end

    @tag :logged_in_user
    test "renders correctly while editing an existing commuter rail alert", %{conn: conn} do
      alert_params =
        build(:alert_map, %{
          alert_id: "test-cr-edit",
          effect: :OTHER_EFFECT,
          effect_detail: "DELAY",
          primary_service_type: "2",
          informed_entity: [
            %{route_type: 2, route_id: "CR-Worcester", direction_id: 0}
          ],
          original_route_selections: ["Framingham/Worcester Line|CR-Worcester"]
        })

      {:ok, _} = Alerts.create_or_update_alert(alert_params, build(:user))

      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _ -> [@route] end,
           get: fn _ -> @route end,
           get: fn _, _ -> @route end,
           all: fn _ -> [@route] end
         ]},
        {StopsRepo, [], [by_route: fn _, _, _ -> [@stop] end, get_parent: fn _ -> nil end]},
        {SchedulesRepo, [], [by_route_ids: fn _, _ -> [] end]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/mono/edit/test-cr-edit")
        render_async(view)

        {:ok, document} = view |> render() |> Floki.parse_document()

        assert document_has_element?(
                 document,
                 "option[value=\"CR-Worcester\"][selected=\"selected\"]"
               )
      end
    end

    @tag :logged_in_user
    test "modal search works", %{conn: conn} do
      tomorrow_day_name = Calendar.strftime(Date.add(@todays_date, 1), "%a %b %0d")

      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _ -> [@route] end,
           get: fn _, _ -> @route end
         ]},
        {SchedulesRepo, [],
         [
           by_route_ids: fn ["CR-Worcester"], _ -> [@schedule_future, @schedule_future] end,
           end_of_rating: fn -> Date.add(@todays_date, 1) end
         ]},
        {StopsRepo, [], [by_route: fn _, _, _ -> [@stop] end]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/mono/new")
        get_to_submission_page_refactor(view, "Commuter Rail", "Delay")
        render_async(view)

        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "route_ids"],
          "alert_data" => %{"route_ids" => ["CR-Worcester"]}
        })

        render_async(view)

        assert view
               |> element("select#alert_data_modal_date")
               |> render() =~ "#{tomorrow_day_name}"

        view
        |> element("form")
        |> render_change(%{
          "alert_data" => %{"modal_date_search_term" => "q", "route_ids" => ["CR-Worcester"]}
        })

        render_async(view)

        refute view
               |> element("select#alert_data_modal_date")
               |> render() =~ "#{tomorrow_day_name}"
      end
    end

    @tag :logged_in_user
    test "stop element not spuriously disabled if second is selected", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _ -> [@route, @route_2] end,
           by_type: fn _, _ -> [@route, @route_2] end,
           get: fn _, _ -> @route end
         ]},
        {SchedulesRepo, [], [by_route_ids: fn _, _ -> [] end]},
        {StopsRepo, [], [by_route: fn _, _, _ -> [@stop] end]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/mono/new")
        get_to_submission_page_refactor(view, "Ferry", "Delay")
        render_async(view)

        assert render_async(view) =~
                 ~s(id="alert_data_stop_names_and_ids" disabled="disabled")

        refute render_async(view) =~ "All Stops"

        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "route_ids"],
          "alert_data" => %{"route_ids" => [@route.id]}
        })

        render_async(view)

        refute render_async(view) =~
                 ~s(id="alert_data_stop_names_and_ids" disabled="disabled")

        assert render_async(view) =~ "All Stops"

        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "route_ids"],
          "alert_data" => %{"route_ids" => [@route_2.id]}
        })

        render_async(view)

        refute render_async(view) =~
                 ~s(id="alert_data_stop_names_and_ids" disabled="disabled")
      end
    end
  end

  describe "end-to-end" do
    @tag :logged_in_user
    test "flash error when route is deselected before submitting", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _ -> [@bus_route] end,
           get: fn _, _ -> @bus_route end
         ]},
        {StopsRepo, [], [by_route: fn _, _, _ -> [@stop] end]},
        {SchedulesRepo, [], [by_route_ids: fn _, _ -> [] end]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/mono/new")
        get_to_submission_page_refactor(view, "Bus", "Delay")
        render_async(view)

        # Attempt review without selecting any route
        open_review_modal(view)

        assert render_async(view) =~ "text-text-error"
      end
    end

    @tag :logged_in_user
    test "allows CR route to be selected then deselected without error", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _ -> [@route] end,
           get: fn _, _ -> @route end
         ]},
        {SchedulesRepo, [], [by_route_ids: fn _, _ -> [] end]},
        {StopsRepo, [], [by_route: fn _, _, _ -> [@stop] end]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/mono/new")
        get_to_submission_page_refactor(view, "Commuter Rail", "Delay")
        render_async(view)

        # Select CR-Worcester
        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "route_ids"],
          "alert_data" => %{"route_ids" => ["CR-Worcester"]}
        })

        render_async(view)

        {:ok, document} = view |> render() |> Floki.parse_document()
        assert document_has_element?(document, "[value=\"CR-Worcester\"]")

        # Deselect
        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "route_ids"],
          "alert_data" => %{"route_ids" => []}
        })

        render_async(view)

        refute render(view) =~ ~s(value="CR-Worcester" selected="selected")
      end
    end

    @tag :logged_in_user
    test "selecting all trips and individual trips saves only individual trips on submit",
         %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _ -> [@route] end,
           get: fn _ -> @route end,
           get: fn _, _ -> @route end,
           by_stop: fn _, _ -> [@route] end
         ]},
        {SchedulesRepo, [],
         [
           by_route_ids: fn _, _ ->
             [@schedule_future, @schedule_future, @schedule_3, @schedule_3]
           end,
           end_of_rating: fn -> Date.add(@todays_date, 7) end
         ]},
        {StopsRepo, [],
         [
           by_route: fn _, _, _ -> [@stop] end,
           by_route_type: fn _ -> [@stop] end,
           all: fn _, _ -> [@stop] end
         ]},
        {RoutePatternsRepo, [],
         [
           by_route_id: fn _, _ -> [] end
         ]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/mono/new")
        get_to_submission_page_refactor(view, "Commuter Rail", "Delay")
        render_async(view)

        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "route_ids"],
          "alert_data" => %{"route_ids" => ["CR-Worcester"]}
        })

        render_async(view)

        # Select "All Trips" default + individual trips
        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "trip_ids"],
          "alert_data" => %{"trip_ids" => ["default", "trip-595", "trip-596"]}
        })

        render_async(view)

        open_review_modal(view)

        view
        |> element("#review-modal-container button", "Submit")
        |> render_click()

        flash = assert_redirect(view, "/")

        alert_id =
          flash["info"]
          |> String.replace("New alert #", "")
          |> String.replace(" created", "")

        new_alert = Alerts.get_by_alert_id(alert_id)
        trip_ids = new_alert.informed_entity |> Enum.map(& &1.trip.trip_id) |> Enum.sort()

        assert trip_ids == ["trip-595", "trip-596"]
      end
    end

    @tag :logged_in_user
    test "end-to-end editing updates stop selection in the database", %{conn: conn} do
      trip = build(:trip_descriptor, %{trip_id: "trip-595"})

      ie =
        build(:informed_entity, %{
          route_id: @route.id,
          route_type: @route.type,
          activities: [:BOARD],
          stop_id: @stop.id,
          trip: Map.from_struct(trip),
          direction_id: nil
        })

      alert_params =
        build(
          :alert_map,
          %{
            alert_id: "test-edit-stop",
            header_text: "example header text",
            informed_entity: [Map.from_struct(ie)],
            effect: :OTHER_EFFECT,
            effect_detail: "DELAY",
            original_route_selections: [@route.id],
            original_stop_selections: ["#{@stop.name}|#{@stop.id}"],
            reminder_times: [],
            severity: 7,
            cause_detail: "unknown",
            user: build(:user),
            primary_service_type: Integer.to_string(@route.type)
          }
        )

      {:ok, _} = Alerts.create_or_update_alert(alert_params, build(:user))

      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _ -> [@route] end,
           get: fn _ -> @route end,
           get: fn _, _ -> @route end,
           all: fn _ -> [@route] end,
           by_stop: fn _, _ -> [@route] end
         ]},
        {SchedulesRepo, [],
         [
           by_route_ids: fn _, _ -> [@schedule_future, @schedule_future] end,
           end_of_rating: fn -> Date.add(@todays_date, 7) end,
           trip: fn "trip-595" -> %Trip{id: "trip-595", name: "595", direction_id: 0} end
         ]},
        {StopsRepo, [],
         [
           by_route: fn _, _, _ -> [@stop, @stop_2] end,
           by_route_type: fn _ -> [@stop, @stop_2] end,
           all: fn _, _ -> [@stop] end,
           get_parent: fn
             "place-sstat" -> @stop
             "place-crtst" -> @stop_2
           end,
           get: fn
             "place-sstat" -> @stop
             "place-crtst" -> @stop_2
           end
         ]},
        {RoutePatternsRepo, [],
         [
           by_route_id: fn _, _ -> [] end,
           included_stops_by_route_id: fn "CR-Worcester", _ -> [@stop, @stop_2] end
         ]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/mono/edit/test-edit-stop")
        render_async(view)

        {:ok, document} = view |> render() |> Floki.parse_document()

        assert document_has_element?(
                 document,
                 "[value=\"CR-Worcester\"][selected=\"selected\"]"
               )

        assert document_has_element?(
                 document,
                 "[value=\"South Station|place-sstat\"][selected=\"selected\"]"
               )

        # Change stop selection to Courthouse
        view
        |> element("form")
        |> render_change(%{
          "alert_data" => %{
            "stop_names_and_ids" => ["Courthouse (outbound)|place-crtst"]
          }
        })

        open_review_modal(view)

        view
        |> element("#review-modal-container button", "Submit")
        |> render_click()

        :timer.sleep(50)
        alert = Alerts.get_by_alert_id("test-edit-stop")

        assert Enum.any?(alert.informed_entity, &(&1.stop_id == "place-crtst"))
      end
    end

    @tag :logged_in_user
    test "user can select all future trips and a specific trip with a distant start date",
         %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _ -> [@route] end,
           get: fn _ -> @route end,
           get: fn _, _ -> @route end,
           by_stop: fn _, _ -> [@route] end
         ]},
        {SchedulesRepo, [],
         [
           by_route_ids: fn _, _ ->
             [@schedule_future, @schedule_future, @schedule_3, @schedule_3]
           end,
           end_of_rating: fn -> Date.add(@todays_date, 7) end
         ]},
        {StopsRepo, [],
         [
           by_route: fn _, _, _ -> [@stop] end,
           by_route_type: fn _ -> [@stop] end
         ]},
        {RoutePatternsRepo, [],
         [
           by_route_id: fn _, _ -> [] end
         ]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/mono/new")
        get_to_submission_page_refactor(view, "Commuter Rail", "Cancellation")
        render_async(view)

        # Select route
        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "route_ids"],
          "alert_data" => %{"route_ids" => ["CR-Worcester"]}
        })

        render_async(view)

        # Select "All future trips" (empty modal_date = all trips)
        view
        |> element("form")
        |> render_change(%{
          "alert_data" => %{"modal_date" => "default", "route_ids" => ["CR-Worcester"]}
        })

        render_async(view)

        # Select individual trips
        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "trip_ids"],
          "alert_data" => %{"trip_ids" => ["trip-595", "trip-596"]}
        })

        render_async(view)

        # Set time range far in the future
        view
        |> element("form")
        |> render_change(%{
          "alert_data" => %{
            "active_period_start_specifier" => "custom",
            "active_period_end_specifier" => "custom"
          }
        })

        view
        |> element("form")
        |> render_change(%{
          "alert_data" => %{
            "active_period_start" => ~N[2045-03-28 03:00:00],
            "active_period_end" => ~N[2045-03-31 19:00:00]
          }
        })

        refute render(view) =~ ~s(Effect must start before)
      end
    end

    @tag :logged_in_user
    test "publishing a bus delay AFTER selecting and deselecting will put up a flash error for the missing route",
         %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _ -> [@bus_route] end,
           get: fn _, _ -> @bus_route end
         ]},
        {StopsRepo, [], [by_route: fn _, _, _ -> [@stop] end]},
        {SchedulesRepo, [], [by_route_ids: fn _, _ -> [] end]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/mono/new")

        get_to_submission_page_refactor(view, "Bus", "Delay")

        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "route_ids"],
          "alert_data" => %{"route_ids" => []}
        })

        open_review_modal(view)

        render_async(view)

        # Inline
        assert has_element?(view, "p.text-text-error", "You must select a route")

        # Flash
        assert view
               |> element("#flash")
               |> render() =~ "You must select a route"
      end
    end

    @tag :logged_in_user
    test "trip select makes 'All Trips' and individual trip selection mutually exclusive",
         %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           by_stop: fn _stop_id, _ -> [@route] end,
           by_type: fn _types -> [@route] end,
           get: fn _, _ -> @route end,
           get: fn _ -> @route end
         ]},
        {SchedulesRepo, [],
         [
           by_route_ids: fn _, _ ->
             [@schedule_future, @schedule_future, @schedule_3, @schedule_3]
           end,
           end_of_rating: fn -> Date.add(@todays_date, 7) end
         ]},
        {StopsRepo, [],
         [
           by_route_type: fn _route_type -> [@stop] end,
           by_route: fn _, _, _ -> [@stop] end,
           all: fn _, _ -> [@stop] end
         ]},
        {RoutePatternsRepo, [],
         [
           by_route_id: fn _, _ -> [] end
         ]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/mono/new")

        get_to_submission_page_refactor(view, "Commuter Rail", "Delay")

        render_async(view)

        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "route_ids"],
          "alert_data" => %{"route_ids" => ["CR-Worcester"]}
        })

        render_async(view)

        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "trip_ids"],
          "alert_data" => %{"trip_ids" => ["default", "trip-595", "trip-596"]}
        })

        render_async(view)

        open_review_modal(view)

        view
        |> element("#review-modal-container button", "Submit")
        |> render_click()

        flash = assert_redirect(view, "/")

        alert_id =
          flash["info"]
          |> String.replace("New alert #", "")
          |> String.replace(" created", "")

        new_alert = Alerts.get_by_alert_id(alert_id)

        assert [%{trip: %{trip_id: "trip-595"}}, %{trip: %{trip_id: "trip-596"}}] =
                 Map.get(new_alert, :informed_entity) |> Enum.sort_by(& &1.trip.trip_id)
      end
    end

    @tag :logged_in_user
    test "end-to-end editing", %{conn: conn} do
      trip = build(:trip_descriptor, %{trip_id: "trip-595"})

      ie =
        build(:informed_entity, %{
          route_id: @route.id,
          route_type: @route.type,
          activities: [:BOARD],
          stop_id: @stop.id,
          trip: Map.from_struct(trip),
          direction_id: nil
        })

      alert_params =
        build(
          :alert_map,
          %{
            alert_id: "test-e2e-editing",
            header_text: "example header text",
            informed_entity: [Map.from_struct(ie)],
            effect: :OTHER_EFFECT,
            effect_detail: "DELAY",
            original_route_selections: [@route.id],
            original_stop_selections: ["#{@stop.name}|#{@stop.id}"],
            reminder_times: [],
            severity: 7,
            cause_detail: "unknown",
            user: build(:user),
            primary_service_type: Integer.to_string(@route.type)
          }
        )

      {:ok, _} = Alerts.create_or_update_alert(alert_params, build(:user))

      with_mocks([
        {RoutesRepo, [],
         [
           by_stop: fn _stop_id, _ -> [@route] end,
           by_type: fn _types -> [@route] end,
           all: fn _opts -> [@route] end,
           get: fn _ -> @route end,
           get: fn _, _ -> @route end
         ]},
        {SchedulesRepo, [],
         [
           by_route_ids: fn _, _ -> [@schedule_future, @schedule_future] end,
           end_of_rating: fn -> Date.add(@todays_date, 7) end,
           trip: fn "trip-595" -> %Trip{id: "trip-595", name: "595", direction_id: 0} end
         ]},
        {StopsRepo, [],
         [
           by_route_type: fn _route_type -> [@stop, @stop_2] end,
           by_route: fn _, _, _ -> [@stop, @stop_2] end,
           all: fn
             ["filter[id]": "place-sstat"], _ -> [@stop]
             ["filter[id]": "place-crtst"], _ -> [@stop_2]
           end,
           get_parent: fn
             "place-sstat" -> @stop
             "place-crtst" -> @stop_2
           end,
           get: fn
             "place-sstat" -> @stop
             "place-crtst" -> @stop_2
           end
         ]},
        {RoutePatternsRepo, [],
         [
           by_route_id: fn _, _ -> [] end,
           included_stops_by_route_id: fn "CR-Worcester", _ -> [@stop, @stop_2] end
         ]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/mono/edit/test-e2e-editing")
        render_async(view)

        {:ok, document} =
          view
          |> render()
          |> Floki.parse_document()

        assert document_has_element?(
                 document,
                 "[value=\"CR-Worcester\"][selected=\"selected\"]"
               )

        assert document_has_element?(
                 document,
                 "[value=\"South Station|place-sstat\"][selected=\"selected\"]"
               )

        assert document_has_element?(
                 document,
                 "[value=\"trip-595\"][selected=\"selected\"]"
               )

        view
        |> element("form")
        |> render_change(%{
          "alert_data" => %{
            "stop_names_and_ids" => ["#{@stop_2.name}|#{@stop_2.id}"]
          }
        })

        open_review_modal(view)

        view
        |> element("#review-modal-container button", "Submit")
        |> render_click()

        :timer.sleep(50)
        alert = Alerts.get_by_alert_id("test-e2e-editing")

        assert [
                 %{
                   stop_id: "place-crtst",
                   route_id: "CR-Worcester",
                   trip: %{trip_id: "trip-595"}
                 }
               ] = Map.get(alert, :informed_entity)
      end
    end

    @tag :logged_in_user
    test "user can select 'All future trips', a trip, and then effect start far from now",
         %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           by_stop: fn _stop_id, _ -> [@route] end,
           by_type: fn _types -> [@route] end,
           get: fn _, _ -> @route end,
           get: fn _ -> @route end
         ]},
        {SchedulesRepo, [],
         [
           by_route_ids: fn _, _ ->
             [@schedule_future, @schedule_future, @schedule_3, @schedule_3]
           end,
           end_of_rating: fn -> Date.add(@todays_date, 7) end
         ]},
        {StopsRepo, [],
         [
           by_route_type: fn _route_type -> [@stop] end,
           by_route: fn _, _, _ -> [@stop] end
         ]},
        {RoutePatternsRepo, [],
         [
           by_route_id: fn _, _ -> [] end
         ]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/mono/new")

        get_to_submission_page_refactor(view, "Commuter Rail", "Cancellation")

        render_async(view)

        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "route_ids"],
          "alert_data" => %{"route_ids" => ["CR-Worcester"]}
        })

        render_async(view)

        view
        |> element("form")
        |> render_change(%{
          "alert_data" => %{"modal_date" => "default", "route_ids" => ["CR-Worcester"]}
        })

        render_async(view)

        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "trip_ids"],
          "alert_data" => %{"trip_ids" => ["trip-595", "trip-596"]}
        })

        render_async(view)

        view
        |> element("form")
        |> render_change(%{
          "alert_data" => %{
            "active_period_start_specifier" => "custom",
            "active_period_end_specifier" => "custom"
          }
        })

        view
        |> element("form")
        |> render_change(%{
          "alert_data" => %{
            "active_period_start" => ~N[2045-03-28 03:00:00],
            "active_period_end" => ~N[2045-03-31 19:00:00]
          }
        })

        refute render(view) =~ ~s(Effect must start before)
      end
    end
  end

  describe "filter_stops_by_direction" do
    @tag :logged_in_user
    test "directional bus stops are removed when direction is set to outbound", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _ -> [@bus_route] end,
           get: fn _ -> @bus_route end,
           get: fn _, _ -> @bus_route end,
           by_stop: fn _, _ -> [@bus_route] end
         ]},
        {StopsRepo, [],
         [
           by_route: fn _, _, _ -> [@bus_stop] end,
           by_route_type: fn _ -> [@bus_stop] end
         ]},
        {SchedulesRepo, [], [by_route_ids: fn _, _ -> [] end]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/mono/new")
        get_to_submission_page_refactor(view, "Bus", "Delay")
        render_async(view)

        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "route_ids"],
          "alert_data" => %{"route_ids" => [@bus_route.id]}
        })

        render_async(view)

        view
        |> element("form")
        |> render_change(%{
          "alert_data" => %{
            "stop_names_and_ids" => [
              "World Trade Center (outbound)|place-wtcst",
              "World Trade Center (inbound)|place-wtcst"
            ]
          }
        })

        view
        |> element("form")
        |> render_change(%{
          "alert_data" => %{"direction" => "0"}
        })

        open_review_modal(view)
        html = render_async(view)

        assert html =~ ~r/Stops:.*World Trade Center \(outbound\)/s
        refute html =~ ~r/Stops:.*World Trade Center \(inbound\)/s
      end
    end

    @tag :logged_in_user
    test "non-directional subway stops are not removed when direction is set", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _ -> [@subway_route] end,
           get: fn _ -> @subway_route end,
           get: fn _, _ -> @subway_route end,
           by_stop: fn _, _ -> [@subway_route] end
         ]},
        {StopsRepo, [],
         [
           by_route: fn _, _, _ -> [@subway_stop] end,
           by_route_type: fn _ -> [@subway_stop] end
         ]},
        {SchedulesRepo, [], [by_route_ids: fn _, _ -> [] end]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/mono/new")
        get_to_submission_page_refactor(view, "Subway", "Notice")
        render_async(view)

        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "route_ids"],
          "alert_data" => %{"route_ids" => [@subway_route.id]}
        })

        render_async(view)

        view
        |> element("form")
        |> render_change(%{
          "alert_data" => %{
            "stop_names_and_ids" => ["Central|place-cntsq"]
          }
        })

        view
        |> element("form")
        |> render_change(%{
          "alert_data" => %{"direction" => "0"}
        })

        open_review_modal(view)
        html = render_async(view)

        assert html =~ ~r/Stops:.*Central/s
      end
    end
  end

  describe "no-flicker: options preserved during async reload" do
    @tag :logged_in_user
    test "route options remain visible while a new async load is in progress", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [], [by_type: fn _ -> [@route] end]},
        {StopsRepo, [], [by_route: fn _, _, _ -> [@stop] end]},
        {SchedulesRepo, [], [by_route_ids: fn _, _ -> [] end]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/mono/new")
        get_to_submission_page_refactor(view, "Commuter Rail", "Delay")
        render_async(view)

        # Verify initial options are loaded
        assert render(view) =~ "CR-Worcester"

        # Trigger a new async load (direction change) — this should NOT clear options
        html_mid_load =
          view
          |> element("form")
          |> render_change(%{"alert_data" => %{"direction" => "0"}})

        # Route options must still be visible before the async task completes
        {:ok, document} = Floki.parse_document(html_mid_load)
        assert document_has_element?(document, "option[value=\"CR-Worcester\"]")
      end
    end
  end

  describe "Slice.transform/4 - trip_information_by_id" do
    test "builds trip_information_by_id when trips are selected and schedules are loaded" do
      changeset = base_changeset(%{trip_ids: ["trip-595"]})
      socket = socket_with_loaded_schedules([@schedule])

      result = Slice.transform(%AffectedServiceSlice{}, changeset, %{}, socket)
      trip_info = Ecto.Changeset.get_field(result, :trip_information_by_id)

      assert %{"trip-595" => entry} = trip_info
      assert entry.direction_id == 0
      assert entry.route_id == "CR-Worcester"
      assert is_binary(entry.trip_name)
    end

    test "produces empty map when no trip_ids are selected" do
      changeset = base_changeset(%{trip_ids: []})
      socket = socket_with_loaded_schedules([@schedule])

      result = Slice.transform(%AffectedServiceSlice{}, changeset, %{}, socket)
      trip_info = Ecto.Changeset.get_field(result, :trip_information_by_id)

      assert trip_info == %{}
    end

    test "produces empty map when selections are still loading" do
      changeset = base_changeset(%{trip_ids: ["trip-595"]})
      socket = socket_with_loading_selections()

      result = Slice.transform(%AffectedServiceSlice{}, changeset, %{}, socket)
      trip_info = Ecto.Changeset.get_field(result, :trip_information_by_id)

      assert trip_info in [nil, %{}]
    end
  end
end
