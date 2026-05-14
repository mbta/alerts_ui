defmodule AlertsUIWeb.CreateAlertMonoLive.Slices.AlertDetailsSliceTest do
  use ExUnit.Case, async: false
  use AlertsUIWeb.ConnCase
  import AlertsUI.Support.Factory
  import Ecto.Changeset
  import Phoenix.LiveViewTest
  import Mock
  import Test.Support.Helpers
  alias AlertsUIWeb.CreateAlertMonoLive.Slices.AlertDetailsSlice
    alias AlertsUI.Alerts
  alias AlertsUI.Models.EnhancedSchedule
  alias AlertsUIWeb.FormComponents.AlertDetails
  alias AlertsUIWeb.FormComponents.Helpers.DateTimeFormatters
  alias AlertsUIWeb.Step
  alias MBTAV3API.Facilities.Facility
  alias MBTAV3API.Facilities.Repo, as: FacilitiesRepo
  alias MBTAV3API.Routes.Repo, as: RoutesRepo
  alias MBTAV3API.Routes.Route
  alias MBTAV3API.Schedules.Repo, as: SchedulesRepo
  alias MBTAV3API.Schedules.Trip
  alias MBTAV3API.Stops.Repo, as: StopsRepo
  alias MBTAV3API.Stops.Stop

    @todays_date DateTime.utc_now()
               |> DateTime.shift_zone!("America/New_York")
               |> DateTime.to_date()

  @tomorrows_date Date.add(@todays_date, 1)

  @start_time @tomorrows_date
              |> NaiveDateTime.new!(~T[06:00:00])

  @end_time @todays_date
            |> Date.add(2)
            |> NaiveDateTime.new!(~T[00:00:00])

  @schedule %EnhancedSchedule{
    route: %Route{id: "CR-Worcester", type: 2, name: "Framingham/Worcester Line"},
    trip: %Trip{id: "CR-683322-595", name: "595", direction_id: 1},
    stop: %Stop{id: "place-sstat", name: "South Station"},
    arrival_time: nil,
    departure_time:
      DateTime.utc_now() |> DateTime.shift_zone!("America/New_York") |> DateTime.add(1, :day)
  }

  @schedule_2 %EnhancedSchedule{
    route: %Route{id: "CR-Worcester", type: 2, name: "Framingham/Worcester Line"},
    trip: %Trip{id: "CR-683322-595", name: "595", direction_id: 1},
    stop: %Stop{id: "place-sstat", name: "South Station"},
    arrival_time:
      DateTime.utc_now()
      |> DateTime.shift_zone!("America/New_York")
      |> DateTime.add(1, :day)
      |> DateTime.add(1, :hour),
    departure_time: nil
  }

  @route %Route{
    direction_names: %{0 => "Westbound", 1 => "Eastbound"},
    sort_order: 3,
    id: "CR-Worcester",
    type: 2,
    name: "Framingham/Worcester Line"
  }

  @stop %Stop{id: "place-sstat", name: "South Station"}
  @stop_2 %Stop{id: "place-crtst", name: "Courthouse"}
  @stop_3 %Stop{id: "place-masta", name: "Massachusetts Avenue"}

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
    properties: [
      %{name: "direction", value: "up"},
      %{name: "alternate-service-text", value: "the elevator broke i'm sorry"},
      %{name: "excludes-stop", value: "door-alfcl-alewife"}
    ]
  }

    describe "component" do
    @tag :logged_in_user
    test "renders", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/mono/new")
      get_to_submission_page_refactor(view, "Ferry", "Delay")
      assert render(view) =~ ~s(id="details_view")
    end

      @tag :logged_in_user
      test "gets causes correctly", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/mono/new")
      get_to_submission_page_refactor(view, "Ferry", "Delay")
      assert render(view) =~ ~s(fog)
    end

          @tag :logged_in_user
        test "capitalizes Amtrak in causes", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/mono/new")
      get_to_submission_page_refactor(view, "Commuter Rail", "Delay")

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "cause_detail" => "AMTRAK_TRAIN_TRAFFIC"
        }
      })

      refute view
             |> render() =~ ~s(amtrak)

      assert view
             |> render() =~ ~s(Amtrak)
    end
  end
end
