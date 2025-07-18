defmodule AletrsUIWeb.Components.ReviewModalTest do
  @moduledoc """
  A majority of this suite are e2e tests to verify various user
  input produces a proper review modal
  """
  use AlertsUIWeb.ConnCase

  import AlertsUI.Support.Factory
  import Mock
  import Phoenix.LiveViewTest
  import Test.Support.Helpers

  alias AlertsUI.Models.EnhancedSchedule
  alias MBTAV3API.Facilities.Facility
  alias MBTAV3API.Facilities.Repo, as: FacilitiesRepo
  alias MBTAV3API.Routes.Repo, as: RoutesRepo
  alias MBTAV3API.Routes.Route
  alias MBTAV3API.Schedules.Repo, as: SchedulesRepo
  alias MBTAV3API.Schedules.Trip
  alias MBTAV3API.Stops.Repo, as: StopsRepo
  alias MBTAV3API.Stops.Stop

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
           get: fn _ -> @route_one end
         ]},
        {StopsRepo, [],
         [
           by_route: fn _route, _direction -> [@stop] end,
           get: fn _ -> @stop end
         ]}
      ]) do
        # Bus Delay
        {:ok, view, _html} = live(conn, "/alerts/new")
        get_to_submission_page(view, "Bus", "Delay")

        fill_out_required_form_fields(view, %{
          affected_service: %{route_ids: ["CR-Worcester"], stop_ids: ["place-aqucl"]}
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
           all: fn _opts -> @routes end
         ]},
        {StopsRepo, [],
         [
           by_route: fn _route, _direction -> [@stop] end,
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
        insert(:alert, %{
          alert_id: "123",
          effect: :SIGNIFICANT_DELAYS,
          effect_detail: "DELAY",
          header_text: "cool header text",
          severity: 3,
          severity_level: :WARNING,
          cause_detail: "PARADE",
          reminder_times: [],
          informed_entity: [%{route_type: 3, route_id: "1"}],
          original_route_selections: ["1", "2", "3"]
        })

        {:ok, view, _html} = live(conn, "/alerts/edit?alert_id=123")

        # Don't need to make any changes, just proceed with submitting the form

        open_review_modal(view)

        assert render(view) =~ ~r/Edit alert #123/s
      end
    end

    @tag :logged_in_user
    test "correct mode and effect: Bus Delay", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _types -> @routes end,
           get: fn _ -> @route_one end
         ]},
        {StopsRepo, [],
         [
           by_route: fn _route, _direction -> [@stop] end,
           get: fn _ -> @stop end
         ]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/new")
        get_to_submission_page(view, "Bus", "Delay")

        fill_out_required_form_fields(view, %{
          affected_service: %{route_ids: ["CR-Worcester"], stop_ids: ["place-aqucl"]}
        })

        open_review_modal(view)

        assert view |> element("#review-modal-container", "Bus • Delay") |> has_element?
      end
    end

    @tag :logged_in_user
    test "correct mode and effect: Systemwide Suspension", %{conn: conn} do
      with_mock(FacilitiesRepo,
        get_by_type: fn _facility_types, _opts -> [@facility] end,
        get: fn _ -> @facility end
      ) do
        {:ok, view, _html} = live(conn, "/alerts/new")
        get_to_submission_page(view, "Access", "Elevator closure")

        fill_out_form(view, "#service_form", %{
          access_affected_service: %{
            facility_id: "349"
          }
        })

        fill_out_form(view, "#details_form", %{
          alert_details: %{header_text: "hello world"}
        })

        open_review_modal(view)

        assert view
               |> element("#review-modal-container", "Access • Elevator Closure")
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
           get: fn _id -> @route_one end
         ]},
        {StopsRepo, [],
         [
           by_route: fn _route, _direction -> [@stop] end,
           get: fn _id -> @stop end
         ]}
      ]) do
        # Bus Delay
        {:ok, view, _html} = live(conn, "/alerts/new")
        get_to_submission_page(view, "Bus", "Delay")

        fill_out_required_form_fields(view, %{
          affected_service: %{route_ids: ["CR-Worcester"], stop_ids: ["place-aqucl"]}
        })

        open_review_modal(view)

        assert render(view) =~ ~r/Routes:.*Framingham\/Worcester Line/s
        assert render(view) =~ ~r/Stops:.*Aquarium/s
        refute render(view) =~ "Trips:"
        refute render(view) =~ "Direction:"
      end
    end

    @tag :logged_in_user
    test "RDS with direction", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _types -> @routes end,
           get: fn _id -> @route_one end
         ]},
        {StopsRepo, [],
         [
           by_route: fn _route, _direction -> [@stop] end,
           get: fn _id -> @stop end
         ]}
      ]) do
        # Bus Delay
        {:ok, view, _html} = live(conn, "/alerts/new")
        get_to_submission_page(view, "Bus", "Delay")

        fill_out_required_form_fields(view, %{
          affected_service: %{
            route_ids: ["CR-Worcester"],
            direction: "1",
            stop_ids: ["place-aqucl"]
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
           get: fn _id -> @route_one end
         ]},
        {StopsRepo, [],
         [
           by_route: fn _route, _direction -> [@stop] end,
           get: fn _id -> @stop end
         ]}
      ]) do
        # Bus Extra Service
        {:ok, view, _html} = live(conn, "/alerts/new")
        get_to_submission_page(view, "Bus", "Extra service")
        fill_out_required_form_fields(view, %{affected_service: %{route_ids: ["CR-Worcester"]}})
        open_review_modal(view)

        assert render(view) =~ ~r/Routes:.*Framingham\/Worcester Line/s
        refute render(view) =~ "Stops:"
        refute render(view) =~ "Direction:"
        refute render(view) =~ "Trips:"
      end
    end

    @tag :logged_in_user
    test "SR", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _types -> @routes end,
           get: fn _id -> @route_one end
         ]},
        {StopsRepo, [],
         [
           by_route_type: fn _rt -> [@stop] end,
           by_route: fn _route, _direction -> [@stop] end,
           get: fn _id -> @stop end
         ]}
      ]) do
        # Bus Stop Closure
        {:ok, view, _html} = live(conn, "/alerts/new")
        get_to_submission_page(view, "Bus", "Stop closure")

        fill_out_required_form_fields(view, %{
          stop_route_affected_service: %{stop_ids: ["place-aqucl"], route_ids: ["CR-Worcester"]}
        })

        open_review_modal(view)

        assert render(view) =~ ~r/Routes:.*Framingham\/Worcester Line/s
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
           get: fn _id -> @route_one end
         ]},
        {SchedulesRepo, [], [by_route_ids: fn _route_ids, _opts -> [@schedule, @schedule_2] end]}
      ]) do
        # CR Cancellation
        {:ok, view, _html} = live(conn, "/alerts/new")
        get_to_submission_page(view, "Commuter Rail", "Cancellation")

        fill_out_required_form_fields(view, %{
          affected_service: %{
            route_ids: ["CR-Worcester"],
            direction: "1",
            trip_ids: ["CR-683322-595"]
          }
        })

        # needed for populating trip names
        send(view.pid, {:selected_schedules, [@schedule]})

        open_review_modal(view)

        assert render(view) =~ ~r/Routes:.*Framingham\/Worcester Line/s
        assert render(view) =~ ~r/Direction:.*Inbound/s
        assert render(view) =~ ~r/Trips:.*595 \(10:00 PM from South Station\)/s
        refute render(view) =~ "Stops:"
      end
    end

    @tag :logged_in_user
    test "RDTS", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _types -> @routes end,
           get: fn _id -> @route_one end
         ]},
        {SchedulesRepo, [], [by_route_ids: fn _route_ids, _opts -> [@schedule, @schedule_2] end]},
        {StopsRepo, [],
         [
           # by_route_type: fn _rt -> [@stop] end,
           by_route: fn _route, _direction -> [@stop] end,
           get: fn _id -> @stop end
         ]}
      ]) do
        # CR Delay
        {:ok, view, _html} = live(conn, "/alerts/new")
        get_to_submission_page(view, "Commuter Rail", "Delay")

        fill_out_required_form_fields(view, %{
          affected_service: %{
            route_ids: ["CR-Worcester"],
            direction: "1",
            trip_ids: ["CR-683322-595"],
            stop_ids: ["place-aqucl"]
          }
        })

        # needed for populating trip names
        send(view.pid, {:selected_schedules, [@schedule]})

        open_review_modal(view)

        assert render(view) =~ ~r/Routes:.*Framingham\/Worcester Line/s
        assert render(view) =~ ~r/Direction:.*Inbound/s
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
        get_to_submission_page(view, "Access", "Elevator closure")

        fill_out_required_form_fields(view, %{access_affected_service: %{facility_id: "349"}})

        open_review_modal(view)

        assert render(view) =~ ~r/Facility:.*Alewife Escalator 349 \(Platform to Russell Field\)/s
        refute render(view) =~ "Routes:"
        refute render(view) =~ "Stops:"
        refute render(view) =~ "Direction:"
        refute render(view) =~ "Trips:"
      end
    end
  end

  describe "timeframe fields" do
    @tag :logged_in_user
    test "default settings", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _types -> @routes end,
           get: fn _id -> @route_one end
         ]},
        {StopsRepo, [],
         [
           by_route: fn _route, _direction -> [@stop] end,
           get: fn _id -> @stop end
         ]}
      ]) do
        # Bus Delay
        {:ok, view, _html} = live(conn, "/alerts/new")
        get_to_submission_page(view, "Bus", "Delay")

        fill_out_required_form_fields(view, %{
          affected_service: %{route_ids: ["CR-Worcester"], stop_ids: ["place-aqucl"]}
        })

        open_review_modal(view)

        assert render(view) =~ ~r/Timing.*One-time/s
        assert render(view) =~ ~r/Effect period.*until later today.*\(max.*hours,.*minutes\)/s
        assert render(view) =~ ~r/Notification period.*Same as effect period/s
      end
    end

    @tag :logged_in_user
    test "recurring timeframe", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _types -> @routes end,
           get: fn _id -> @route_one end
         ]},
        {StopsRepo, [],
         [
           by_route: fn _route, _direction -> [@stop] end,
           get: fn _id -> @stop end
         ]}
      ]) do
        # Bus Delay
        {:ok, view, _html} = live(conn, "/alerts/new")
        get_to_submission_page(view, "Bus", "Delay")

        fill_out_required_form_fields(view, %{
          affected_service: %{route_ids: ["CR-Worcester"], stop_ids: ["place-aqucl"]}
        })

        fill_out_form(view, "#time_range_form", %{
          time_range: %{
            alert_timing: :recurring,
            active_period_start_specifier: :custom
          }
        })

        # Needs to be 2 separate render_changes because of function `set_start_date` in TimeRange
        fill_out_form(view, "#time_range_form", %{
          time_range: %{
            active_period_start_date: ~D[2999-06-08],
            recurrence_days: ["saturday"]
          }
        })

        open_review_modal(view)

        assert render(view) =~ ~r/Timing.*Recurring/s
        assert render(view) =~ ~r/Effect period.*every Saturday.*until alert is manually closed/s
      end
    end

    @tag :logged_in_user
    test "custom notification period", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _types -> @routes end,
           get: fn _id -> @route_one end
         ]},
        {StopsRepo, [],
         [
           by_route: fn _route, _direction -> [@stop] end,
           get: fn _id -> @stop end
         ]}
      ]) do
        # Bus Delay
        {:ok, view, _html} = live(conn, "/alerts/new")
        get_to_submission_page(view, "Bus", "Delay")

        fill_out_required_form_fields(view, %{
          affected_service: %{route_ids: ["CR-Worcester"], stop_ids: ["place-aqucl"]}
        })

        fill_out_form(view, "#notification_period_form", %{
          notification_period: %{
            notification_specifier: :custom
          }
        })

        open_review_modal(view)

        assert render(view) =~ ~r/Notification period.*@.*until alert is closed/s
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
           get: fn _id -> @route_one end
         ]},
        {StopsRepo, [],
         [
           by_route: fn _route, _direction -> [@stop] end,
           get: fn _id -> @stop end
         ]}
      ]) do
        # Bus Delay
        {:ok, view, _html} = live(conn, "/alerts/new")
        get_to_submission_page(view, "Bus", "Delay")

        fill_out_required_form_fields(view, %{
          affected_service: %{route_ids: ["CR-Worcester"], stop_ids: ["place-aqucl"]}
        })

        open_review_modal(view)

        assert render(view) =~ ~r/Cause.*None/s
        assert render(view) =~ ~r/Severity.*About 15 minutes.*\(4 - WARNING\)/s

        assert render(view) =~
                 ~r/Main message.*Framingham\/Worcester Line is experiencing delays of about 15 minutes/s

        assert render(view) =~ ~r/Supporting information.*None/s
        refute render(view) =~ ~r/URL:/s
      end
    end

    @tag :logged_in_user
    test "populate all alert details", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _types -> @routes end,
           get: fn _id -> @route_one end
         ]},
        {StopsRepo, [],
         [
           by_route: fn _route, _direction -> [@stop] end,
           get: fn _id -> @stop end
         ]}
      ]) do
        # Bus Delay
        {:ok, view, _html} = live(conn, "/alerts/new")
        get_to_submission_page(view, "Bus", "Delay")

        fill_out_required_form_fields(view, %{
          affected_service: %{route_ids: ["CR-Worcester"], stop_ids: ["place-aqucl"]}
        })

        fill_out_form(view, "#details_form", %{
          alert_details: %{
            header_text: "hello world",
            cause_detail: "DISABLED_BUS",
            severity: 7,
            description_text: "supporting information",
            url: "http://www.fake.com"
          }
        })

        open_review_modal(view)

        assert render(view) =~ ~r/Cause.*Disabled bus/s
        assert render(view) =~ ~r/Severity.*About 30 minutes.*\(7 - SEVERE\)/s
        assert render(view) =~ ~r/Supporting information.*supporting information/s
        assert render(view) =~ ~r/URL: http:\/\/www.fake.com/s
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
           get: fn _ -> @route_one end
         ]},
        {StopsRepo, [],
         [
           by_route: fn _route, _direction -> [@stop] end,
           get: fn _ -> @stop end
         ]}
      ]) do
        # Bus Delay
        {:ok, view, _html} = live(conn, "/alerts/new")
        get_to_submission_page(view, "Bus", "Delay")

        fill_out_required_form_fields(view, %{
          affected_service: %{route_ids: ["CR-Worcester"], stop_ids: ["place-aqucl"]}
        })

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
           get: fn _ -> @route_one end
         ]},
        {StopsRepo, [],
         [
           by_route: fn _route, _direction -> [@stop] end,
           get: fn _ -> @stop end
         ]}
      ]) do
        # Bus Delay
        {:ok, view, _html} = live(conn, "/alerts/new")
        get_to_submission_page(view, "Bus", "Delay")

        fill_out_required_form_fields(view, %{
          affected_service: %{route_ids: ["CR-Worcester"], stop_ids: ["place-aqucl"]}
        })

        # Unsure how long mbta images stay archived, but I'm curious to try it!
        image_url =
          "https://cdn.mbta.com/sites/default/files/styles/max_2600x2600/public/media/2025-04/2025-04-24-red-line-may-3-4-weekend-closure.png"

        fill_out_form(view, "#details_form", %{
          alert_details: %{
            image_url: image_url,
            image_alternative_text: "This is the alternative text"
          }
        })

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
           get: fn _id -> @route_one end
         ]},
        {StopsRepo, [],
         [
           by_route: fn _route, _direction -> [@stop] end,
           get: fn _id -> @stop end
         ]}
      ]) do
        # Bus Delay
        {:ok, view, _html} = live(conn, "/alerts/new")
        get_to_submission_page(view, "Bus", "Delay")

        fill_out_required_form_fields(view, %{
          affected_service: %{route_ids: ["CR-Worcester"], stop_ids: ["place-aqucl"]}
        })

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
           get: fn _id -> @route_one end
         ]},
        {StopsRepo, [],
         [
           by_route: fn _route, _direction -> [@stop] end,
           get: fn _id -> @stop end
         ]}
      ]) do
        # Bus Delay
        {:ok, view, _html} = live(conn, "/alerts/new")
        get_to_submission_page(view, "Bus", "Delay")

        fill_out_required_form_fields(view, %{
          affected_service: %{route_ids: ["CR-Worcester"], stop_ids: ["place-aqucl"]}
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
        fill_out_form(view, "#rider_reminder_form", %{
          rider_reminders: %{
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

        open_review_modal(view)

        # 3 scheduled reminders
        assert render(view) =~ ~r/Reminders.*Scheduled.*Scheduled.*Scheduled/s
      end
    end

    # @tag :logged_in_user
    # test "TBD populate some past reminders for an edited alert", %{conn: conn} do
    #   with_mocks([
    #     {RoutesRepo, [], [by_type: fn _types -> @routes end]},
    #     {StopsRepo, [], [by_route: fn _route, _direction -> [@stop] end]}
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
           get: fn _id -> @route_one end
         ]},
        {StopsRepo, [],
         [
           by_route: fn _route, _direction -> [@stop] end,
           get: fn _id -> @stop end
         ]}
      ]) do
        # Bus Delay
        {:ok, view, _html} = live(conn, "/alerts/new")
        get_to_submission_page(view, "Bus", "Delay")

        fill_out_required_form_fields(view, %{
          affected_service: %{route_ids: ["CR-Worcester"], stop_ids: ["place-aqucl"]}
        })

        open_review_modal(view)

        assert render(view) =~ ~r/SMS.*To be populated when we build this out later/s
        assert render(view) =~ ~r/Email.*To be populated when we build this out later/s
        assert render(view) =~ ~r/Web Banner.*Not selected/s
      end
    end

    @tag :logged_in_user
    test "web banner selected and text modified", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _types -> @routes end,
           get: fn _id -> @route_one end
         ]},
        {StopsRepo, [],
         [
           by_route: fn _route, _direction -> [@stop] end,
           get: fn _id -> @stop end
         ]}
      ]) do
        # Bus Delay
        {:ok, view, _html} = live(conn, "/alerts/new")
        get_to_submission_page(view, "Bus", "Delay")

        fill_out_required_form_fields(view, %{
          affected_service: %{route_ids: ["CR-Worcester"], stop_ids: ["place-aqucl"]}
        })

        fill_out_form(view, "#delivery_form", %{
          "delivery" => %{
            "view_banner" => true,
            "banner_sync_toggle" => false,
            "banner_text" => "Well hello there",
            "accept_banner" => true
          }
        })

        open_review_modal(view)

        assert render(view) =~ ~r/SMS.*To be populated when we build this out later/s
        assert render(view) =~ ~r/Email.*To be populated when we build this out later/s
        assert render(view) =~ ~r/Web Banner.*Well hello there/s
      end
    end

    @tag :logged_in_user
    test "web banner selected and sms/email deselected", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _types -> @routes end,
           get: fn _id -> @route_one end
         ]},
        {StopsRepo, [],
         [
           by_route: fn _route, _direction -> [@stop] end,
           get: fn _id -> @stop end
         ]}
      ]) do
        # Bus Delay
        {:ok, view, _html} = live(conn, "/alerts/new")
        get_to_submission_page(view, "Bus", "Delay")

        fill_out_required_form_fields(view, %{
          affected_service: %{route_ids: ["CR-Worcester"], stop_ids: ["place-aqucl"]}
        })

        fill_out_form(view, "#delivery_form", %{
          "delivery" => %{
            "notification_toggle" => false,
            "view_banner" => true,
            "accept_banner" => true
          }
        })

        open_review_modal(view)

        assert render(view) =~ ~r/SMS.*Not selected/s
        assert render(view) =~ ~r/Email.*Not selected/s

        assert render(view) =~
                 ~r/Web Banner.*Framingham\/Worcester Line is experiencing delays of about 15 minutes/s
      end
    end

    @tag :logged_in_user
    test "both sms/email and web banner deselected", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _types -> @routes end,
           get: fn _id -> @route_one end
         ]},
        {StopsRepo, [],
         [
           by_route: fn _route, _direction -> [@stop] end,
           get: fn _id -> @stop end
         ]}
      ]) do
        # Bus Delay
        {:ok, view, _html} = live(conn, "/alerts/new")
        get_to_submission_page(view, "Bus", "Delay")

        fill_out_required_form_fields(view, %{
          affected_service: %{route_ids: ["CR-Worcester"], stop_ids: ["place-aqucl"]}
        })

        open_review_modal(view)

        assert render(view) =~ ~r/SMS.*Not selected/s
        assert render(view) =~ ~r/Email.*Not selected/s
        assert render(view) =~ ~r/Web Banner.*Not selected/s
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
           get: fn _id -> @route_one end
         ]},
        {StopsRepo, [],
         [
           by_route: fn _route, _direction -> [@stop] end,
           get: fn _id -> @stop end
         ]}
      ]) do
        # Bus Delay
        {:ok, view, _html} = live(conn, "/alerts/new")
        get_to_submission_page(view, "Bus", "Delay")

        fill_out_required_form_fields(view, %{
          affected_service: %{route_ids: ["CR-Worcester"], stop_ids: ["place-aqucl"]}
        })

        open_review_modal(view)

        today = Date.utc_today()

        assert render(view) =~ ~r/Created.*#{today}/s
        assert render(view) =~ ~r/Created by.*TO BE DONE/s
        assert render(view) =~ ~r/Last edited.*TO BE DONE/s
        assert render(view) =~ ~r/Last edited by.*TO BE DONE/s
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
           all: fn _opts -> @routes end
         ]},
        {StopsRepo, [],
         [
           by_route: fn _route, _direction -> [@stop] end,
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
        insert(:alert, %{
          alert_id: "123",
          effect: :SIGNIFICANT_DELAYS,
          effect_detail: "DELAY",
          header_text: "cool header text",
          severity: 3,
          severity_level: :WARNING,
          cause_detail: "UNKNOWN",
          reminder_times: [],
          informed_entity: [%{route_type: 3, route_id: "1", direction_id: 0}],
          original_route_selections: ["1", "2", "3"]
        })

        {:ok, view, _html} = live(conn, "/alerts/edit?alert_id=123")

        # Don't need to make any changes, just proceed with submitting the form

        open_review_modal(view)
        assert render(view) =~ ~r/Edit alert #123/s
      end
    end
  end
end
