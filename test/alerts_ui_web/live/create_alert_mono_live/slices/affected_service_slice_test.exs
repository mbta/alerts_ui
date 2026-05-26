defmodule AlertsUIWeb.CreateAlertMonoLive.Slices.AffectedServiceSliceTest do
  use ExUnit.Case, async: true

  alias AlertsUI.Models.EnhancedSchedule
  alias AlertsUIWeb.CreateAlertMonoLive.AlertData
  alias AlertsUIWeb.CreateAlertMonoLive.Slice
  alias AlertsUIWeb.CreateAlertMonoLive.Slices.AffectedServiceSlice
  alias MBTAV3API.Routes.Route
  alias MBTAV3API.Schedules.Trip
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
