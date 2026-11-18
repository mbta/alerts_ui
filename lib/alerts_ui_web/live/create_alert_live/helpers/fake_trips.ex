alias AlertsUI.Models.EnhancedSchedule
alias MBTAV3API.Schedules.Trip
alias MBTAV3API.Stops.Stop

require Logger

defmodule AlertsUIWeb.CreateAlertLive.Helpers.FakeTrips do
  @moduledoc """
  Functions for handling staged fake trips

  Sometimes it is nice to be able to inject fake trip data into our site to test
  out specific cases, i.e. short-lived disruptions/changes to GTFS.
  """
  alias MBTAV3API.Routes.Route

  @fake_trip_file_path "./test/support/fixtures/extra_trips.json"

  @spec maybe_add_fake_trips([EnhancedSchedule.t()], boolean(), Route.type_int()) :: [
          EnhancedSchedule.t()
        ]
  def maybe_add_fake_trips(schedules, show_fake_trips, route_type)

  def maybe_add_fake_trips(schedules, true, route_type) do
    data = File.read!(@fake_trip_file_path)
    data = data |> Jason.decode!()

    now = DateTime.now!("America/New_York")

    added_schedules =
      data
      |> Enum.with_index()
      |> Enum.map(fn {d, idx} ->
        # Hard code the times to always be a little after 'now' so that they reliably show
        # up in the form
        departure_datetime = now |> DateTime.add(1, :hour) |> DateTime.add(5 * idx, :minute)
        time_of_last_trip_arrival = departure_datetime |> DateTime.add(1, :hour)

        # Ferries get the name that is displayed in the selector from the stop name, not the trip name
        stop_name =
          if route_type === 4, do: "[FAKE] #{d["stop"]["name"]}", else: d["stop"]["name"]

        %EnhancedSchedule{
          route_id: d["route_id"],
          departure_time: departure_datetime,
          time_of_last_trip_arrival: time_of_last_trip_arrival,
          trip: %Trip{
            id: d["trip"]["id"],
            name: "[FAKE] #{d["trip"]["name"]}",
            direction_id: d["trip"]["direction_id"]
          },
          stop: %Stop{name: stop_name},
          last_stop_name: d["last_stop_name"],
          added_route_ids: d["added_route_ids"] || []
        }
      end)

    added_schedules ++ schedules
  rescue
    exception ->
      Logger.error(
        "Error reading fake trips, returning original trips: #{Exception.message(exception)}"
      )

      schedules
  end

  def maybe_add_fake_trips(schedules, false, _route_type) do
    schedules
  end
end
