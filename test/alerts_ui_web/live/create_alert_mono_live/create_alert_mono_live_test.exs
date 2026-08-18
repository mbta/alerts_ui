defmodule AlertsUIWeb.CreateAlertMonoLiveTest do
  use ExUnit.Case, async: false
  use AlertsUIWeb.ConnCase
  import Phoenix.LiveViewTest
  import AlertsUI.Support.Factory
  import Mock
  import Test.Support.Helpers

  alias AlertsUI.Alerts
  alias AlertsUI.Models.EnhancedSchedule
  alias MBTAV3API.Facilities.Facility
  alias MBTAV3API.Facilities.Repo, as: FacilitiesRepo
  alias MBTAV3API.RoutePatterns.Repo, as: RoutePatternsRepo
  alias MBTAV3API.RoutePatterns.RoutePattern
  alias MBTAV3API.Routes.Repo, as: RoutesRepo
  alias MBTAV3API.Routes.Route
  alias MBTAV3API.Schedules.Repo, as: SchedulesRepo
  alias MBTAV3API.Schedules.Trip
  alias MBTAV3API.Stops.Repo, as: StopsRepo
  alias MBTAV3API.Stops.Stop

  @route %Route{
    direction_names: %{0 => "Westbound", 1 => "Eastbound"},
    sort_order: 3,
    id: "CR-Worcester",
    type: 2,
    name: "Framingham/Worcester Line"
  }

  @stop %Stop{id: "place-sstat", name: "South Station"}

  @schedule %EnhancedSchedule{
    route: %Route{id: "CR-Worcester", type: 2, name: "Framingham/Worcester Line"},
    trip: %Trip{id: "CR-683322-595", name: "595", direction_id: 0},
    stop: %Stop{id: "place-sstat", name: "South Station"},
    arrival_time: nil,
    departure_time: Date.utc_today() |> DateTime.new!(~T[22:00:00], "America/New_York")
  }
  @schedule_2 %EnhancedSchedule{
    route: %Route{id: "CR-Worcester", type: 2, name: "Framingham/Worcester Line"},
    trip: %Trip{id: "CR-683322-595", name: "595", direction_id: 0},
    stop: %Stop{id: "place-sstat", name: "South Station"},
    arrival_time: Date.utc_today() |> DateTime.new!(~T[22:00:00], "America/New_York"),
    departure_time: nil
  }

  @route_pattern %RoutePattern{
    direction_id: 0,
    stops: [@stop],
    route_id: "CR-Worcester",
    id: "CR-Worcester-1"
  }

  @todays_date DateTime.utc_now()
               |> DateTime.shift_zone!("America/New_York")
               |> DateTime.to_date()

  describe "create alerts page" do
    @tag :logged_in_user
    test "connected mount displays first page of form when logged in", %{conn: conn} do
      {:ok, view, html} = live(conn, "/alerts/new")

      assert html =~ ~r/Create Alert/

      assert view
             |> element("#form_container", "Creating New Alert")
             |> has_element?
    end

    test "redirects the user when not logged in", %{conn: conn} do
      assert live(conn, "/alerts/new") ==
               {:error, {:redirect, %{to: "/auth/keycloak", flash: %{}}}}
    end

    @tag :logged_in_user
    test "does not crash if you navigate right to the review modal", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/alerts/new/bus/delay?review=true")

      assert html =~ ~r/Create Alert/
    end

    @tag :logged_in_user
    test "submitting first part of form unhides second part", %{conn: conn} do
      with_mocks([
        {RoutePatternsRepo, [],
         [
           by_route_id: fn _route_id, _opts -> [@route_pattern] end,
           included_stops_by_route_id: fn _route_id, _ -> [@stop] end
         ]},
        {StopsRepo, [], by_route: fn _, _, _opts -> [@stop] end},
        {RoutesRepo, [], [by_type: fn _type -> [@route] end, get: fn _id, _opts -> @route end]},
        {SchedulesRepo, [], by_route_ids: fn _route_ids, _opts -> [] end}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/new")

        first_rendered_view = render_async(view)
        assert first_rendered_view =~ ~s(class="min-w-full flex flex-col mb-8" id="route_view")
        refute first_rendered_view =~ ~s(class="min-w-full flex flex-col mt-4" id="details_view")

        view = get_to_submission_page_refactor(conn, view, "Commuter Rail", "Suspension")

        second_rendered_view = render_async(view, 1000)

        refute second_rendered_view =~ ~s(class="min-w-full flex flex-col mb-8" id="route_view")
        assert second_rendered_view =~ ~s(class="min-w-full flex flex-col mt-4" id="details_view")

        # Submit service section
        view
        |> element("form")
        |> render_change(%{"alert_data" => %{"route_ids" => ["CR-Worcester"]}})

        view
        |> element("form")
        |> render_change(%{
          "alert_data" => %{"stop_ids" => [@stop.id]}
        })

        # Check header for autotext
        assert view |> element("#alert_data_header_text") |> render() =~
                 "Framingham/Worcester Line: service is suspended"
      end
    end

    @tag :logged_in_user
    test "Correctly displays prediction suppression modal", %{conn: conn} do
      with_mocks([
        {SchedulesRepo, [], by_route_ids: fn _route_ids, _opts -> [] end},
        {StopsRepo, [], by_route: fn _, _, _opts -> [@stop] end},
        {RoutesRepo, [], [by_type: fn _type -> [@route] end, get: fn _id, _opts -> @route end]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/new")

        view = get_to_submission_page_refactor(conn, view, "Commuter Rail", "Suspension")

        view
        |> element("form")
        |> render_change(%{"alert_data" => %{"route_ids" => [@route.id]}})

        open_review_modal(view)

        assert view |> element("#check_predictions_modal-container") |> render() =~
                 ~s(Warning: Predictions will be suppressed)

        assert view |> element("#check_predictions_modal-container") |> render() =~
                 "#{@route.name}"
      end
    end

    @tag :logged_in_user
    test "Prediction suppression modal still comes up even if you went to the review modal and back",
         %{conn: conn} do
      with_mocks([
        {SchedulesRepo, [], by_route_ids: fn _route_ids, _opts -> [] end},
        {StopsRepo, [], by_route: fn _, _, _opts -> [@stop] end},
        {RoutesRepo, [], [by_type: fn _type -> [@route] end, get: fn _id, _opts -> @route end]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/new")

        view = get_to_submission_page_refactor(conn, view, "Commuter Rail", "Suspension")

        view
        |> element("form")
        |> render_change(%{"alert_data" => %{"route_ids" => [@route.id]}})

        open_review_modal(view)

        view
        |> element("#check_predictions_modal-container button", "Yes, continue")
        |> render_click()

        view
        |> element("#review-modal-container button", "Keep editing")
        |> render_click()

        refute render_async(view) =~ ~s(id="check_predictions_modal-container"),
               "prediction modal should no longer be rendered"

        open_review_modal(view)

        assert render_async(view) =~ ~s(id="check_predictions_modal-container"),
               "prediction modal should render"

        assert view |> element("#check_predictions_modal-container") |> render() =~
                 ~s(Warning: Predictions will be suppressed)
      end
    end

    @tag :logged_in_user
    test "Correctly displays trip end warning modal", %{conn: conn} do
      with_mocks([
        {SchedulesRepo, [], by_route_ids: fn _route_ids, _opts -> [@schedule, @schedule_2] end},
        {StopsRepo, [], by_route: fn _, _, _opts -> [@stop] end},
        {RoutesRepo, [], [by_type: fn _type -> [@route] end, get: fn _id, _opts -> @route end]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/new")

        view = get_to_submission_page_refactor(conn, view, "Commuter Rail", "Delay")

        view
        |> element("form")
        |> render_change(%{
          "alert_data" => %{
            "route_ids" => [@route.id],
            "stop_ids" => [@stop.id],
            "trip_ids" => ["CR-683322-595"],
            "active_period_start_specifier" => :custom
          }
        })

        view
        |> element("form")
        |> render_change(%{
          "alert_data" => %{
            "active_period_start" => Date.utc_today() |> NaiveDateTime.new!(~T[23:00:00])
          }
        })

        open_review_modal(view)

        assert view |> element("#trip_end_warning_modal-container") |> render() =~
                 "Warning: Alert starts after end of trip(s)"
      end
    end

    @tag :logged_in_user
    test "Works with both modals", %{conn: conn} do
      with_mocks([
        {SchedulesRepo, [], by_route_ids: fn _route_ids, _opts -> [@schedule, @schedule_2] end},
        {StopsRepo, [], by_route: fn _, _, _opts -> [@stop] end},
        {RoutesRepo, [], [by_type: fn _type -> [@route] end, get: fn _id, _opts -> @route end]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/new")

        view = get_to_submission_page_refactor(conn, view, "Commuter Rail", "Suspension")

        view
        |> element("form")
        |> render_change(%{
          "alert_data" => %{
            "route_ids" => [@route.id],
            "trip_ids" => ["CR-683322-595"],
            "active_period_start_specifier" => :custom
          }
        })

        view
        |> element("form")
        |> render_change(%{
          "alert_data" => %{
            "active_period_start" => Date.utc_today() |> NaiveDateTime.new!(~T[23:00:00])
          }
        })

        open_review_modal(view)

        assert view |> element("#check_predictions_modal-container") |> render() =~
                 ~s(Warning: Predictions will be suppressed)

        view
        |> element("#check_predictions_modal-container button", "Yes, continue")
        |> render_click()

        assert view |> element("#trip_end_warning_modal-container") |> render() =~
                 "Warning: Alert starts after end of trip(s)"

        view
        |> element("#trip_end_warning_modal-container button", "Yes, continue")
        |> render_click()

        assert view
               |> element("#review-modal-container", "Commuter Rail • Suspension")
               |> has_element?
      end
    end

    @tag :logged_in_user
    test "shows correct affected service for access combination", %{conn: conn} do
      with_mocks([
        {RoutePatternsRepo, [], [included_stops_by_route_id: fn _route_id, _direction -> [] end]},
        {FacilitiesRepo, [], get_by_type: fn _types, _opts -> [] end}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page_refactor(conn, view, "Facility", "Parking issue")

        assert render_async(view) =~ ~s(id="access_service_view")
      end
    end

    @tag :logged_in_user
    test "shows correct affected service for systemwide combination", %{conn: conn} do
      with_mock(RoutePatternsRepo, by_route_id: fn _route_id, _opts -> [] end) do
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page_refactor(conn, view, "Systemwide", "Notice")

        assert render_async(view) =~ ~s(id="systemwide_service_view")
      end
    end

    @tag :logged_in_user
    test "shows correct affected service for stop route combination", %{conn: conn} do
      with_mocks([
        {StopsRepo, [], by_route: fn _, _, _opts -> [@stop] end},
        {RoutesRepo, [], [by_type: fn _type -> [@route] end, get: fn _id, _opts -> @route end]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page_refactor(conn, view, "Bus", "Stop move")

        assert render_async(view) =~ ~s(id="stop_route_service_view")
      end
    end

    @tag :logged_in_user
    test "shows correct affected service for other combination", %{conn: conn} do
      with_mocks([
        {StopsRepo, [], by_route: fn _, _, _opts -> [@stop] end},
        {RoutesRepo, [], [by_type: fn _type -> [@route] end, get: fn _id, _opts -> @route end]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page_refactor(conn, view, "Bus", "Detour")

        assert render_async(view) =~ ~s(id="service_view")
      end
    end

    @tag :logged_in_user
    test "submitting the second part of the form saves the alert", %{conn: conn} do
      with_mocks([
        {RoutePatternsRepo, [], [by_route_id: fn _route_id, _opts -> [@route_pattern] end]},
        {StopsRepo, [], [by_route: fn _, _, _opts -> [@stop] end, all: fn _, _ -> [@stop] end]},
        {RoutesRepo, [], [by_type: fn _type -> [@route] end, get: fn _id, _opts -> @route end]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/new")
        assert render_async(view) =~ ~s(id="route_view")
        view = get_to_submission_page_refactor(conn, view, "Bus", "Detour")

        assert render_async(view) =~ ~s(id="details_view")

        view
        |> element("form")
        |> render_change(%{
          alert_data: %{
            single_route_id: "1"
          }
        })

        open_review_modal(view)
        submit_alert(view)

        flash = assert_redirect(view, "/")
        assert flash["info"] =~ ~r/New alert #[0-9]+ created/
      end
    end

    @tag :logged_in_user
    test "clicking on timeline moves view back", %{conn: conn} do
      with_mocks([
        {StopsRepo, [], by_route: fn _, _, _opts -> [@stop] end},
        {RoutesRepo, [], [by_type: fn _type -> [@route] end, get: fn _id, _opts -> @route end]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page_refactor(conn, view, "Bus", "Detour")

        render_async(view)

        view
        |> element("#route_type_and_effect")
        |> render_click()

        assert render_async(view) =~ ~s(class="min-w-full flex flex-col mb-8" id="route_view")
        refute render_async(view) =~ ~s(class="min-w-full flex flex-col mt-4" id="details_view")
      end
    end

    @tag :logged_in_user
    test "displays stop names when route selected", %{conn: conn} do
      stops = [%Stop{id: "1", name: "cool stop name"}]

      with_mocks([
        {RoutesRepo, [], [by_type: fn _type -> [@route] end, get: fn _id, _opts -> @route end]},
        {StopsRepo, [], by_route: fn _route, _direction, _opts -> stops end},
        {SchedulesRepo, [], by_route_ids: fn _route_ids, _opts -> [] end}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page_refactor(conn, view, "Bus", "Detour")
        render_async(view, 1000)

        view
        |> element("form")
        |> render_change(%{
          "alert_data" => %{"single_route_id" => "CR-Worcester", "directions" => "0"}
        })

        assert render(view) =~ "cool stop name"
      end
    end

    @tag :logged_in_user
    test "displays a list of facilities and successfully saves facility alert", %{conn: conn} do
      :ELEVATOR_CLOSURE
      child_stop = %Stop{id: "3", name: "baby stop"}
      stop = %Stop{id: "2", name: "stop", child_ids: [child_stop.id]}
      facility = %Facility{id: "1", long_name: "real big elevator", stop: stop}
      facilities = [facility]

      with_mocks([
        {RoutesRepo, [], by_stop: fn _stop_id -> [%Route{id: "Blue", name: "blue route"}] end},
        {FacilitiesRepo, [],
         [get_by_type: fn _types, _opts -> facilities end, get: fn _id -> facility end]},
        {StopsRepo, [],
         get!: fn
           "2" -> stop
           "3" -> child_stop
         end,
         all: fn ["filter[id]": ""], _ -> [stop, child_stop] end}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page_refactor(conn, view, "Facility", "Elevator closure")
        render_async(view)

        assert view
               |> element("form")
               |> render_async() =~ "real big elevator"

        view
        |> element("form")
        |> render_change(%{
          "alert_data" => %{"single_facility_id" => facility.id}
        })

        open_review_modal(view)

        submit_alert(view)

        flash = assert_redirect(view, "/")
        assert flash["info"] =~ ~r/New alert #[0-9]+ created/
      end
    end

    @tag :logged_in_user
    test "redirects to the referer upon successful save", %{conn: conn} do
      :ELEVATOR_CLOSURE
      child_stop = %Stop{id: "3", name: "baby stop"}
      stop = %Stop{id: "2", name: "stop", child_ids: [child_stop.id]}
      facility = %Facility{id: "1", long_name: "real big elevator", stop: stop}

      with_mocks([
        {RoutesRepo, [], by_stop: fn _stop_id -> [%Route{id: "Blue", name: "blue route"}] end},
        {FacilitiesRepo, [],
         [get_by_type: fn _types, _opts -> [facility] end, get: fn _id -> facility end]},
        {StopsRepo, [],
         all: fn _, _ -> [stop] end,
         get!: fn
           "2" -> stop
           "3" -> child_stop
         end}
      ]) do
        conn = put_req_header(conn, "referer", "/alerts?filter[timeline]=future")

        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page_refactor(conn, view, "Facility", "Elevator closure")
        render_async(view)

        view
        |> element("form")
        |> render_change(%{
          "alert_data" => %{"single_facility_id" => facility.id}
        })

        open_review_modal(view)
        submit_alert(view)

        flash = assert_redirect(view, "/alerts?filter[timeline]=future")
        assert flash["info"] =~ ~r/New alert #[0-9]+ created/
      end
    end
  end

  describe "obsolete ids modal" do
    @tag :logged_in_user
    test "should not render at all by default", %{conn: conn} do
      # If the modal renders at all (even hidden), it will capture esc's and reroute us to the home page
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _types -> [@route] end,
           get: fn _id -> @route end,
           get: fn _id, _opts -> @route end,
           all: fn _opts -> [@route] end
         ]},
        {StopsRepo, [],
         [
           by_route: fn _route, _direction, _opts -> [@stop] end,
           get: fn _id -> @stop end
         ]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page_refactor(conn, view, "Bus", "Multi-route detour")

        refute view
               |> element("#gtfs-warning-modal")
               |> has_element?
      end
    end

    @tag :logged_in_user
    test "displays modal with obsolete ids", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _types -> [@route] end,
           get: fn _id -> @route end,
           get: fn _id, _opts -> @route end,
           all: fn _opts -> [@route] end
         ]},
        {SchedulesRepo, [],
         by_route_ids: fn _route_ids, _opts -> [] end,
         end_of_rating: fn -> Date.add(@todays_date, 7) end},
        {StopsRepo, [],
         [
           all: fn _, _ -> [@stop] end,
           by_route: fn _route, _direction, _opts -> [@stop] end,
           get_parent: fn
             "place-sstat" -> @stop
             "obsolete_stop" -> %Stop{id: "obsolete_stop", name: "spurious stop"}
           end
         ]},
        {RoutePatternsRepo, [],
         [
           by_route_id: fn _route_id, _opts -> [@route_pattern] end,
           included_stops_by_route_id: fn _route_id, _ -> [@stop] end
         ]}
      ]) do
        alert_params =
          build(:alert_map, %{
            alert_id: "123",
            effect: :OTHER_EFFECT,
            effect_detail: "DELAY",
            header_text: "cool header text",
            severity: 3,
            severity_level: :WARNING,
            cause_detail: "UNKNOWN",
            reminder_times: [],
            informed_entity: [
              %{route_type: 3, route_id: "CR-Worcester", direction_id: 0, stop_id: "place-sstat"},
              %{
                route_type: 3,
                route_id: "CR-Worcester",
                direction_id: 0,
                stop_id: "obsolete_stop"
              }
            ],
            original_route_selections: [
              "Framingham/Worcester Line|CR-Worcester",
              "spurious route|sp_rt"
            ],
            original_stop_selections: ["South Station|place-sstat", "spurious stop|obsolete_stop"]
          })

        {:ok, _} =
          Alerts.create_or_update_alert(alert_params, build(:user))

        {:ok, view, html} = live(conn, "/alerts/edit/123")

        assert html =~ ~r/Edit Alert/

        rendered_view = view |> element("#gtfs-warning-modal-content") |> render_async(1000)
        refute rendered_view =~ ~s(aria-hidden=\"true\")
        assert rendered_view =~ "spurious route [sp_rt]"
        assert rendered_view =~ "spurious stop [obsolete_stop]"
        open_review_modal(view)

        assert view |> element("#review-modal-container") |> render_async() =~
                 "Framingham/Worcester"

        assert view |> element("#review-modal-container") |> render_async() =~
                 "South Station"

        refute view |> element("#review-modal-container") |> render_async() =~
                 "spurious route"

        refute view |> element("#review-modal-container") |> render_async() =~
                 "spurious stop"

        open_review_modal(view)
        submit_alert(view)

        assert Alerts.get_by_alert_id("123").original_route_selections == [
                 "Framingham/Worcester Line|CR-Worcester"
               ]

        assert Alerts.get_by_alert_id("123").original_stop_selections == [
                 "South Station|place-sstat"
               ]
      end
    end
  end

  describe "duplicating an alert" do
    @tag :logged_in_user
    test "defaults to now/later_today when duplicating a past alert", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _types -> [@route] end,
           get: fn _id -> @route end,
           get: fn _id, _opts -> @route end,
           all: fn _opts -> [@route] end
         ]},
        {StopsRepo, [],
         [
           by_route: fn _route, _direction, _opts -> [@stop] end,
           get_parent: fn
             "place-sstat" -> @stop
             "obsolete_stop" -> %Stop{id: "obsolete_stop", name: "spurious stop"}
           end
         ]}
      ]) do
        alert_params =
          build(:alert_map, %{
            alert_id: "123",
            effect: :OTHER_EFFECT,
            effect_detail: "DELAY",
            header_text: "cool header text",
            severity: 3,
            severity_level: :WARNING,
            cause_detail: "UNKNOWN",
            reminder_times: [],
            informed_entity: [
              %{route_type: 3, route_id: "CR-Worcester", direction_id: 0, stop_id: "place-sstat"},
              %{
                route_type: 3,
                route_id: "CR-Worcester",
                direction_id: 0,
                stop_id: "obsolete_stop"
              }
            ],
            original_route_selections: [
              "Framingham/Worcester Line|CR-Worcester",
              "spurious route|sp_rt"
            ],
            original_stop_selections: ["South Station|place-sstat", "spurious stop|obsolete_stop"],
            duration_certainty: :KNOWN,
            active_period_start_specifier: :custom,
            active_period_start: ~N[2020-03-07 00:00:00],
            active_period_end_specifier: :custom,
            active_period_end: ~N[2023-03-07 23:59:59],
            closed_timestamp: ~N[2023-03-07 23:59:59]
          })

        {:ok, alert} =
          Alerts.create_or_update_alert(alert_params, build(:user))

        {:ok, view, html} = live(conn, "/alerts/duplicate/#{alert.alert_id}")

        assert html =~ ~r/Duplicate Alert/

        assert view
               |> element("#alert_data_active_period_start_specifier option[selected]")
               |> render() =~ ">Now<"

        assert view
               |> element("#alert_data_active_period_end_specifier option[selected]")
               |> render() =~ ">Later today<"

        assert view
               |> element("#alert_data_notification_specifier option[selected]")
               |> render() =~ ">Now<"
      end
    end

    @tag :logged_in_user
    test "should not change the dates when duplicating a current alert", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _types -> [@route] end,
           get: fn _id -> @route end,
           get: fn _id, _opts -> @route end,
           all: fn _opts -> [@route] end
         ]},
        {StopsRepo, [],
         [
           by_route: fn _route, _direction, _opts -> [@stop] end,
           get_parent: fn
             "place-sstat" -> @stop
             "obsolete_stop" -> %Stop{id: "obsolete_stop", name: "spurious stop"}
           end
         ]}
      ]) do
        alert_params =
          build(:alert_map, %{
            alert_id: "123",
            effect: :OTHER_EFFECT,
            effect_detail: "DELAY",
            header_text: "cool header text",
            severity: 3,
            severity_level: :WARNING,
            cause_detail: "UNKNOWN",
            reminder_times: [],
            informed_entity: [
              %{route_type: 3, route_id: "CR-Worcester", direction_id: 0, stop_id: "place-sstat"},
              %{
                route_type: 3,
                route_id: "CR-Worcester",
                direction_id: 0,
                stop_id: "obsolete_stop"
              }
            ],
            original_route_selections: [
              "Framingham/Worcester Line|CR-Worcester",
              "spurious route|sp_rt"
            ],
            original_stop_selections: ["South Station|place-sstat", "spurious stop|obsolete_stop"],
            duration_certainty: :KNOWN,
            active_period_start_specifier: :custom,
            active_period_start: ~N[2020-03-07 00:00:00],
            active_period_end_specifier: :custom,
            active_period_end: ~N[2030-03-07 23:59:59]
          })

        {:ok, alert} =
          Alerts.create_or_update_alert(alert_params, build(:user))

        {:ok, view, _html} = live(conn, "/alerts/duplicate/#{alert.alert_id}")

        assert view
               |> element("#alert_data_active_period_start_specifier option[selected]")
               |> render() =~ ">Custom<"

        assert view
               |> element("#alert_data_active_period_end_specifier option[selected]")
               |> render() =~ ">Custom<"

        assert view
               |> element("#alert_data_notification_specifier option[selected]")
               |> render() =~ ">Same as effect period<"
      end
    end
  end
end
