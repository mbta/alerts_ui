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
  alias MBTAV3API.Routes.Repo, as: RoutesRepo
  alias MBTAV3API.Routes.Route
  alias MBTAV3API.Schedules.Repo, as: SchedulesRepo
  alias MBTAV3API.Schedules.Trip
  alias MBTAV3API.Stops.Repo, as: StopsRepo
  alias MBTAV3API.Stops.Stop
  alias Phoenix.LiveView.AsyncResult

  @schedule %EnhancedSchedule{
    route: %Route{id: "CR-Worcester", type: 2, name: "Framingham/Worcester Line"},
    trip: %Trip{id: "trip-595", name: "595", direction_id: 0},
    stop: %Stop{id: "place-sstat", name: "South Station"},
    arrival_time: nil,
    departure_time: ~U[2024-06-01 14:00:00Z]
  }

  defp base_changeset(attrs \\ %{}) do
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
    %{assigns: %{selections: %AsyncResult{loading: [:selections]}}}
  end

  @route %Route{
    direction_names: %{0 => "Westbound", 1 => "Eastbound"},
    sort_order: 3,
    id: "CR-Worcester",
    type: 2,
    name: "Framingham/Worcester Line"
  }

  @subway_route %Route{
    direction_names: %{0 => "Southbound", 1 => "Northbound"},
    sort_order: 1,
    id: "Red",
    type: 1,
    name: "Red Line"
  }

  @stop %Stop{id: "place-sstat", name: "South Station"}

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
    test "direction options are populated once a route is chosen", %{conn: conn} do
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
    test "trip options are populated when route and direction are selected", %{conn: conn} do
      today = @todays_date |> Date.to_string()

      with_mocks([
        {RoutesRepo, [], [by_type: fn _ -> [@route] end]},
        {StopsRepo, [], [by_route: fn _, _, _ -> [@stop] end]},
        {SchedulesRepo, [],
         [
           by_route_ids: fn ["CR-Worcester"], [stop_sequences: [:first, :last], date: ^today] ->
             [@schedule, @schedule]
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
    test "renders correctly while editing an existing commuter rail alert", %{conn: conn} do
      alert_params =
        build(:alert_map, %{
          alert_id: "test-cr-edit",
          effect: :DELAY,
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
        {StopsRepo, [], [by_route: fn _, _, _ -> [@stop] end]}
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
