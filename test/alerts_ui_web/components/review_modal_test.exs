defmodule AlertsUIWeb.Components.ReviewModalTest do
  @moduledoc """
  A majority of this suite are e2e tests to verify various user
  input produces a proper review modal
  """
  use AlertsUIWeb.ConnCase, async: false

  import AlertsUI.Support.Factory
  import AlertsUI.UsersFixtures
  import Mock
  import Phoenix.Component
  import Phoenix.LiveViewTest
  import Test.Support.Helpers

  alias AlertsUI.ActivePeriodBuilder
  alias AlertsUI.Alerts
  alias AlertsUI.Models.EnhancedSchedule
  alias AlertsUIWeb.ReviewModal
  alias MBTAV3API.Facilities.Facility
  alias MBTAV3API.Facilities.Repo, as: FacilitiesRepo
  alias MBTAV3API.RoutePatterns.Repo, as: RoutePatternsRepo
  alias MBTAV3API.Routes.Repo, as: RoutesRepo
  alias MBTAV3API.Routes.Route
  alias MBTAV3API.Schedules.Repo, as: SchedulesRepo
  alias MBTAV3API.Schedules.Trip
  alias MBTAV3API.Stops.Repo, as: StopsRepo
  alias MBTAV3API.Stops.Stop

  @tomorrow_datetime DateTime.utc_now()
                     |> DateTime.shift_zone!("America/New_York")
                     |> DateTime.add(1, :day)

  @route_one %Route{
    sort_order: 1,
    id: "CR-Worcester",
    name: "Framingham/Worcester Line",
    direction_names: %{0 => "Outbound", 1 => "Inbound"}
  }
  @route_two %Route{sort_order: 2, id: "CR-Other", name: "Other Line"}
  @routes [@route_one, @route_two]
  @stop %Stop{id: "place-aqucl", name: "Aquarium"}
  @schedule %EnhancedSchedule{
    route_id: "CR-Worcester",
    trip: %Trip{id: "CR-683322-595", name: "595", direction_id: 0},
    stop: %Stop{id: "place-sstat", name: "South Station"},
    arrival_time: nil,
    departure_time: Date.utc_today() |> DateTime.new!(~T[22:00:00], "America/New_York")
  }
  @schedule_2 %EnhancedSchedule{
    route_id: "CR-Worcester",
    trip: %Trip{id: "CR-683322-595", name: "595", direction_id: 0},
    stop: %Stop{id: "place-sstat", name: "South Station"},
    arrival_time: Date.utc_today() |> DateTime.new!(~T[23:00:00], "America/New_York"),
    departure_time: nil
  }
  @facility %Facility{
    id: "349",
    type: "ESCALATOR",
    short_name: "Platform to Russell Field",
    long_name: "Alewife Escalator 349 (Platform to Russell Field)",
    stop: %Stop{
      id: "place-alfcl",
      name: "Aquarium",
      type: "stop"
    },
    latitude: 42.395428,
    longitude: -71.142483,
    properties: [
      %{name: "direction", value: "up"},
      %{name: "excludes-stop", value: 141},
      %{name: "excludes-stop", value: 9_070_061},
      %{name: "excludes-stop", value: "door-alfcl-alewife"},
      %{name: "excludes-stop", value: "door-alfcl-busway"},
      %{name: "excludes-stop", value: "door-alfcl-cambridgepark"},
      %{name: "excludes-stop", value: "door-alfcl-pathbusway"},
      %{name: "excludes-stop", value: "door-alfcl-steel"}
    ]
  }

  describe "header" do
    @tag :logged_in_user
    test "creating new alert", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _types -> @routes end,
           get: fn _ -> @route_one end,
           get: fn _, _ -> @route_one end
         ]},
        {StopsRepo, [],
         [
           by_route: fn _route, _direction, _opts -> [@stop] end,
           get: fn _ -> @stop end
         ]}
      ]) do
        # Bus Delay
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Bus", "Delay")

        fill_out_form(view, "form", %{
          alert_data: %{route_ids: ["CR-Worcester"], stop_ids: ["place-aqucl"]}
        })

        open_review_modal(view)

        assert view |> element("#review-modal-container", "Create new alert") |> has_element?
      end
    end

    @tag :logged_in_user
    test "header when editing", %{conn: conn} do
      todays_date =
        DateTime.utc_now()
        |> DateTime.shift_zone!("America/New_York")
        |> DateTime.to_date()

      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _types -> @routes end,
           get: fn _id -> @route_one end,
           get: fn _id, _opts -> @route_one end,
           all: fn _opts -> @routes end
         ]},
        {StopsRepo, [],
         [
           by_route: fn _route, _direction, _opts -> [@stop] end,
           get_parent: fn nil -> nil end
         ]},
        {SchedulesRepo, [],
         [
           by_route_ids: fn _route_ids, _opts ->
             [@schedule, @schedule_2]
           end,
           end_of_rating: fn -> Date.add(todays_date, 1) end
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
            cause_detail: "PARADE",
            reminder_times: [],
            informed_entity: [%{route_type: 3, route_id: @route_one.id, direction_id: 0}],
            original_route_selections: ["#{@route_one.name}|#{@route_one.id}"]
          })

        {:ok, _} =
          Alerts.create_or_update_alert(alert_params, build(:user))

        {:ok, view, _html} = live(conn, "/alerts/edit/123")

        open_review_modal(view)

        assert render(view) =~ ~r/Edit alert #123/s
      end
    end

    @tag :logged_in_user
    test "header when duplicating", %{conn: conn} do
      todays_date =
        DateTime.utc_now()
        |> DateTime.shift_zone!("America/New_York")
        |> DateTime.to_date()

      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _types -> @routes end,
           get: fn _id -> @route_one end,
           get: fn _id, _opts -> @route_one end,
           all: fn _opts -> @routes end
         ]},
        {StopsRepo, [],
         [
           by_route: fn _route, _direction, _opts -> [@stop] end,
           get_parent: fn nil -> nil end
         ]},
        {SchedulesRepo, [],
         [
           by_route_ids: fn _route_ids, _opts ->
             [@schedule, @schedule_2]
           end,
           end_of_rating: fn -> Date.add(todays_date, 7) end
         ]}
      ]) do
        alert_params =
          build(:alert_map, %{
            active_period_start: @tomorrow_datetime,
            active_period_end: nil,
            alert_id: "123",
            effect: :OTHER_EFFECT,
            effect_detail: "DELAY",
            header_text: "cool header text",
            severity: 3,
            severity_level: :WARNING,
            cause_detail: "PARADE",
            reminder_times: [],
            informed_entity: [%{route_type: 3, route_id: @route_one.id}],
            original_route_selections: ["#{@route_one.name}|#{@route_one.id}"]
          })

        {:ok, _} =
          Alerts.create_or_update_alert(alert_params, build(:user))

        {:ok, view, _html} = live(conn, "/alerts/duplicate/123")

        view
        |> element("form")
        |> render_change(%{
          "alert_data" => %{
            "active_period_end_specifier" => "until_further_notice"
          }
        })

        open_review_modal(view)

        assert view |> element("#review-modal-container") |> render =~ ~r/Duplicate alert #123/s
      end
    end

    @tag :logged_in_user
    test "correct mode and effect: Bus Delay", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _types -> @routes end,
           get: fn _ -> @route_one end,
           get: fn _, _ -> @route_one end
         ]},
        {StopsRepo, [],
         [
           by_route: fn _route, _direction, _opts -> [@stop] end,
           get: fn _ -> @stop end
         ]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Bus", "Delay")

        fill_out_form(view, "form", %{
          alert_data: %{route_ids: ["CR-Worcester"], stop_ids: ["place-aqucl"]}
        })

        render_async(view)

        open_review_modal(view)

        assert view |> element("#review-modal-container", "Bus • Delay") |> has_element?
      end
    end

    @tag :logged_in_user
    test "correct mode and effect: Facility", %{conn: conn} do
      with_mock(FacilitiesRepo,
        get_by_type: fn _facility_types, _opts -> [@facility] end,
        get: fn _ -> @facility end
      ) do
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Facility", "Bike issue")

        fill_out_form(view, "form", %{
          alert_data: %{
            facility_ids: ["349"]
          }
        })

        render_async(view)

        open_review_modal(view)

        assert view
               |> element("#review-modal-container", "Facility • Bike Issue")
               |> has_element?
      end
    end
  end

  describe "the affected service paradigms to make sure Routes, Stops, Trips, Direction render correctly" do
    @tag :logged_in_user
    test "RDS with no direction", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _types -> @routes end,
           get: fn _id -> @route_one end,
           get: fn _id, _opts -> @route_one end
         ]},
        {StopsRepo, [],
         [
           by_route: fn _route, _direction, _opts -> [@stop] end,
           get: fn _id -> @stop end
         ]}
      ]) do
        # Bus Delay
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Bus", "Delay")

        fill_out_form(view, "form", %{
          alert_data: %{
            route_ids: ["CR-Worcester"],
            stop_names_and_ids: ["Aquarium|place-aqucl"]
          }
        })

        open_review_modal(view)

        assert render(view) =~ ~r/Routes:.*Framingham\/Worcester Line/s
        assert render(view) =~ ~r/Stops:.*Aquarium/s
        refute render(view) =~ "Trips:"
        assert render(view) =~ ~r/Direction:.*Both/s
      end
    end

    @tag :logged_in_user
    test "RDS with direction", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _types -> @routes end,
           get: fn _id -> @route_one end,
           get: fn _id, _opts -> @route_one end
         ]},
        {StopsRepo, [],
         [
           by_route: fn _route, _direction, _opts ->
             [
               Map.put(@stop, :name, @stop.name <> "(inbound)")
             ]
           end,
           get: fn _id -> @stop end
         ]}
      ]) do
        # Bus Delay
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Bus", "Delay")

        fill_out_form(view, "form", %{
          alert_data: %{
            route_ids: ["CR-Worcester"],
            direction: "1",
            stop_names_and_ids: ["Aquarium (inbound)|place-aqucl"]
          }
        })

        open_review_modal(view)

        assert render(view) =~ ~r/Routes:.*Framingham\/Worcester Line/s
        assert render(view) =~ ~r/Stops:.*Aquarium/s
        assert render(view) =~ ~r/Direction:.*Inbound/s
        refute render(view) =~ "Trips:"
      end
    end

    @tag :logged_in_user
    test "R", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _types -> @routes end,
           get: fn _id -> @route_one end,
           get: fn _id, _opts -> @route_one end
         ]},
        {StopsRepo, [],
         [
           by_route: fn _route, _direction, _opts -> [@stop] end,
           get: fn _id -> @stop end
         ]}
      ]) do
        # Bus Extra Service
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Bus", "Extra service")

        fill_out_form(view, "form", %{
          alert_data: %{route_ids: ["CR-Worcester"]}
        })

        open_review_modal(view)

        assert render(view) =~ ~r/Routes:.*Framingham\/Worcester Line/s
        refute render(view) =~ "Stops:"
        refute render(view) =~ ~r/Direction:.*Both/s
        refute render(view) =~ "Trips:"
      end
    end

    @tag :logged_in_user
    test "SR", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _types -> @routes end,
           by_stop: fn _, _ -> @routes end,
           get: fn _id -> @route_one end,
           get: fn _id, _opts -> @route_one end
         ]},
        {StopsRepo, [],
         [
           by_route_type: fn _rt -> [@stop] end,
           by_route: fn _route, _direction -> [@stop] end,
           by_route: fn _route, _direction, _opts -> [@stop] end,
           get: fn _id -> @stop end
         ]}
      ]) do
        # Bus Stop Closure
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Bus", "Stop closure")

        fill_out_form(view, "form", %{
          alert_data: %{stop_names_and_ids: ["Aquarium|place-aqucl"], route_ids: ["CR-Worcester"]}
        })

        open_review_modal(view)

        assert view |> element("#review-modal-container") |> render =~
                 ~r/Routes:.*Framingham\/Worcester Line/s

        assert render(view) =~ ~r/Stops:.*Aquarium/s
        refute render(view) =~ "Direction:"
        refute render(view) =~ "Trips:"
      end
    end

    @tag :logged_in_user
    test "RDT", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _types -> @routes end,
           get: fn _id -> @route_one end,
           get: fn _id, _opts -> @route_one end
         ]},
        {StopsRepo, [],
         [
           by_route_type: fn _, _ -> [] end,
           by_route: fn _, _, _ -> [] end,
           by_trip: fn _trip_id -> [@stop] end
         ]},
        {SchedulesRepo, [], [by_route_ids: fn _route_ids, _opts -> [@schedule, @schedule_2] end]}
      ]) do
        # CR Cancellation
        {:ok, view, _html} = live(conn, "/alerts/new")

        view = get_to_submission_page(conn, view, "Commuter Rail", "Cancellation")

        fill_out_form(view, "form", %{
          alert_data: %{
            route_ids: ["CR-Worcester"]
          }
        })

        fill_out_form(view, "form", %{
          alert_data: %{
            direction: "0",
            trip_ids: ["CR-683322-595"]
          }
        })

        open_review_modal(view)

        assert render(view) =~ ~r/Routes:.*Framingham\/Worcester Line/s
        assert render(view) =~ ~r/Direction:.*Outbound/s

        assert view |> element("#review-modal-container") |> render =~
                 ~r/Trips:.*595 \(10:00 PM from South Station\)/s

        refute render(view) =~ "Stops:"
      end
    end

    @tag :logged_in_user
    test "RDTS", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _types -> @routes end,
           get: fn _id -> @route_one end,
           get: fn _id, _opts -> @route_one end
         ]},
        {SchedulesRepo, [],
         [
           by_route_ids: fn _route_ids, _opts -> [@schedule, @schedule_2] end
         ]},
        {StopsRepo, [],
         [
           # by_route_type: fn _rt -> [@stop] end,
           by_route: fn _route, _direction, _opts ->
             [
               Map.put(@stop, :name, @stop.name <> "(inbound)")
             ]
           end,
           get: fn _id -> @stop end,
           by_trip: fn _trip_id -> [@stop] end
         ]}
      ]) do
        # CR Delay
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Commuter Rail", "Delay")

        fill_out_form(view, "form", %{
          alert_data: %{
            route_ids: ["CR-Worcester"],
            trip_ids: ["CR-683322-595"],
            stop_names_and_ids: ["Aquarium (inbound)|place-aqucl"]
          }
        })

        render_async(view)

        open_review_modal(view)

        assert render(view) =~ ~r/Routes:.*Framingham\/Worcester Line/s
        assert render(view) =~ ~r/Direction:.*Both/s
        assert render(view) =~ ~r/Trips:.*595 \(10:00 PM from South Station\)/s
        assert render(view) =~ ~r/Stops:.*Aquarium/s
      end
    end

    @tag :logged_in_user
    test "Access", %{conn: conn} do
      with_mocks([
        {FacilitiesRepo, [],
         [
           get: fn _facility_id -> @facility end,
           get_by_type: fn _facility_types, _opts -> [@facility] end
         ]}
      ]) do
        # Access Elevator Closure
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Facility", "Elevator closure")

        fill_out_form(view, "form", %{
          alert_data: %{single_facility_id: "349"}
        })

        open_review_modal(view)

        assert render(view) =~
                 ~r/Facilities:.*Alewife Escalator 349 \(Platform to Russell Field\)/s

        refute render(view) =~ "Routes:"
        refute render(view) =~ "Stops:"
        refute render(view) =~ "Direction:"
        refute render(view) =~ "Trips:"
      end
    end

    @tag :logged_in_user
    test "Systemwide", %{conn: conn} do
      # Systemwide delay
      {:ok, view, _html} = live(conn, "/alerts/new")
      view = get_to_submission_page(conn, view, "Systemwide", "Delay")

      fill_out_form(view, "form", %{
        alert_data: %{service_types: [3, 2, 4, 1]}
      })

      open_review_modal(view)

      refute render(view) =~ "Facility:"
      refute render(view) =~ "Routes:"
      refute render(view) =~ "Stops:"
      refute render(view) =~ "Direction:"
      refute render(view) =~ "Trips:"
      assert render(view) =~ ~r/Modes:.*Bus, Commuter Rail, Ferry, Subway/s
    end
  end

  describe "timeframe fields" do
    @tag :logged_in_user
    test "default settings", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _types -> @routes end,
           get: fn _id -> @route_one end,
           get: fn _id, _opts -> @route_one end
         ]},
        {StopsRepo, [],
         [
           by_route: fn _route, _direction, _opts -> [@stop] end,
           get: fn _id -> @stop end,
           by_trip: fn _trip_id -> [@stop] end
         ]}
      ]) do
        # Bus Delay
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Bus", "Delay")

        fill_out_form(view, "form", %{
          alert_data: %{route_ids: ["CR-Worcester"], stop_ids: ["place-aqucl"]}
        })

        render_async(view)

        open_review_modal(view)

        assert view |> element("#review-modal-container") |> render =~ ~r/Timing.*One-time/s

        assert view |> element("#review-modal-container") |> render =~
                 ~r/Effect period.*until.*later today.*\(max.*hours,.*minutes\)/s

        assert view |> element("#review-modal-container") |> render =~
                 ~r/Notification period.*until.*alert is closed/s
      end
    end

    @tag :logged_in_user
    test "when work order is closed", %{conn: conn} do
      with_mocks([
        {FacilitiesRepo, [],
         [
           get: fn _type -> @facility end,
           get_by_type: fn _type, _opts -> [@facility] end
         ]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Facility", "Elevator closure")

        fill_out_form(view, "form", %{
          alert_data: %{single_facility_id: "349"}
        })

        fill_out_form(view, "form", %{
          alert_data: %{active_period_end_specifier: :when_work_order_is_closed}
        })

        render_async(view)

        open_review_modal(view)

        assert render(view) =~ ~r/Timing.*One-time/s

        assert view |> element("#review-modal-container") |> render =~
                 ~r/Effect period.*until.*a work order for this facility is closed/s

        assert render(view) =~ ~r/Notification period.*Same as effect period/s
      end
    end

    @tag :logged_in_user
    test "when work order-based alert has been closed", %{conn: conn} do
      with_mocks([
        {FacilitiesRepo, [],
         [
           get: fn _type -> @facility end,
           get_by_type: fn _type, _opts -> [@facility] end
         ]}
      ]) do
        alert_id = "T-#{System.unique_integer([:positive])}"
        now = NaiveDateTime.new!(~D[2040-02-14], ~T[12:00:00])

        {:ok, _alert} =
          Alerts.create_or_update_alert(
            %{
              alert_id: alert_id,
              source: :TRAPEZE,
              work_order_id: "310-2026-0000",
              effect: "ACCESSIBILITY_ISSUE",
              effect_detail: "ESCALATOR_CLOSURE",
              effect_name: "Escalator Closure",
              primary_service_type: "access",
              can_close_automatically: true,
              duration_certainty: :KNOWN,
              active_period_start: now,
              active_period_end: now |> NaiveDateTime.add(3, :minute),
              active_period: [%{start: now, end: now}],
              header_text: "Forest Hills Escalator 128 is out of service.",
              informed_entity: [%{facility_id: "128", activities: [:USING_ESCALATOR]}],
              severity: 3,
              last_modified_timestamp: DateTime.utc_now(),
              reminder_times: []
            },
            build(:user)
          )

        {:ok, view, _html} = live(conn, "/alerts/edit/#{alert_id}")

        open_review_modal(view)

        assert render(view) =~
                 ~r/Effect period.*Tue Feb 14, 2040 @ 7:00 AM until Tue Feb 14, 2040 @ 7:03 AM/s
      end
    end

    @tag :logged_in_user
    test "recurring timeframe", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _types -> @routes end,
           get: fn _id -> @route_one end,
           get: fn _id, _opts -> @route_one end
         ]},
        {StopsRepo, [],
         [
           by_route: fn _route, _direction, _opts -> [@stop] end,
           get: fn _id -> @stop end
         ]}
      ]) do
        # Bus Delay
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Bus", "Delay")

        fill_out_form(view, "form", %{
          alert_data: %{route_ids: ["CR-Worcester"], stop_ids: ["place-aqucl"]}
        })

        fill_out_form(view, "form", %{
          alert_data: %{
            alert_timing: :recurring,
            active_period_start_specifier: :custom
          }
        })

        # Needs to be 2 separate render_changes because of function `set_start_date` in TimeRange
        fill_out_form(view, "form", %{
          alert_data: %{
            active_period_start_date: ~D[2999-06-08],
            recurrence_days: ["saturday"]
          }
        })

        render_async(view)

        open_review_modal(view)

        assert render(view) =~ ~r/Timing.*Recurring/s

        assert render(view) =~
                 ~r/Effect period.*Sat Jun 08, 2999 until alert is manually closed.*Every Saturday/s
      end
    end

    @tag :logged_in_user
    test "custom notification period", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _types -> @routes end,
           get: fn _id -> @route_one end,
           get: fn _id, _opts -> @route_one end
         ]},
        {StopsRepo, [],
         [
           by_route: fn _route, _direction, _opts -> [@stop] end,
           get: fn _id -> @stop end
         ]}
      ]) do
        # Bus Delay
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Bus", "Delay")

        fill_out_form(view, "form", %{
          alert_data: %{route_ids: ["CR-Worcester"], stop_ids: ["place-aqucl"]}
        })

        fill_out_form(view, "form", %{
          notification_period: %{
            notification_specifier: :custom
          }
        })

        render_async(view)

        open_review_modal(view)

        assert render(view) =~ ~r/Notification period.*@.*until.*alert is closed/s
      end
    end
  end

  describe "alert details" do
    @tag :logged_in_user
    test "default settings", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _types -> @routes end,
           get: fn _id -> @route_one end,
           get: fn _id, _opts -> @route_one end
         ]},
        {StopsRepo, [],
         [
           by_route: fn _route, _direction, _opts -> [@stop] end,
           get: fn _id -> @stop end
         ]}
      ]) do
        # Bus Delay
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Bus", "Delay")

        fill_out_form(view, "form", %{
          alert_data: %{route_ids: ["CR-Worcester"], stop_ids: ["place-aqucl"]}
        })

        render_async(view)

        open_review_modal(view)

        assert render(view) =~ ~r/Cause.*None/s
        assert render(view) =~ ~r/Severity.*About 15 minutes.*\(4 - WARNING\)/s

        assert render(view) =~
                 ~r/Main message.*Framingham\/Worcester Line is experiencing delays of about 15 minutes/s

        assert render(view) =~ ~r/Supporting information.*None/s
        refute render(view) =~ ~r/>URL</s
      end
    end

    @tag :logged_in_user
    test "populate all alert details", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _types -> @routes end,
           get: fn _id -> @route_one end,
           get: fn _id, _opts -> @route_one end
         ]},
        {StopsRepo, [],
         [
           by_route: fn _route, _direction, _opts -> [@stop] end,
           get: fn _id -> @stop end
         ]}
      ]) do
        # Bus Delay
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Bus", "Delay")

        fill_out_form(view, "form", %{
          alert_data: %{route_ids: ["CR-Worcester"], stop_ids: ["place-aqucl"]}
        })

        fill_out_form(view, "form", %{
          alert_data: %{
            header_text: "hello world",
            cause_detail: "DISABLED_BUS",
            severity: 7,
            description_text: "supporting information",
            url: "http://www.fake.com"
          }
        })

        render_async(view)

        open_review_modal(view)

        assert render(view) =~ ~r{Cause.*Disabled bus}s
        assert render(view) =~ ~r{Severity.*About 30 minutes.*\(7 - SEVERE\)}s
        assert render(view) =~ ~r{Supporting information.*supporting information}s

        assert view
               |> element("p.url_label + a[href='http://www.fake.com']", ~r[http://www.fake.com])
               |> has_element?()
      end
    end
  end

  describe "image" do
    @tag :logged_in_user
    test "by default, no image", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _types -> @routes end,
           get: fn _ -> @route_one end,
           get: fn _, _ -> @route_one end
         ]},
        {StopsRepo, [],
         [
           by_route: fn _route, _direction, _opts -> [@stop] end,
           get: fn _ -> @stop end
         ]}
      ]) do
        # Bus Delay
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Bus", "Delay")

        fill_out_form(view, "form", %{
          alert_data: %{route_ids: ["CR-Worcester"], stop_ids: ["place-aqucl"]}
        })

        render_async(view)

        open_review_modal(view)

        refute view |> element("#alert-image") |> has_element?
      end
    end

    @tag :logged_in_user
    test "when image / alt text are provided", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _types -> @routes end,
           get: fn _ -> @route_one end,
           get: fn _, _ -> @route_one end
         ]},
        {StopsRepo, [],
         [
           by_route: fn _route, _direction, _opts -> [@stop] end,
           get: fn _ -> @stop end
         ]}
      ]) do
        # Bus Delay
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Bus", "Delay")

        fill_out_form(view, "form", %{
          alert_data: %{route_ids: ["CR-Worcester"], stop_ids: ["place-aqucl"]}
        })

        # Unsure how long mbta images stay archived, but I'm curious to try it!
        image_url =
          "https://cdn.mbta.com/sites/default/files/styles/max_2600x2600/public/media/2025-04/2025-04-24-red-line-may-3-4-weekend-closure.png"

        fill_out_form(view, "form", %{
          alert_data: %{
            image_url: image_url,
            image_alternative_text: "This is the alternative text"
          }
        })

        render_async(view)

        open_review_modal(view)

        assert view |> element("#alert-image") |> has_element?

        # Can't verify the measuring hook because it's JS
        assert render(view) =~ ~r/#{image_url}/s
        assert render(view) =~ ~r/Alt text:.*This is the alternative text/s
      end
    end
  end

  describe "reminders" do
    @tag :logged_in_user
    test "default", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _types -> @routes end,
           get: fn _id -> @route_one end,
           get: fn _, _ -> @route_one end
         ]},
        {StopsRepo, [],
         [
           by_route: fn _route, _direction, _opts -> [@stop] end,
           get: fn _id -> @stop end
         ]}
      ]) do
        # Bus Delay
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Bus", "Delay")

        fill_out_form(view, "form", %{
          alert_data: %{route_ids: ["CR-Worcester"], stop_ids: ["place-aqucl"]}
        })

        render_async(view)

        open_review_modal(view)

        assert render(view) =~ ~r/Reminders.*None/s
      end
    end

    @tag :logged_in_user
    test "populate some future reminders", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _types -> @routes end,
           get: fn _id -> @route_one end,
           get: fn _id, _opts -> @route_one end
         ]},
        {StopsRepo, [],
         [
           by_route: fn _route, _direction, _opts -> [@stop] end,
           get: fn _id -> @stop end
         ]}
      ]) do
        # Bus Delay
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Bus", "Delay")

        fill_out_form(view, "form", %{
          alert_data: %{route_ids: ["CR-Worcester"], stop_ids: ["place-aqucl"]}
        })

        now =
          DateTime.now!("America/New_York")
          |> DateTime.to_naive()
          |> NaiveDateTime.truncate(:second)

        tomorrow =
          now
          |> NaiveDateTime.add(1, :day)
          |> NaiveDateTime.to_date()
          |> Date.to_string()

        # There doesn't seem to be another test of rider reminders structured like this.
        # Does rider_reminders try testing multiple reminders?
        # What's the sort for?
        fill_out_form(view, "form", %{
          alert_data: %{
            "reminder_sort" => ["0", "1", "2"],
            "reminder_times" => %{
              "0" => %{
                "_persistent_id" => "0",
                "max_time" => tomorrow <> "T03:00",
                "min_time" => now,
                "reminder_time" => now |> NaiveDateTime.add(1, :minute)
              },
              "1" => %{
                "_persistent_id" => "2",
                "max_time" => tomorrow <> "T03:00",
                "min_time" => now,
                "reminder_time" => now |> NaiveDateTime.add(2, :minute)
              },
              "2" => %{
                "_persistent_id" => "3",
                "max_time" => tomorrow <> "T03:00",
                "min_time" => now,
                "reminder_time" => now |> NaiveDateTime.add(3, :minute)
              }
            }
          }
        })

        render_async(view)

        open_review_modal(view)

        # 3 scheduled reminders
        assert render(view) =~ ~r/Reminders.*Scheduled.*Scheduled.*Scheduled/s
      end
    end

    # @tag :logged_in_user
    # test "TBD populate some past reminders for an edited alert", %{conn: conn} do
    #   with_mocks([
    #     {RoutesRepo, [], [by_type: fn _types -> @routes end]},
    #     {StopsRepo, [], [by_route: fn _route, _direction, _opts -> [@stop] end]}
    #   ]) do
    #     ...
    #     assert render(view) =~ ~r/Reminders.*Sent.*Sent.*Scheduled/s
    #   end
    # end
  end

  describe "preview message" do
    @tag :logged_in_user
    test "by default, sms/email selected", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _types -> @routes end,
           get: fn _id -> @route_one end,
           get: fn _id, _opts -> @route_one end
         ]},
        {StopsRepo, [],
         [
           by_route: fn _route, _direction, _opts -> [@stop] end,
           get: fn _id -> @stop end
         ]}
      ]) do
        # Bus Delay
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Bus", "Delay")

        fill_out_form(view, "form", %{
          alert_data: %{route_ids: ["CR-Worcester"], stop_ids: ["place-aqucl"]}
        })

        render_async(view)

        open_review_modal(view)
        assert render(view) =~ ~r[Send notifications</p>\s*<p.*Yes]s
        assert render(view) =~ "Warning: Notifications will be sent to alert subscribers."
        refute render(view) =~ ~r[Web Banner Text</p>\s*<p.*Not selected]s
      end
    end

    @tag :logged_in_user
    test "web banner selected and text modified", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _types -> @routes end,
           get: fn _id -> @route_one end,
           get: fn _id, _opts -> @route_one end
         ]},
        {StopsRepo, [],
         [
           by_route: fn _route, _direction, _opts -> [@stop] end,
           get: fn _id -> @stop end
         ]}
      ]) do
        # Bus Delay
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Bus", "Delay")

        fill_out_form(view, "form", %{
          alert_data: %{route_ids: ["CR-Worcester"], stop_ids: ["place-aqucl"]}
        })

        fill_out_form(view, "form", %{
          "alert_data" => %{
            "view_banner" => true,
            "banner_sync_toggle" => false,
            "banner_text" => "Well hello there",
            "accept_banner" => true
          }
        })

        render_async(view)

        open_review_modal(view)

        assert render(view) =~ ~r[Web Banner Text</p>\s*<p.*Well hello there]s
      end
    end

    @tag :logged_in_user
    test "web banner selected and sms/email deselected", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _types -> @routes end,
           get: fn _id -> @route_one end,
           get: fn _id, _opts -> @route_one end
         ]},
        {StopsRepo, [],
         [
           by_route: fn _route, _direction, _opts -> [@stop] end,
           get: fn _id -> @stop end
         ]}
      ]) do
        # Bus Delay
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Bus", "Delay")

        fill_out_form(view, "form", %{
          alert_data: %{route_ids: ["CR-Worcester"], stop_ids: ["place-aqucl"]}
        })

        fill_out_form(view, "form", %{
          "alert_data" => %{
            "notification_toggle" => false,
            "view_banner" => true,
            "accept_banner" => true
          }
        })

        render_async(view)

        open_review_modal(view)

        assert render(view) =~
                 ~r[Web Banner Text</p>\s*<p.*Framingham/Worcester Line is experiencing delays of about 15 minutes]s
      end
    end

    @tag :logged_in_user
    test "both sms/email and web banner deselected", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _types -> @routes end,
           get: fn _id -> @route_one end,
           get: fn _id, _opts -> @route_one end
         ]},
        {StopsRepo, [],
         [
           by_route: fn _route, _direction, _opts -> [@stop] end,
           get: fn _id -> @stop end
         ]}
      ]) do
        # Bus Delay
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Bus", "Delay")

        fill_out_form(view, "form", %{
          alert_data: %{
            route_ids: ["CR-Worcester"],
            stop_ids: ["place-aqucl"],
            notification_toggle: false
          }
        })

        render_async(view)

        open_review_modal(view)

        refute render(view) =~ "Warning: Notifications will be sent to alert subscribers."
        assert render(view) =~ ~r[Send notifications</p>\s*<p.*No]s
        refute render(view) =~ ~r[Web Banner Text</p>\s*<p.*Not selected]s
      end
    end
  end

  describe "creation metadata sidebar" do
    @tag :logged_in_user
    test "default", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _types -> @routes end,
           get: fn _id -> @route_one end,
           get: fn _id, _opts -> @route_one end
         ]},
        {StopsRepo, [],
         [
           by_route: fn _route, _direction, _opts -> [@stop] end,
           get: fn _id -> @stop end
         ]}
      ]) do
        # Bus Delay
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Bus", "Delay")

        fill_out_form(view, "form", %{
          alert_data: %{route_ids: ["CR-Worcester"], stop_ids: ["place-aqucl"]}
        })

        render_async(view)

        open_review_modal(view)

        today =
          DateTime.now!("America/New_York")
          |> Calendar.strftime("%a %m/%d/%Y")

        assert render(view) =~ ~r/Created.*#{today}/s
        assert render(view) =~ ~r/Created by.*Firstname Lastname/s
        refute render(view) =~ ~r/Last edited/s
        refute render(view) =~ ~r/Last edited by/s
      end
    end

    @tag :logged_in_user
    test "creation metadata sidebar when editing", %{
      conn: conn
    } do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _types -> @routes end,
           get: fn _ -> @route_one end,
           get: fn _, _ -> @route_one end,
           all: fn _ -> @routes end
         ]},
        {StopsRepo, [],
         [
           by_route: fn _route, _direction, _opts -> [@stop] end,
           get: fn _id -> @stop end,
           get_parent: fn _id -> @stop end,
           all: fn _params, _obj -> [@stop] end
         ]},
        {RoutePatternsRepo, [],
         [
           included_stops_by_route_id: fn _route_id, _direction -> [] end,
           by_route_id: fn _route_id, _opts -> [] end
         ]}
      ]) do
        # create an alert
        user = user_fixture([:viewer, :author], %{first_name: "original", last_name: "user"})
        conn = AlertsUIWeb.ConnCase.log_in_user(conn, user)
        {:ok, view, _html} = live(conn, "/alerts/new")

        view = get_to_submission_page(conn, view, "Bus", "Delay")

        view
        |> element("form")
        |> render_change(%{
          alert_data: %{
            route_ids: [@route_one.id],
            stop_ids: [@stop.id]
          }
        })

        render_async(view)

        open_review_modal(view)

        view
        |> element("#review-modal-container button", "Submit")
        |> render_click()

        :timer.sleep(50)
        flash = assert_redirect(view, "/")

        alert_id =
          flash["info"]
          |> String.replace("New alert #", "")
          |> String.replace(" created", "")

        # edit it with a different user
        user = user_fixture([:viewer, :author], %{first_name: "second", last_name: "seconduser"})
        conn = AlertsUIWeb.ConnCase.log_in_user(conn, user)

        no_timestamp_today =
          DateTime.now!("America/New_York")
          |> Calendar.strftime("%a %m/%d/%Y")

        {:ok, view, _html} = live(conn, "/alerts/edit/#{alert_id}")

        open_review_modal(view)
        assert render(view) =~ ~r/Created.*#{no_timestamp_today}/s
        assert render(view) =~ ~r/Last edited.*#{no_timestamp_today}/s

        assert render(view) =~ ~r/Created by.*original user/s
        assert render(view) =~ ~r/Last edited by.*second seconduser/s

        # edit it a second time to check that the created_by name remains correct
        user = user_fixture([:viewer, :author], %{first_name: "final", last_name: "finaluser"})
        conn = AlertsUIWeb.ConnCase.log_in_user(conn, user)

        {:ok, view, _html} = live(conn, "/alerts/edit/#{alert_id}")

        timestamp_today =
          DateTime.now!("America/New_York")
          |> Calendar.strftime("%a %m/%d/%Y, %-I:%M %p")

        open_review_modal(view)
        assert render(view) =~ ~r/Created.*#{timestamp_today}/s
        assert render(view) =~ ~r/Last edited.*#{no_timestamp_today}/s

        assert render(view) =~ ~r/Created by.*original user/s
        assert render(view) =~ ~r/Last edited by.*final finaluser/s
      end
    end
  end

  describe "real-world bug fixes" do
    # In this case, seems that cause_detail can be empty in 2 ways; nil and empty string
    # Better typing would be good, but this is an easy bandaid
    @tag :logged_in_user
    test "can submit an edit on an alert without a cause_detail", %{conn: conn} do
      todays_date =
        DateTime.utc_now()
        |> DateTime.shift_zone!("America/New_York")
        |> DateTime.to_date()

      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _types -> @routes end,
           get: fn _id -> @route_one end,
           get: fn _id, _opts -> @route_one end,
           all: fn _opts -> @routes end
         ]},
        {StopsRepo, [],
         [
           by_route: fn _route, _direction, _opts -> [@stop] end,
           get_parent: fn nil -> nil end
         ]},
        {SchedulesRepo, [],
         [
           by_route_ids: fn _route_ids, _opts ->
             [@schedule, @schedule_2]
           end,
           end_of_rating: fn -> Date.add(todays_date, 1) end
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
            informed_entity: [%{route_type: 3, route_id: @route_one.id, direction_id: 0}],
            original_route_selections: ["#{@route_one.name}|#{@route_one.id}"]
          })

        {:ok, _} =
          Alerts.create_or_update_alert(alert_params, build(:user))

        {:ok, view, _html} = live(conn, "/alerts/edit/123")

        # Don't need to make any changes, just proceed with submitting the form

        open_review_modal(view)
        assert render(view) =~ ~r/Edit alert #123/s
      end
    end
  end

  describe "alert details variations" do
    @days_ago DateTime.utc_now()
              |> DateTime.add(-5, :day)
              |> DateTime.to_naive()
              |> NaiveDateTime.truncate(:second)

    @yesterday DateTime.utc_now()
               |> DateTime.add(-1, :day)
               |> DateTime.to_naive()
               |> NaiveDateTime.truncate(:second)

    @tomorrow DateTime.utc_now()
              |> DateTime.add(1, :day)
              |> DateTime.to_naive()
              |> NaiveDateTime.truncate(:second)

    @days_ahead DateTime.utc_now()
                |> DateTime.add(5, :day)
                |> DateTime.to_naive()
                |> NaiveDateTime.truncate(:second)

    @alert_data %{
      route_type: 2,
      effect_name: "Cancellation",
      route_ids: ["CR-Fitchburg"],
      trip_ids: ["HaverhillRestoredWKDY-744203-1418"],
      header_text:
        "Fitchburg Line train 1418 (11:01 AM from Littleton/Route 495) trip is cancelled until 1:01 PM",
      description_text: nil,
      combination: :RDT,
      alert_timing: :"one-time",
      active_period_start: nil,
      active_period_end: nil,
      active_period_start_date: nil,
      active_period_start_time: nil,
      active_period_end_date: nil,
      active_period_end_time: nil,
      active_period_end_specifier: "custom",
      active_period_start_specifier: "custom",
      cause_detail: nil,
      url: nil,
      image_url: nil,
      notification_period_start: nil,
      notification_specifier: :same_as_effect_period,
      notification_toggle: true,
      severity: 4,
      reminder_times: [],
      recurrence_days: [],
      created_timestamp: ActivePeriodBuilder.naive_eastern_datetime_to_utc(@yesterday),
      created_by: "First Last"
    }

    @assigns %{
      alert_id: 123,
      target_id: "#view_alerts_live_view",
      cancel_alert: true,
      cancel_event_name: "close_details",
      alert_data: @alert_data
    }

    test "published / current version" do
      assigns = %{
        @assigns
        | alert_data: %{
            @alert_data
            | active_period_start: @yesterday,
              active_period_end: @tomorrow
          }
      }

      rendered_modal =
        rendered_to_string(~H"""
        <ReviewModal.review_modal
          alert_id={@alert_id}
          cancel_event_name={@cancel_event_name}
          target_id={@target_id}
          cancel_alert={@cancel_alert}
          alert_data={@alert_data}
          current_user={build(:user)}
        />
        """)

      assert rendered_modal =~ "Alert #123 (Published / Current)"
      assert rendered_modal =~ ~r"<button[^>]*?>\s*?Close alert"s
      assert rendered_modal =~ "Duplicate"
      assert rendered_modal =~ "Edit this alert"
    end

    test "published / future version" do
      assigns = %{
        @assigns
        | alert_data: %{
            @alert_data
            | active_period_start: @tomorrow,
              active_period_end: @days_ahead,
              notification_period_start: @yesterday
          }
      }

      rendered_modal =
        rendered_to_string(~H"""
        <ReviewModal.review_modal
          alert_id={@alert_id}
          cancel_event_name={@cancel_event_name}
          target_id={@target_id}
          cancel_alert={@cancel_alert}
          alert_data={@alert_data}
          current_user={build(:user)}
        />
        """)

      assert rendered_modal =~ "Alert #123 (Published / Upcoming)"
      assert rendered_modal =~ ~r"<button[^>]*?>\s*?Close alert"s
      assert rendered_modal =~ "Duplicate"
      assert rendered_modal =~ "Edit this alert"
    end

    test "past version" do
      assigns = %{
        @assigns
        | alert_data: %{
            @alert_data
            | active_period_start: @days_ago,
              active_period_end: @yesterday
          }
      }

      rendered_modal =
        rendered_to_string(~H"""
        <ReviewModal.review_modal
          alert_id={@alert_id}
          cancel_event_name={@cancel_event_name}
          target_id={@target_id}
          cancel_alert={@cancel_alert}
          alert_data={@alert_data}
          current_user={build(:user)}
        />
        """)

      assert rendered_modal =~ "Alert #123 (Past)"
      refute rendered_modal =~ ~r"<button[^>]*?>\s*?Close alert"s
      refute rendered_modal =~ ~r"<button[^>]*?>\s*?Cancel alert"s
      assert rendered_modal =~ "Duplicate"
      assert rendered_modal =~ "Done"
    end

    test "future version" do
      assigns = %{
        @assigns
        | alert_data: %{
            @alert_data
            | active_period_start: @tomorrow,
              active_period_end: @days_ahead
          }
      }

      rendered_modal =
        rendered_to_string(~H"""
        <ReviewModal.review_modal
          alert_id={@alert_id}
          cancel_event_name={@cancel_event_name}
          target_id={@target_id}
          cancel_alert={@cancel_alert}
          alert_data={@alert_data}
          current_user={build(:user)}
        />
        """)

      assert rendered_modal =~ "Alert #123 (Future)"
      assert rendered_modal =~ "Cancel alert"
      assert rendered_modal =~ "Duplicate"
      assert rendered_modal =~ "Edit this alert"
    end

    test "when end is before beginning and before now (alert has been closed before it started)" do
      assigns = %{
        @assigns
        | alert_data: %{
            @alert_data
            | active_period_start: @tomorrow,
              active_period_end: @yesterday
          }
      }

      rendered_modal =
        rendered_to_string(~H"""
        <ReviewModal.review_modal
          alert_id={@alert_id}
          cancel_event_name={@cancel_event_name}
          target_id={@target_id}
          cancel_alert={@cancel_alert}
          alert_data={@alert_data}
        />
        """)

      assert rendered_modal =~ "(closed before effect start)"
    end

    test "recurring with end date" do
      assigns = %{
        @assigns
        | alert_data: %{
            @alert_data
            | active_period_start: @yesterday,
              active_period_start_date: NaiveDateTime.to_date(@yesterday),
              active_period_start_time: NaiveDateTime.to_time(@yesterday),
              active_period_end_date: NaiveDateTime.to_date(@tomorrow),
              active_period_end_time: NaiveDateTime.to_time(@tomorrow),
              alert_timing: :recurring,
              recurrence_days: ["wednesday"]
          }
      }

      rendered_modal =
        rendered_to_string(~H"""
        <ReviewModal.review_modal
          alert_id={@alert_id}
          cancel_event_name={@cancel_event_name}
          target_id={@target_id}
          cancel_alert={@cancel_alert}
          alert_data={@alert_data}
        />
        """)

      assert rendered_modal =~ "Alert #123 (Published / Current)"
    end

    test "recurring without end date" do
      assigns = %{
        @assigns
        | alert_data: %{
            @alert_data
            | active_period_start: @yesterday,
              active_period_start_date: NaiveDateTime.to_date(@yesterday),
              active_period_start_time: NaiveDateTime.to_time(@yesterday),
              active_period_end_date: nil,
              active_period_end_time: NaiveDateTime.to_time(@tomorrow),
              alert_timing: :recurring,
              recurrence_days: ["wednesday"]
          }
      }

      rendered_modal =
        rendered_to_string(~H"""
        <ReviewModal.review_modal
          alert_id={@alert_id}
          cancel_event_name={@cancel_event_name}
          target_id={@target_id}
          cancel_alert={@cancel_alert}
          alert_data={@alert_data}
        />
        """)

      assert rendered_modal =~ "Alert #123 (Published / Current)"
    end
  end
end
