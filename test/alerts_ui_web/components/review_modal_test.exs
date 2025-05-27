defmodule AletrsUIWeb.Components.ReviewModalTest do
  @moduledoc """
  A majority of this suite are e2e tests to verify various user
  input produces a proper review modal
  """
  use AlertsUIWeb.ConnCase

  import Mock
  import Phoenix.LiveViewTest
  import Test.Support.Helpers

  alias MBTAV3API.Routes.Repo, as: RoutesRepo
  alias MBTAV3API.Routes.Route
  alias MBTAV3API.Stops.Repo, as: StopsRepo
  alias MBTAV3API.Stops.Stop

  @route_one %Route{sort_order: 1, id: "1", name: "route_number_1"}
  @route_two %Route{sort_order: 2, id: "2", name: "route_number_2"}
  @routes [@route_one, @route_two]
  @stop %Stop{id: "place-aqucl", name: "Aquarium"}

  describe "the affected service paradigms to make sure Routes, Stops, Trips, Direction render correctly" do
    @tag :logged_in_user
    test "RDS with no direction", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [], [by_type: fn _types -> @routes end]},
        {StopsRepo, [], [by_route: fn _route, _direction -> [@stop] end]}
      ]) do
        # Bus Delay
        {:ok, view, _html} = live(conn, "/alerts/new")
        get_to_submission_page(view, "Bus", "Delay")

        fill_out_required_form_fields(view, %{
          affected_service: %{route_ids: ["1"], stop_ids: ["place-aqucl"]}
        })

        open_review_modal(view)

        assert render(view) =~ ~r/Routes:.*1/s
        assert render(view) =~ ~r/Stops:.*place-aqucl/s
        refute render(view) =~ "Trips:"
        refute render(view) =~ "Direction:"
      end
    end

    @tag :logged_in_user
    test "RDS with direction", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [], [by_type: fn _types -> @routes end]},
        {StopsRepo, [], [by_route: fn _route, _direction -> [@stop] end]}
      ]) do
        # Bus Delay
        {:ok, view, _html} = live(conn, "/alerts/new")
        get_to_submission_page(view, "Bus", "Delay")

        fill_out_required_form_fields(view, %{
          affected_service: %{route_ids: ["1"], direction: "1", stop_ids: ["place-aqucl"]}
        })

        open_review_modal(view)

        assert render(view) =~ ~r/Routes:.*1/s
        assert render(view) =~ ~r/Stops:.*place-aqucl/s
        assert render(view) =~ ~r/Direction:.*1/s
        refute render(view) =~ "Trips:"
      end
    end

    @tag :logged_in_user
    test "R", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [], [by_type: fn _types -> @routes end]},
        {StopsRepo, [], [by_route: fn _route, _direction -> [@stop] end]}
      ]) do
        # Bus Extra Service
        {:ok, view, _html} = live(conn, "/alerts/new")
        get_to_submission_page(view, "Bus", "Extra service")
        fill_out_required_form_fields(view, %{affected_service: %{route_ids: ["1"]}})
        open_review_modal(view)

        assert render(view) =~ ~r/Routes:.*1/s
        refute render(view) =~ "Stops:"
        refute render(view) =~ "Direction:"
        refute render(view) =~ "Trips:"
      end
    end

    @tag :logged_in_user
    test "SR", %{conn: conn} do
      # Bus Stop Closure
      {:ok, view, _html} = live(conn, "/alerts/new")
      get_to_submission_page(view, "Bus", "Stop closure")

      fill_out_required_form_fields(view, %{
        stop_route_affected_service: %{stop_ids: ["place-aqucl"], route_ids: ["1"]}
      })

      open_review_modal(view)

      assert render(view) =~ ~r/Routes:.*1/s
      assert render(view) =~ ~r/Stops:.*place-aqucl/s
      refute render(view) =~ "Direction:"
      refute render(view) =~ "Trips:"
    end

    @tag :logged_in_user
    test "RDT", %{conn: conn} do
      # CR Cancellation
      {:ok, view, _html} = live(conn, "/alerts/new")
      get_to_submission_page(view, "Commuter Rail", "Cancellation")

      fill_out_required_form_fields(view, %{
        affected_service: %{route_ids: ["1"], direction: "1", trip_ids: ["trip_1", "trip_2"]}
      })

      open_review_modal(view)

      assert render(view) =~ ~r/Routes:.*1/s
      assert render(view) =~ ~r/Direction:.*1/s
      assert render(view) =~ ~r/Trips:.*trip_1, trip_2/s
      refute render(view) =~ "Stops:"
    end

    @tag :logged_in_user
    test "RDTS", %{conn: conn} do
      # CR Delay
      {:ok, view, _html} = live(conn, "/alerts/new")
      get_to_submission_page(view, "Commuter Rail", "Delay")

      fill_out_required_form_fields(view, %{
        affected_service: %{
          route_ids: ["1"],
          direction: "1",
          trip_ids: ["trip_1", "trip_2"],
          stop_ids: ["place-aqucl"]
        }
      })

      open_review_modal(view)

      assert render(view) =~ ~r/Routes:.*1/s
      assert render(view) =~ ~r/Direction:.*1/s
      assert render(view) =~ ~r/Trips:.*trip_1, trip_2/s
      assert render(view) =~ ~r/Stops:.*place-aqucl/s
    end

    @tag :logged_in_user
    test "Access", %{conn: conn} do
      # Access Elevator Closure
      {:ok, view, _html} = live(conn, "/alerts/new")
      get_to_submission_page(view, "Access", "Elevator closure")

      fill_out_required_form_fields(view, %{access_affected_service: %{facility_id: "facility_5"}})

      open_review_modal(view)

      assert render(view) =~ ~r/Facility:.*facility_5/s
      refute render(view) =~ "Routes:"
      refute render(view) =~ "Stops:"
      refute render(view) =~ "Direction:"
      refute render(view) =~ "Trips:"
    end
  end

  describe "timeframe fields" do
    @tag :logged_in_user
    test "default settings", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [], [by_type: fn _types -> @routes end]},
        {StopsRepo, [], [by_route: fn _route, _direction -> [@stop] end]}
      ]) do
        # Bus Delay
        {:ok, view, _html} = live(conn, "/alerts/new")
        get_to_submission_page(view, "Bus", "Delay")

        fill_out_required_form_fields(view, %{
          affected_service: %{route_ids: ["1"], stop_ids: ["place-aqucl"]}
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
        {RoutesRepo, [], [by_type: fn _types -> @routes end]},
        {StopsRepo, [], [by_route: fn _route, _direction -> [@stop] end]}
      ]) do
        # Bus Delay
        {:ok, view, _html} = live(conn, "/alerts/new")
        get_to_submission_page(view, "Bus", "Delay")

        fill_out_required_form_fields(view, %{
          affected_service: %{route_ids: ["1"], stop_ids: ["place-aqucl"]}
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
        {RoutesRepo, [], [by_type: fn _types -> @routes end]},
        {StopsRepo, [], [by_route: fn _route, _direction -> [@stop] end]}
      ]) do
        # Bus Delay
        {:ok, view, _html} = live(conn, "/alerts/new")
        get_to_submission_page(view, "Bus", "Delay")

        fill_out_required_form_fields(view, %{
          affected_service: %{route_ids: ["1"], stop_ids: ["place-aqucl"]}
        })

        fill_out_form(view, "#notification_period_form", %{
          notification_period: %{
            notification_specifier: :custom
          }
        })

        open_review_modal(view)

        assert render(view) =~ ~r/Notification period.*@.*until alert is manually closed/s
      end
    end
  end

  describe "alert details" do
    @tag :logged_in_user
    test "default settings", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [], [by_type: fn _types -> @routes end]},
        {StopsRepo, [], [by_route: fn _route, _direction -> [@stop] end]}
      ]) do
        # Bus Delay
        {:ok, view, _html} = live(conn, "/alerts/new")
        get_to_submission_page(view, "Bus", "Delay")

        fill_out_required_form_fields(view, %{
          affected_service: %{route_ids: ["1"], stop_ids: ["place-aqucl"]}
        })

        open_review_modal(view)

        assert render(view) =~ ~r/Cause.*None/s
        assert render(view) =~ ~r/Severity.*Up to 15 minutes.*\(4 - WARNING\)/s
        assert render(view) =~ ~r/Main message.*hello world/s
        assert render(view) =~ ~r/Supporting information.*None/s
        refute render(view) =~ ~r/URL:/s
      end
    end

    @tag :logged_in_user
    test "populate all alert details", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [], [by_type: fn _types -> @routes end]},
        {StopsRepo, [], [by_route: fn _route, _direction -> [@stop] end]}
      ]) do
        # Bus Delay
        {:ok, view, _html} = live(conn, "/alerts/new")
        get_to_submission_page(view, "Bus", "Delay")

        fill_out_required_form_fields(view, %{
          affected_service: %{route_ids: ["1"], stop_ids: ["place-aqucl"]}
        })

        fill_out_form(view, "#details_form", %{
          alert_details: %{
            header_text: "hello world",
            cause_detail: "ACCIDENT",
            severity: 7,
            description_text: "supporting information",
            url: "http://www.fake.com"
          }
        })

        open_review_modal(view)

        assert render(view) =~ ~r/Cause.*Accident/s
        assert render(view) =~ ~r/Severity.*Up to 30 minutes.*\(7 - SEVERE\)/s
        assert render(view) =~ ~r/Supporting information.*supporting information/s
        assert render(view) =~ ~r/URL: http:\/\/www.fake.com/s
      end
    end
  end

  describe "reminders" do
    @tag :logged_in_user
    test "default", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [], [by_type: fn _types -> @routes end]},
        {StopsRepo, [], [by_route: fn _route, _direction -> [@stop] end]}
      ]) do
        # Bus Delay
        {:ok, view, _html} = live(conn, "/alerts/new")
        get_to_submission_page(view, "Bus", "Delay")

        fill_out_required_form_fields(view, %{
          affected_service: %{route_ids: ["1"], stop_ids: ["place-aqucl"]}
        })

        open_review_modal(view)

        assert render(view) =~ ~r/Reminders.*None/s
      end
    end

    @tag :logged_in_user
    test "populate some future reminders", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [], [by_type: fn _types -> @routes end]},
        {StopsRepo, [], [by_route: fn _route, _direction -> [@stop] end]}
      ]) do
        # Bus Delay
        {:ok, view, _html} = live(conn, "/alerts/new")
        get_to_submission_page(view, "Bus", "Delay")

        fill_out_required_form_fields(view, %{
          affected_service: %{route_ids: ["1"], stop_ids: ["place-aqucl"]}
        })

        now =
          DateTime.now!("America/New_York")
          |> DateTime.to_naive()
          |> NaiveDateTime.truncate(:second)

        # Assumes we're running the test during normal business hours
        # or at least not past midnight on the current service day
        # Janky? Yes. It's what I could figure out right now, lol
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
        {RoutesRepo, [], [by_type: fn _types -> @routes end]},
        {StopsRepo, [], [by_route: fn _route, _direction -> [@stop] end]}
      ]) do
        # Bus Delay
        {:ok, view, _html} = live(conn, "/alerts/new")
        get_to_submission_page(view, "Bus", "Delay")

        fill_out_required_form_fields(view, %{
          affected_service: %{route_ids: ["1"], stop_ids: ["place-aqucl"]}
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
        {RoutesRepo, [], [by_type: fn _types -> @routes end]},
        {StopsRepo, [], [by_route: fn _route, _direction -> [@stop] end]}
      ]) do
        # Bus Delay
        {:ok, view, _html} = live(conn, "/alerts/new")
        get_to_submission_page(view, "Bus", "Delay")

        fill_out_required_form_fields(view, %{
          affected_service: %{route_ids: ["1"], stop_ids: ["place-aqucl"]}
        })

        fill_out_form(view, "#delivery_form", %{
          "delivery" => %{
            "view_banner" => true,
            "banner_sync_toggle" => false,
            "banner_text" => "Well hello there",
            # No other tests for the app use `accept_banner`, why?
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
        {RoutesRepo, [], [by_type: fn _types -> @routes end]},
        {StopsRepo, [], [by_route: fn _route, _direction -> [@stop] end]}
      ]) do
        # Bus Delay
        {:ok, view, _html} = live(conn, "/alerts/new")
        get_to_submission_page(view, "Bus", "Delay")

        fill_out_required_form_fields(view, %{
          affected_service: %{route_ids: ["1"], stop_ids: ["place-aqucl"]}
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
        assert render(view) =~ ~r/Web Banner.*hello world/s
      end
    end

    @tag :logged_in_user
    test "both sms/email and web banner deselected", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [], [by_type: fn _types -> @routes end]},
        {StopsRepo, [], [by_route: fn _route, _direction -> [@stop] end]}
      ]) do
        # Bus Delay
        {:ok, view, _html} = live(conn, "/alerts/new")
        get_to_submission_page(view, "Bus", "Delay")

        fill_out_required_form_fields(view, %{
          affected_service: %{route_ids: ["1"], stop_ids: ["place-aqucl"]}
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
        {RoutesRepo, [], [by_type: fn _types -> @routes end]},
        {StopsRepo, [], [by_route: fn _route, _direction -> [@stop] end]}
      ]) do
        # Bus Delay
        {:ok, view, _html} = live(conn, "/alerts/new")
        get_to_submission_page(view, "Bus", "Delay")

        fill_out_required_form_fields(view, %{
          affected_service: %{route_ids: ["1"], stop_ids: ["place-aqucl"]}
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
end
