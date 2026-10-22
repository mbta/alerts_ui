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
  alias MBTAV3API.RoutePatterns.RoutePattern
  alias MBTAV3API.Routes.Repo, as: RoutesRepo
  alias MBTAV3API.Routes.Route
  alias MBTAV3API.Schedules.Repo, as: SchedulesRepo
  alias MBTAV3API.Schedules.Schedule
  alias MBTAV3API.Schedules.Trip
  alias MBTAV3API.Stops.Repo, as: StopsRepo
  alias MBTAV3API.Stops.Stop

  # Past departure time — kept for Slice.transform/4 unit tests only
  @schedule %EnhancedSchedule{
    route_id: "CR-Worcester",
    trip: %Trip{id: "trip-595", name: "595", direction_id: 0},
    stop: %Stop{id: "place-sstat", name: "South Station"},
    arrival_time: nil,
    departure_time: ~U[2024-06-01 14:00:00Z],
    added_route_ids: []
  }

  # Far-future times survive filter_out_old_trips; departure_time must be non-nil for sort
  @schedule_future %EnhancedSchedule{
    route_id: "CR-Worcester",
    trip: %Trip{id: "trip-595", name: "595", direction_id: 0},
    stop: %Stop{id: "place-sstat", name: "South Station"},
    arrival_time: ~U[2099-01-01 12:00:00Z],
    departure_time: ~U[2099-01-01 11:00:00Z],
    added_route_ids: []
  }

  @schedule_3 %EnhancedSchedule{
    route_id: "CR-Worcester",
    trip: %Trip{id: "trip-596", name: "596", direction_id: 0},
    stop: %Stop{id: "place-sstat", name: "South Station"},
    arrival_time: ~U[2099-01-01 13:00:00Z],
    departure_time: ~U[2099-01-01 12:00:00Z],
    added_route_ids: []
  }

  @boat_f1 %Route{
    direction_names: %{0 => "Outbound", 1 => "Inbound"},
    sort_order: 1,
    id: "Boat-F1",
    type: 4,
    name: "Hingham/Hull Ferry"
  }

  @boat_f2h %Route{
    direction_names: %{0 => "Outbound", 1 => "Inbound"},
    sort_order: 1,
    id: "Boat-F2H",
    type: 4,
    name: "Hingham Ferry"
  }

  @two_hours_from_now DateTime.utc_now()
                      |> DateTime.add(2, :hour)
                      |> DateTime.shift_zone!("America/New_York")

  @boat_f1_schedule_1 %Schedule{
    stop: %Stop{id: "Boat-Rowes", name: "Rowes Wharf"},
    departure_time: @two_hours_from_now,
    arrival_time: DateTime.add(@two_hours_from_now, 30, :minute),
    trip: %Trip{id: "Boat-F1-2030-Rowes-F1-A-PM-Weekday-Summer-26", name: "", direction_id: 0},
    route_id: "Boat-F1",
    added_route_ids: ["Boat-F2H"]
  }

  @boat_f1_schedule_2 %{
    @boat_f1_schedule_1
    | departure_time: DateTime.add(@boat_f1_schedule_1.departure_time, 2, :hour),
      arrival_time: DateTime.add(@boat_f1_schedule_1.arrival_time, 2, :hour)
  }

  @boat_f2h_schedule_1 %Schedule{
    stop: %Stop{id: "Boat-George", name: "Georges Island"},
    departure_time: @two_hours_from_now,
    arrival_time: DateTime.add(@two_hours_from_now, 30, :minute),
    trip: %Trip{
      id: "Boat-F2H-1440-Long-F2H-B-PM-Weekday-GeorgesIsland-Summer-26",
      name: "",
      direction_id: 0
    },
    route_id: "Boat-F2H",
    added_route_ids: []
  }

  @boat_f2h_schedule_2 %{
    @boat_f2h_schedule_1
    | departure_time: DateTime.add(@boat_f2h_schedule_1.departure_time, 2, :hour),
      arrival_time: DateTime.add(@boat_f2h_schedule_1.arrival_time, 2, :hour)
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

  @detour_bus_route %Route{
    direction_names: %{0 => "Outbound", 1 => "Inbound"},
    sort_order: 1,
    id: "1",
    type: 3,
    name: "1"
  }

  @detour_stop %Stop{
    id: "72",
    type: 3,
    name: "Mass Ave at Pearl St"
  }

  @connection_stop %Stop{
    id: "71",
    type: 3,
    name: "Mass Ave opp Inman St"
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
    test "date filter initializes to today when navigating to a commuter rail suspension (RDTS) alert",
         %{conn: conn} do
      today_day_name = Calendar.strftime(@todays_date, "%a %b %0d")

      with_mocks([
        {RoutesRepo, [], [by_type: fn _ -> [@route] end]},
        {StopsRepo, [], [by_route: fn _, _, _ -> [@stop] end]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Commuter Rail", "Suspension")
        render_async(view)

        assert render(view) =~ ~s(Filter: #{today_day_name})
        refute render(view) =~ "Filter: All future trips"
      end
    end

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
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Commuter Rail", "Delay")
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
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Subway", "Delay")
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
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Commuter Rail", "Delay")
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
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Commuter Rail", "Delay")
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
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Ferry", "Delay")
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
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Subway", "Delay")
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
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Bus", "Delay")
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
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Commuter Rail", "Delay")
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
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Commuter Rail", "Delay")
        render_async(view)

        view
        |> element("form")
        |> render_change(%{
          "alert_data" => %{"route_ids" => ["CR-Worcester"], "modal_date" => today}
        })

        render_async(view)

        assert view |> element("#service_view") |> render =~ @schedule_future.trip.name
        refute view |> element("#service_view") |> render =~ @schedule_3.trip.name

        view
        |> element("form")
        |> render_change(%{
          "alert_data" => %{"modal_date" => tomorrow, "route_ids" => ["CR-Worcester"]}
        })

        render_click(view, "accept_filter")
        render_async(view)

        assert view |> element("#service_view") |> render =~ @schedule_3.trip.name
        refute view |> element("#service_view") |> render =~ @schedule_future.trip.name
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
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Commuter Rail", "Delay")
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
    test "selecting 'All future trips' loads trips across all future dates and shows correct filter title",
         %{conn: conn} do
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
               case opts |> Keyword.get(:date) |> to_string() do
                 ^today -> [@schedule_future, @schedule_future]
                 ^tomorrow -> [@schedule_3, @schedule_3]
                 _ -> []
               end

             _, _ ->
               []
           end,
           end_of_rating: fn -> Date.add(@todays_date, 1) end
         ]},
        {StopsRepo, [], [by_route: fn _, _, _ -> [@stop] end]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Commuter Rail", "Delay")
        render_async(view)

        # First select a specific date (today) — only today's trip should appear
        view
        |> element("form")
        |> render_change(%{
          "alert_data" => %{"route_ids" => ["CR-Worcester"], "modal_date" => today}
        })

        render_click(view, "accept_filter")
        render_async(view)

        assert view |> element("#service_view") |> render =~ @schedule_future.trip.name
        refute view |> element("#service_view") |> render =~ @schedule_3.trip.name

        # Select "All future trips" — the select component renders the prompt with value="default",
        # so the browser sends "default" when "All future trips" is chosen.
        view
        |> element("form")
        |> render_change(%{
          "alert_data" => %{"modal_date" => "default", "route_ids" => ["CR-Worcester"]}
        })

        render_click(view, "accept_filter")
        render_async(view)

        # Both trips — today's and tomorrow's — should appear
        assert view |> element("#service_view") |> render =~ @schedule_future.trip.name
        assert view |> element("#service_view") |> render =~ @schedule_3.trip.name
        assert view |> element("#service_view") |> render =~ "Filter: All future trips"
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
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Commuter Rail", "Delay")
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
        assert view |> element("#service_view") |> render =~ @schedule_future.trip.name
        refute view |> element("#service_view") |> render =~ @schedule_3.trip.name
        # Filter title back to today
        assert view |> element("#service_view") |> render =~ ~s(Filter: #{today_day_name})
      end
    end

    @tag :logged_in_user
    test "cancel button appears when filter is active and hides when filter is cleared",
         %{conn: conn} do
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
           by_route_ids: fn _, _ -> [@schedule_future, @schedule_future] end,
           end_of_rating: fn -> Date.add(@todays_date, 7) end
         ]},
        {StopsRepo, [], [by_route: fn _, _, _ -> [@stop] end]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Commuter Rail", "Delay")

        view
        |> element("form")
        |> render_change(%{
          "alert_data" => %{"route_ids" => ["CR-Worcester"], "modal_date" => today}
        })

        render_async(view)

        # No cancel button before filter is applied (today is the default)
        refute render(view) =~ ~s(id="clear-button")

        # Apply a non-today filter
        view
        |> element("form")
        |> render_change(%{
          "alert_data" => %{"modal_date" => tomorrow, "route_ids" => ["CR-Worcester"]}
        })

        render_click(view, "accept_filter")
        render_async(view)

        # Cancel button appears when a non-default filter is active
        assert render(view) =~ ~s(id="clear-button")

        # Clear the filter
        render_click(view, "clear_filter")
        render_async(view)

        # Cancel button disappears after clearing
        refute render(view) =~ ~s(id="clear-button")
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
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Ferry", "Delay")
        render_async(view)

        assert render_async(view) =~ ~s(id="dates-filter-modal_button" disabled="")

        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "route_ids"],
          "alert_data" => %{"route_ids" => [@ferry_route.id]}
        })

        refute render_async(view) =~ ~s(id="dates-filter-modal_button" disabled="")
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
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Ferry", "Delay")
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
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Bus", "Delay")
        render_async(view)

        assert render(view) =~ ~s(id="alert_data_stop_names_and_ids" disabled="")

        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "route_ids"],
          "alert_data" => %{"route_ids" => [@bus_route.id]}
        })

        render_async(view)

        refute render(view) =~ ~s(id="alert_data_stop_names_and_ids" disabled="")
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
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Ferry", "Delay")
        render_async(view)

        assert render_async(view) =~
                 ~s(id="alert_data_stop_names_and_ids" disabled="")

        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "route_ids"],
          "alert_data" => %{"route_ids" => [@route.id]}
        })

        render_async(view)
        refute render(view) =~ ~s(id="alert_data_stop_names_and_ids" disabled="")
        assert render_async(view) =~ "All Stops"

        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "route_ids"],
          "alert_data" => %{"route_ids" => [@route_2.id]}
        })

        render_async(view)
        refute render(view) =~ ~s(id="alert_data_stop_names_and_ids" disabled="")
      end
    end

    @tag :logged_in_user
    test "stop select is disabled on direct URL load for single-route effect before any route selected",
         %{conn: conn} do
      with_mocks([
        {RoutesRepo, [], [by_type: fn _ -> [@bus_route] end]},
        {StopsRepo, [], [by_route: fn _, _, _ -> [@stop] end]},
        {SchedulesRepo, [], [by_route_ids: fn _, _ -> [] end]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/new/bus/detour")
        render_async(view)

        assert render(view) =~ ~s(id="alert_data_stop_names_and_ids" disabled="")
      end
    end

    @tag :logged_in_user
    test "stop select becomes enabled after single_route_id selected on direct URL load",
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
        {:ok, view, _html} = live(conn, "/alerts/new/bus/detour")
        render_async(view)

        assert render(view) =~ ~s(id="alert_data_stop_names_and_ids" disabled="")

        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "single_route_id"],
          "alert_data" => %{"single_route_id" => @bus_route.id}
        })

        render_async(view)

        refute render(view) =~ ~s(id="alert_data_stop_names_and_ids" disabled="")
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
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Bus", "Delay")
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
        {:ok, view, _html} = live(conn, "/alerts/duplicate/test-dup-stops")
        render_async(view)

        {:ok, document} = view |> render() |> Floki.parse_document()

        assert document_has_element?(
                 document,
                 "option[value=\"Courthouse (outbound)|place-crtst\"][selected]"
               )
      end
    end

    @tag :logged_in_user
    test "stop selection is cleared when route is deselected", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _ -> [@bus_route] end,
           get: fn _, _ -> @bus_route end
         ]},
        {StopsRepo, [], [by_route: fn _, _, _ -> [@stop, @stop_2] end]},
        {SchedulesRepo, [], [by_route_ids: fn _, _ -> [] end]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Bus", "Delay")
        render_async(view)

        # Select a route and then a stop
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
            "route_ids" => [@bus_route.id],
            "stop_names_and_ids" => ["#{@stop_2.name} (outbound)|#{@stop_2.id}"]
          }
        })

        render_async(view)

        {:ok, document} = view |> render() |> Floki.parse_document()

        assert document_has_element?(
                 document,
                 "option[value=\"#{@stop_2.name} (outbound)|#{@stop_2.id}\"][selected]"
               )

        # Deselect the route — stop selection must be cleared
        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "route_ids"],
          "alert_data" => %{"route_ids" => []}
        })

        render_async(view)

        {:ok, document} = view |> render() |> Floki.parse_document()

        refute document_has_element?(
                 document,
                 "option[value=\"#{@stop_2.name} (outbound)|#{@stop_2.id}\"][selected]"
               )
      end
    end

    @tag :logged_in_user
    test "stop selection is cleared when a second route is added", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _ -> [@bus_route] end,
           get: fn _, _ -> @bus_route end
         ]},
        {StopsRepo, [], [by_route: fn _, _, _ -> [@stop, @stop_2] end]},
        {SchedulesRepo, [], [by_route_ids: fn _, _ -> [] end]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Bus", "Delay")
        render_async(view)

        # Select a route and then a stop
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
            "route_ids" => [@bus_route.id],
            "stop_names_and_ids" => ["#{@stop_2.name} (outbound)|#{@stop_2.id}"]
          }
        })

        render_async(view)

        {:ok, document} = view |> render() |> Floki.parse_document()

        assert document_has_element?(
                 document,
                 "option[value=\"#{@stop_2.name} (outbound)|#{@stop_2.id}\"][selected]"
               )

        # Add a second route — stop selection must be cleared
        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "route_ids"],
          "alert_data" => %{"route_ids" => [@bus_route.id, "second-route"]}
        })

        render_async(view)

        {:ok, document} = view |> render() |> Floki.parse_document()

        refute document_has_element?(
                 document,
                 "option[value=\"#{@stop_2.name} (outbound)|#{@stop_2.id}\"][selected]"
               )
      end
    end

    @tag :logged_in_user
    test "stop select is disabled when multiple routes are selected", %{conn: conn} do
      boat_f1 = %Route{
        direction_names: %{0 => "Outbound", 1 => "Inbound"},
        sort_order: 1,
        id: "Boat-F1",
        type: 4,
        name: "Hingham Ferry"
      }

      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _ -> [@ferry_route, boat_f1] end,
           by_type: fn _, _ -> [@ferry_route, boat_f1] end,
           get: fn _, _ -> @ferry_route end
         ]},
        {SchedulesRepo, [], [by_route_ids: fn _, _ -> [] end]},
        {StopsRepo, [], [by_route: fn _, _, _ -> [@stop] end]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Ferry", "Delay")
        render_async(view)

        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "route_ids"],
          "alert_data" => %{"route_ids" => [@ferry_route.id, "Boat-F1"]}
        })

        render_async(view)

        assert render(view) =~ ~s(id="alert_data_stop_names_and_ids" disabled=""),
               "stop names should be disabled"
      end
    end

    @tag :logged_in_user
    test "route search filter results", %{conn: conn} do
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
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Commuter Rail", "Delay")
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
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Commuter Rail", "Delay")
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
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Commuter Rail", "Delay")
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
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Bus", "Detour")
        render_async(view)

        refute render_async(view) =~ "text-text-error"

        open_review_modal(view)

        render_async(view)

        assert has_element?(view, "p.text-text-error", "Select a route")

        # Flash
        assert view
               |> element("#flash")
               |> render() =~ "Select a route"
      end
    end

    @tag :logged_in_user
    test "shows inline error when the stop selector is blurred with exactly one stop selected for suspension",
         %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [by_type: fn _ -> [@subway_route] end, get: fn _, _ -> @subway_route end]},
        {StopsRepo, [], [by_route: fn _, _, _ -> [@subway_stop, @stop_2] end]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Subway", "Suspension")
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
            "stop_names_and_ids" => ["#{@subway_stop.name}|#{@subway_stop.id}"]
          }
        })

        refute render(view) =~ "Select 2 or more stops"
        refute has_element?(view, "#flash")

        assert has_element?(
                 view,
                 ~s(div#stop_names_and_ids_selector_wrapper[phx-hook="FocusOutPush"][data-focusout-event="stop_selector_blur"])
               )

        render_hook(view, "stop_selector_blur", %{})

        assert has_element?(
                 view,
                 "p.text-text-error",
                 "Select 2 or more stops between which service is not running"
               )

        refute has_element?(view, "#flash")
      end
    end

    @tag :logged_in_user
    test "shows flash error on review attempt with exactly one stop selected for suspension",
         %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [by_type: fn _ -> [@subway_route] end, get: fn _, _ -> @subway_route end]},
        {StopsRepo, [], [by_route: fn _, _, _ -> [@subway_stop, @stop_2] end]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Subway", "Suspension")
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
            "stop_names_and_ids" => ["#{@subway_stop.name}|#{@subway_stop.id}"]
          }
        })

        open_review_modal(view)
        render_async(view)

        assert has_element?(
                 view,
                 "p.text-text-error",
                 "Select 2 or more stops between which service is not running"
               )

        assert view
               |> element("#flash")
               |> render() =~ "Select 2 or more stops between which service is not running"
      end
    end

    @tag :logged_in_user
    test "shows progressive errors if stops are not selected for Bypass alerts",
         %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [by_type: fn _ -> [@subway_route] end, get: fn _, _ -> @subway_route end]},
        {StopsRepo, [], [by_route: fn _, _, _ -> [@subway_stop, @stop_2] end]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Subway", "Station bypass")
        render_async(view)

        open_review_modal(view)
        render_async(view)

        assert has_element?(view, "p.text-text-error", "Select a route")
        refute has_element?(view, "p.text-text-error", "Select stop(s)")

        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "single_route_id"],
          "alert_data" => %{"single_route_id" => @subway_route.id}
        })

        render_async(view)
        open_review_modal(view)

        refute has_element?(view, "p.text-text-error", "Select a route")
        assert has_element?(view, "p.text-text-error", "Select stop(s)")
      end
    end

    @tag :logged_in_user
    test "hides 'All Stops' option for Bypass alerts",
         %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [by_type: fn _ -> [@subway_route] end, get: fn _, _ -> @subway_route end]},
        {StopsRepo, [], [by_route: fn _, _, _ -> [@subway_stop, @stop_2] end]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Subway", "Station bypass")
        render_async(view)

        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "route_ids"],
          "alert_data" => %{"route_ids" => [@subway_route.id]}
        })

        render_async(view)

        refute has_element?(view, "option", "All Stops")
      end
    end

    @tag :logged_in_user
    test "renders with 'All Future Trips' selected while editing an existing commuter rail alert",
         %{conn: conn} do
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
        {SchedulesRepo, [],
         [by_route_ids: fn _, _ -> [] end, end_of_rating: fn -> Date.add(@todays_date, 7) end]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/edit/test-cr-edit")
        render_async(view)

        {:ok, document} = view |> render_async() |> Floki.parse_document()

        assert document_has_element?(
                 document,
                 "option[value=\"CR-Worcester\"][selected]"
               )

        assert render_async(view) =~ "Filter: All future trips"
      end
    end

    @tag :logged_in_user
    test "renders with 'All Future Trips' selected while duplicating an existing commuter rail alert",
         %{conn: conn} do
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
        {SchedulesRepo, [],
         [by_route_ids: fn _, _ -> [] end, end_of_rating: fn -> Date.add(@todays_date, 7) end]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/duplicate/test-cr-edit")
        render_async(view)

        {:ok, document} = view |> render() |> Floki.parse_document()

        assert document_has_element?(
                 document,
                 "option[value=\"CR-Worcester\"][selected]"
               )

        assert render(view) =~ "Filter: All future trips"
      end
    end

    @tag :logged_in_user
    test "does not query schedules if not a trip based alert",
         %{conn: conn} do
      alert_params =
        build(:alert_map, %{
          alert_id: "test-bus-query",
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
        {SchedulesRepo, [],
         [by_route_ids: fn _, _ -> [] end, end_of_rating: fn -> Date.add(@todays_date, 1) end]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/edit/test-bus-query")
        render_async(view)

        {:ok, document} = view |> render() |> Floki.parse_document()

        assert document_has_element?(
                 document,
                 "option[value=\"746\"][selected]"
               )

        refute called(SchedulesRepo.end_of_rating())
        refute called(SchedulesRepo.by_route_ids(:_, :_))
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
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Commuter Rail", "Delay")
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
          "_target" => ["alert_data", "modal_date_search_term"],
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
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Ferry", "Delay")
        render_async(view)

        assert render_async(view) =~
                 ~s(id="alert_data_stop_names_and_ids" disabled="")

        refute render_async(view) =~ "All Stops"

        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "route_ids"],
          "alert_data" => %{"route_ids" => [@route.id]}
        })

        render_async(view)

        refute render_async(view) =~
                 ~s(id="alert_data_stop_names_and_ids" disabled="")

        assert render_async(view) =~ "All Stops"

        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "route_ids"],
          "alert_data" => %{"route_ids" => [@route_2.id]}
        })

        render_async(view)

        refute render_async(view) =~
                 ~s(id="alert_data_stop_names_and_ids" disabled="")
      end
    end

    @tag :logged_in_user
    test "stop element not spuriously disabled if there is an error in the form", %{conn: conn} do
      # https://app.notion.com/p/mbta-downtown-crossing/Stop-selector-disabled-for-recurring-alert-37ef5d8d11ea8047a5b4ebad98deacc4?source=copy_link
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
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Bus", "Delay")
        render_async(view)

        assert render_async(view) =~
                 ~s(id="alert_data_stop_names_and_ids" disabled="")

        refute render_async(view) =~ "All Stops"

        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "route_ids"],
          "alert_data" => %{"route_ids" => [@route.id]}
        })

        view
        |> element("form")
        |> render_change(%{
          "alert_data" => %{
            "alert_timing" => "recurring"
          }
        })

        render_async(view)

        refute render_async(view) =~
                 ~s(id="alert_data_stop_names_and_ids" disabled=""),
               "stop selector should not be disabled"
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
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Bus", "Delay")
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
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Commuter Rail", "Delay")
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
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Commuter Rail", "Delay")
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
        submit_alert(view)

        new_alert = parse_alert_created_output(view)
        trip_ids = new_alert.informed_entity |> Enum.map(& &1.trip.trip_id) |> Enum.sort()

        assert trip_ids == ["trip-595", "trip-596"]
      end
    end

    @tag :logged_in_user
    test "editing updates stop selection in the database", %{conn: conn} do
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
           end,
           by_trip: fn _trip_id -> [@stop] end
         ]},
        {RoutePatternsRepo, [],
         [
           by_route_id: fn _, _ -> [] end,
           included_stops_by_route_id: fn "CR-Worcester", _ -> [@stop, @stop_2] end
         ]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/edit/test-edit-stop")
        render_async(view)

        {:ok, document} = view |> render() |> Floki.parse_document()

        assert document_has_element?(
                 document,
                 "[value=\"CR-Worcester\"][selected]"
               )

        assert document_has_element?(
                 document,
                 "[value=\"South Station|place-sstat\"][selected]"
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
        render_async(view)

        view
        |> element("#review-modal-container button", "Submit")
        |> render_click()

        :timer.sleep(50)
        alert = Alerts.get_by_alert_id("test-edit-stop")

        assert Enum.any?(alert.informed_entity, &(&1.stop_id == "place-crtst"))
      end
    end

    @tag :logged_in_user
    test "editing a station bypass alert does not render the obsolete entities modal", %{
      conn: conn
    } do
      alert_params =
        build(:alert_map, %{
          alert_id: "test-station-bypass",
          effect: :NO_SERVICE,
          effect_detail: "STATION_CLOSURE",
          effect_name: "Station Bypass",
          primary_service_type: "1",
          informed_entity: [
            %{
              route_type: 1,
              route_id: @subway_route.id,
              stop_id: @subway_stop.id,
              direction_id: 0
            }
          ],
          original_route_selections: ["#{@subway_route.name}|#{@subway_route.id}"],
          original_stop_selections: ["#{@subway_stop.name}|#{@subway_stop.id}"]
        })

      {:ok, _} = Alerts.create_or_update_alert(alert_params, build(:user))

      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _ -> [@subway_route] end,
           get: fn _ -> @subway_route end,
           get: fn _, _ -> @subway_route end,
           all: fn _ -> [@subway_route] end
         ]},
        {StopsRepo, [],
         [
           by_route: fn _, _, _ -> [@subway_stop] end,
           get_parent: fn _ -> nil end
         ]},
        {SchedulesRepo, [], [by_route_ids: fn _, _ -> [] end]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/edit/test-station-bypass")
        render_async(view)

        refute view
               |> element("#gtfs-warning-modal")
               |> has_element?
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
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Commuter Rail", "Cancellation")
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
        {:ok, view, _html} = live(conn, "/alerts/new")

        view = get_to_submission_page(conn, view, "Bus", "Delay")

        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "route_ids"],
          "alert_data" => %{"route_ids" => []}
        })

        open_review_modal(view)

        render_async(view)

        # Inline
        assert has_element?(view, "p.text-text-error", "Select route(s)")

        # Flash
        assert view
               |> element("#flash")
               |> render() =~ "Select route(s)"
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
        {:ok, view, _html} = live(conn, "/alerts/new")

        view = get_to_submission_page(conn, view, "Commuter Rail", "Delay")

        render_async(view)

        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "route_ids"],
          "alert_data" => %{"route_ids" => ["CR-Worcester"]}
        })

        render_async(view)

        # Mock user selecting 2 trips in addition to "All Trips"
        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "trip_ids"],
          "alert_data" => %{"trip_ids" => ["default", "trip-595", "trip-596"]}
        })

        # At this time, we CAN'T test the JS hook unless we set up Playwright.
        # So, we can't check whether the selections look right to the user,
        # but we can verify that the data on the server is correct when the form
        # is submitted

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
    test "editing", %{conn: conn} do
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
           end,
           by_trip: fn _trip_id -> [@stop] end
         ]},
        {RoutePatternsRepo, [],
         [
           by_route_id: fn _, _ -> [] end,
           included_stops_by_route_id: fn "CR-Worcester", _ -> [@stop, @stop_2] end
         ]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/edit/test-e2e-editing")
        render_async(view)

        {:ok, document} =
          view
          |> render()
          |> Floki.parse_document()

        assert document_has_element?(
                 document,
                 "[value=\"CR-Worcester\"][selected]"
               )

        assert document_has_element?(
                 document,
                 "[value=\"South Station|place-sstat\"][selected]"
               )

        assert document_has_element?(
                 document,
                 "[value=\"trip-595\"][selected]"
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
        {:ok, view, _html} = live(conn, "/alerts/new")

        view = get_to_submission_page(conn, view, "Commuter Rail", "Cancellation")

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

    @tag :logged_in_user
    test "can add alternate route entities for RDT", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _ -> [@boat_f1, @boat_f2h] end,
           by_type: fn _, _ -> [@boat_f1, @boat_f2h] end,
           get: fn _, _ -> @boat_f1 end
         ]},
        {SchedulesRepo, [],
         [
           by_route_ids: fn _, _ -> [@boat_f1_schedule_1, @boat_f1_schedule_2] end
         ]},
        {StopsRepo, [],
         [
           by_route: fn _, _, _ -> [@boat_f1_schedule_1.stop] end,
           all: fn
             ["filter[id]": ""], _ ->
               []
           end
         ]},
        {RoutePatternsRepo, [],
         [
           by_route_id: fn _, _ -> [] end
         ]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Ferry", "Delay")
        render_async(view)

        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "route_ids"],
          "alert_data" => %{"route_ids" => [@boat_f1_schedule_1.route_id]}
        })

        render_async(view)

        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "trip_ids"],
          "alert_data" => %{"trip_ids" => [@boat_f1_schedule_1.trip.id]}
        })

        open_review_modal(view)
        submit_alert(view)

        new_alert = parse_alert_created_output(view)

        [
          %{
            route_id: "Boat-F1",
            stop_id: nil,
            trip: %{trip_id: "Boat-F1-2030-Rowes-F1-A-PM-Weekday-Summer-26"}
          },
          %{
            route_id: "Boat-F2H",
            stop_id: nil,
            trip: %{trip_id: "Boat-F1-2030-Rowes-F1-A-PM-Weekday-Summer-26"}
          }
        ] =
          new_alert.informed_entity
      end
    end

    @tag :logged_in_user
    test "can add alternate route entities for RDTS", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _ -> [@boat_f1, @boat_f2h] end,
           by_type: fn _, _ -> [@boat_f1, @boat_f2h] end,
           get: fn _, _ -> @boat_f1 end
         ]},
        {SchedulesRepo, [],
         [
           by_route_ids: fn _, _ -> [@boat_f1_schedule_1, @boat_f1_schedule_2] end
         ]},
        {StopsRepo, [],
         [
           by_route: fn _, _, _ -> [@boat_f1_schedule_1.stop] end,
           all: fn
             ["filter[id]": "Boat-Rowes"], _ ->
               [%Stop{id: "Boat-Rowes", name: "Rowes Wharf"}]
           end
         ]},
        {RoutePatternsRepo, [],
         [
           by_route_id: fn _, _ -> [] end
         ]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Ferry", "Delay")
        render_async(view)

        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "route_ids"],
          "alert_data" => %{"route_ids" => [@boat_f1_schedule_1.route_id]}
        })

        render_async(view)

        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "trip_ids"],
          "alert_data" => %{"trip_ids" => [@boat_f1_schedule_1.trip.id]}
        })

        render_async(view)

        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "stop_names_and_ids"],
          "alert_data" => %{"stop_names_and_ids" => ["Rowes Wharf|Boat-Rowes"]}
        })

        render_async(view)

        open_review_modal(view)
        submit_alert(view)

        new_alert = parse_alert_created_output(view)

        [
          %{
            route_id: "Boat-F1",
            stop_id: "Boat-Rowes",
            trip: %{trip_id: "Boat-F1-2030-Rowes-F1-A-PM-Weekday-Summer-26"}
          },
          %{
            route_id: "Boat-F2H",
            stop_id: "Boat-Rowes",
            trip: %{trip_id: "Boat-F1-2030-Rowes-F1-A-PM-Weekday-Summer-26"}
          }
        ] = new_alert.informed_entity
      end
    end

    @tag :logged_in_user
    test "can add alternate route entities along with parent entities", %{conn: conn} do
      cr_franklin = %Route{
        direction_names: %{0 => "Outbound", 1 => "Inbound"},
        sort_order: 1,
        id: "CR-Franklin",
        type: 4,
        name: "Franklin/Foxboro Line"
      }

      cr_franklin_schedule = %Schedule{
        stop: %Stop{id: "place-sstat", name: "South Station"},
        departure_time: @two_hours_from_now,
        arrival_time: DateTime.add(@two_hours_from_now, 30, :minute),
        trip: %Trip{id: "SWKDYWCPeriod-831443-1775", name: "", direction_id: 0},
        route_id: "CR-Franklin",
        added_route_ids: ["CR-Fairmount"]
      }

      cr_franklin_schedule_2 = %{
        cr_franklin_schedule
        | departure_time: DateTime.add(@boat_f1_schedule_1.departure_time, 2, :hour),
          arrival_time: DateTime.add(@boat_f1_schedule_1.arrival_time, 2, :hour)
      }

      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _ -> [cr_franklin] end,
           by_type: fn _, _ -> [cr_franklin] end,
           get: fn _, _ -> cr_franklin end
         ]},
        {SchedulesRepo, [],
         [
           by_route_ids: fn _, _ -> [cr_franklin_schedule, cr_franklin_schedule_2] end
         ]},
        {StopsRepo, [],
         [
           by_route: fn _, _, _ -> [cr_franklin_schedule.stop] end,
           all: fn
             ["filter[id]": "place-sstat"], _ ->
               [%Stop{id: "place-sstat", name: "South Station"}]
           end
         ]},
        {RoutePatternsRepo, [],
         [
           by_route_id: fn "CR-Franklin", _ ->
             [
               %RoutePattern{
                 direction_id: 0,
                 id: "CR-Franklin-3badde55-0",
                 stop_ids: ["NEC-2287"],
                 stops: [
                   %Stop{
                     id: "NEC-2287",
                     parent_id: "place-sstat"
                   }
                 ]
               }
             ]
           end
         ]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Ferry", "Delay")
        render_async(view)

        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "route_ids"],
          "alert_data" => %{"route_ids" => [cr_franklin_schedule.route_id]}
        })

        render_async(view)

        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "trip_ids"],
          "alert_data" => %{"trip_ids" => [cr_franklin_schedule.trip.id]}
        })

        render_async(view)

        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "stop_names_and_ids"],
          "alert_data" => %{"stop_names_and_ids" => ["South Station|place-sstat"]}
        })

        render_async(view)

        open_review_modal(view)
        submit_alert(view)

        new_alert = parse_alert_created_output(view)

        [
          %{
            route_id: "CR-Franklin",
            stop_id: "NEC-2287",
            trip: %{trip_id: "SWKDYWCPeriod-831443-1775"}
          },
          %{
            route_id: "CR-Fairmount",
            stop_id: "NEC-2287",
            trip: %{trip_id: "SWKDYWCPeriod-831443-1775"}
          },
          %{
            route_id: "CR-Franklin",
            stop_id: "place-sstat",
            trip: %{trip_id: "SWKDYWCPeriod-831443-1775"}
          },
          %{
            route_id: "CR-Fairmount",
            stop_id: "place-sstat",
            trip: %{trip_id: "SWKDYWCPeriod-831443-1775"}
          }
        ] = new_alert.informed_entity
      end
    end

    @tag :logged_in_user
    test "Boat-F2H alerts with trips should include Boat-F1 informed entities", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _ -> [@boat_f1, @boat_f2h] end,
           by_type: fn _, _ -> [@boat_f1, @boat_f2h] end,
           get: fn _, _ -> @boat_f2h end
         ]},
        {SchedulesRepo, [],
         [
           by_route_ids: fn _, _ -> [@boat_f2h_schedule_1, @boat_f2h_schedule_2] end
         ]},
        {StopsRepo, [],
         [
           by_route: fn _, _, _ -> [@boat_f2h_schedule_1.stop] end,
           all: fn
             ["filter[id]": ""], _ ->
               []
           end
         ]},
        {RoutePatternsRepo, [],
         [
           by_route_id: fn _, _ -> [] end
         ]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Ferry", "Delay")
        render_async(view)

        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "route_ids"],
          "alert_data" => %{"route_ids" => [@boat_f2h_schedule_1.route_id]}
        })

        render_async(view)

        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "trip_ids"],
          "alert_data" => %{"trip_ids" => [@boat_f2h_schedule_1.trip.id]}
        })

        open_review_modal(view)
        submit_alert(view)

        new_alert = parse_alert_created_output(view)

        [
          %{
            route_id: "Boat-F2H",
            stop_id: nil,
            trip: %{
              route_id: "Boat-F2H",
              trip_id: "Boat-F2H-1440-Long-F2H-B-PM-Weekday-GeorgesIsland-Summer-26"
            }
          },
          %{
            route_id: "Boat-F1",
            stop_id: nil,
            trip: %{
              route_id: "Boat-F1",
              trip_id: "Boat-F2H-1440-Long-F2H-B-PM-Weekday-GeorgesIsland-Summer-26"
            }
          }
        ] =
          new_alert.informed_entity
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
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Bus", "Delay")
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
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Subway", "Notice")
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
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Commuter Rail", "Delay")
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

  describe "transform_changeset - stop coherence" do
    defp stop_coherence_changeset(attrs) do
      Ecto.Changeset.cast(
        %AlertData{},
        Map.merge(%{route_type: 1, direction: "default", trip_ids: []}, attrs),
        [:direction, :effect_name, :route_ids, :stop_names_and_ids, :route_type, :trip_ids]
      )
    end

    test "clears stop selection when route is deselected by user input" do
      changeset =
        stop_coherence_changeset(%{route_ids: [], stop_names_and_ids: ["Central|place-cntsq"]})

      params = %{"_target" => ["alert_data", "my_target"]}

      result = AffectedServiceSlice.transform_changeset(changeset, params)
      assert Ecto.Changeset.get_field(result, :stop_names_and_ids) == []
      assert Ecto.Changeset.get_field(result, :stop_ids) == []
    end

    test "preserves stop selection when no user input is present" do
      changeset =
        stop_coherence_changeset(%{route_ids: [], stop_names_and_ids: ["Central|place-cntsq"]})

      result = AffectedServiceSlice.transform_changeset(changeset, %{})

      assert Ecto.Changeset.get_field(result, :stop_names_and_ids) == ["Central|place-cntsq"]
      assert Ecto.Changeset.get_field(result, :stop_ids) == ["place-cntsq"]
    end

    test "clears stop selection when multiple routes are selected via user input" do
      changeset =
        stop_coherence_changeset(%{
          route_ids: ["Red", "Orange"],
          stop_names_and_ids: ["Central|place-cntsq"]
        })

      params = %{"_target" => ["alert_data", "my_target"]}

      result = AffectedServiceSlice.transform_changeset(changeset, params)

      assert Ecto.Changeset.get_field(result, :stop_names_and_ids) == []
      assert Ecto.Changeset.get_field(result, :stop_ids) == []
    end

    test "preserves stop selection when multiple routes are selected and no user input is present" do
      changeset =
        stop_coherence_changeset(%{
          route_ids: ["Red", "Orange"],
          stop_names_and_ids: ["Central|place-cntsq"]
        })

      result = AffectedServiceSlice.transform_changeset(changeset, %{})
      assert Ecto.Changeset.get_field(result, :stop_names_and_ids) == ["Central|place-cntsq"]
      assert Ecto.Changeset.get_field(result, :stop_ids) == ["place-cntsq"]
    end

    test "preserves stop selection when exactly one route is selected" do
      changeset =
        stop_coherence_changeset(%{
          route_ids: ["Red"],
          stop_names_and_ids: ["Central|place-cntsq"]
        })

      result = AffectedServiceSlice.transform_changeset(changeset, %{})

      assert Ecto.Changeset.get_field(result, :stop_names_and_ids) == ["Central|place-cntsq"]
      assert Ecto.Changeset.get_field(result, :stop_ids) == ["place-cntsq"]
    end

    test "filters out Name|default entries from stop_names_and_ids" do
      changeset =
        stop_coherence_changeset(%{
          route_ids: ["Red"],
          stop_names_and_ids: ["Central|default"]
        })

      result = AffectedServiceSlice.transform_changeset(changeset, %{})

      assert Ecto.Changeset.get_field(result, :stop_ids) == []
    end

    test "strips bare \"default\" when selected alongside a real stop" do
      changeset =
        stop_coherence_changeset(%{
          route_ids: ["Red"],
          stop_names_and_ids: ["default", "Central|place-cntsq"]
        })

      result = AffectedServiceSlice.transform_changeset(changeset, %{})

      assert Ecto.Changeset.get_field(result, :stop_names_and_ids) == ["Central|place-cntsq"]
      refute "default" in Ecto.Changeset.get_field(result, :stop_names_and_ids)
    end

    test "clears stop and trip selections when route_ids target fires with a different single route" do
      changeset =
        stop_coherence_changeset(%{
          route_ids: ["Red"],
          stop_names_and_ids: ["Central|place-cntsq"],
          trip_ids: ["trip-595"]
        })

      params = %{"_target" => ["alert_data", "route_ids"]}

      result = AffectedServiceSlice.transform_changeset(changeset, params)

      assert Ecto.Changeset.get_field(result, :stop_names_and_ids) == []
      assert Ecto.Changeset.get_field(result, :trip_ids) == []
    end

    test "clears stop and trip selections when single_route_id target fires" do
      changeset =
        stop_coherence_changeset(%{
          route_ids: ["746"],
          stop_names_and_ids: ["World Trade Center (outbound)|place-wtcst"],
          trip_ids: ["trip-595"]
        })

      params = %{"_target" => ["alert_data", "single_route_id"]}

      result = AffectedServiceSlice.transform_changeset(changeset, params)

      assert Ecto.Changeset.get_field(result, :stop_names_and_ids) == []
      assert Ecto.Changeset.get_field(result, :trip_ids) == []
    end
  end

  describe "skate detours" do
    @tag :logged_in_user
    test "detour select is disabled until route is selected", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _ -> [@bus_route] end,
           get: fn _, _ -> @bus_route end
         ]},
        {StopsRepo, [], [by_route: fn _, _, _ -> [@detour_stop] end]}
      ]) do
        conn = put_resp_cookie(conn, "show_new_bus_detours", "true")
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Bus", "Detour")

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
    test "detour prompt changes if all skate detours are used", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _ -> [@bus_route] end,
           get: fn _, _ -> @bus_route end
         ]},
        {StopsRepo, [], [by_route: fn _, _, _ -> [] end]},
        {Alerts, [],
         [
           get_matching_skate_ids: fn _ ->
             [
               %{alert_id: "123", skate_detour_id: 7},
               %{alert_id: "123", skate_detour_id: 8},
               %{alert_id: "123", skate_detour_id: 9},
               %{alert_id: "123", skate_detour_id: 10}
             ]
           end
         ]}
      ]) do
        conn = put_resp_cookie(conn, "show_new_bus_detours", "true")
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Bus", "Detour")

        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "single_route_id"],
          "alert_data" => %{"route_ids" => ["1"], "single_route_id" => "1"}
        })

        assert view |> element("#alert_data_skate_detour_id_selector") |> render_async =~
                 ~s(disabled="" title="Already associated with alert 123")
      end
    end

    @tag :logged_in_user
    test "detour select is displayed if one matches selected route", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _ -> [@detour_bus_route] end,
           get: fn _, _ -> @detour_bus_route end
         ]},
        {StopsRepo, [], [by_route: fn _, _, _ -> [@detour_stop] end]}
      ]) do
        conn = put_resp_cookie(conn, "show_new_bus_detours", "true")
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Bus", "Detour")

        render_async(view)

        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "single_route_id"],
          "alert_data" => %{"route_ids" => ["1"], "single_route_id" => "1"}
        })

        assert view |> element("#alert_data_skate_detour_id_selector") |> render_async =~
                 "Inbound"

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
           by_type: fn _ -> [@detour_bus_route] end,
           get: fn _, _ -> @detour_bus_route end
         ]},
        {StopsRepo, [], [by_route: fn _, _, _ -> [@detour_stop, @connection_stop] end]}
      ]) do
        conn = put_resp_cookie(conn, "show_new_bus_detours", "true")
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Bus", "Detour")

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
                 "Route 1 inbound is detoured, skipping Mass Ave at Pearl St due to a drawbridge being raised. The closest stop with service is Mass Ave opp Inman St."
      end
    end

    @tag :logged_in_user
    test "if a skate detour is selected, the skate detour id is persisted", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _ -> [@detour_bus_route] end,
           get: fn _, _ -> @detour_bus_route end
         ]},
        {StopsRepo, [],
         [by_route: fn _, _, _ -> [@detour_stop] end, all: fn _, _ -> [@detour_stop] end]},
        {RoutePatternsRepo, [],
         [
           by_route_id: fn _, _ -> [] end
         ]}
      ]) do
        conn = put_resp_cookie(conn, "show_new_bus_detours", "true")
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Bus", "Detour")

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
end
