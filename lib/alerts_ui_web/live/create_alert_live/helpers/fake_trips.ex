alias AlertsUI.Models.EnhancedSchedule
alias MBTAV3API.Schedules.Trip
alias MBTAV3API.Stops.Stop

defmodule AlertsUIWeb.CreateAlertLive.Helpers.FakeTrips do
  @moduledoc """
  Functions for handling staged fake trips

  Sometimes it is nice to be able to inject fake trip data into our site to test
  out specific cases, i.e. short-lived disruptions/changes to GTFS.
  """

  @fake_trip_file_path "./test/support/fixtures/extra_trips.json"

  @spec maybe_add_fake_trips([EnhancedSchedule.t()]) :: [EnhancedSchedule.t()]
  def maybe_add_fake_trips(schedules) do
    {:ok, data} = File.read(@fake_trip_file_path)
    data = data |> Jason.decode!()

    added_schedules =
      Enum.map(data, fn d ->
        {:ok, departure_datetime, _} = DateTime.from_iso8601(d["departure_time"])

        {:ok, time_of_last_trip_arrival, _} =
          DateTime.from_iso8601(d["time_of_last_trip_arrival"])

        %EnhancedSchedule{
          route_id: d["route_id"],
          departure_time: departure_datetime,
          time_of_last_trip_arrival: time_of_last_trip_arrival,
          trip: %Trip{
            id: d["trip"]["id"],
            name: "FAKE #{d["trip"]["name"]}",
            direction_id: d["trip"]["direction_id"]
          },
          stop: %Stop{name: d["stop"]["name"]},
          last_stop_name: d["stop"]["last_stop_name"],
          added_route_ids: d["added_route_ids"] || []
        }
      end)

    added_schedules ++ schedules
  end
end
