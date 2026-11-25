defmodule AlertsUI.AlertValidation.AlertAssociationValidator do
  @moduledoc """
    Checks open alerts that have duration certainties of KNOWN or UNKNOWN against
    provided API url. If they have any stops or trips that are not associated with their routes,
    the alert IDs are logged so Splunk can alert
    interested parties. If you want to make this run for upcoming,
    then the api library functions need updated to take the api key.
  """

  alias AlertsUI.Alerts
  alias AlertsUI.Models.Alert
  alias AlertsUI.Routes
  alias MBTAV3API.Schedules.Repo, as: SchedulesRepo
  alias MBTAV3API.Stops.Repo, as: StopsRepo

  @type invalid_alert_t :: %{
          alert_id: String.t(),
          invalid_stops: [String.t()],
          invalid_trips: [String.t()]
        }

  @spec validate_alerts() :: [invalid_alert_t()]
  def validate_alerts do
    Alerts.list_all_open()
    |> Enum.reject(&(&1.primary_service_type == "2"))
    |> gather_alerts()
  end

  @spec validate_commuter_rail_alerts() :: [invalid_alert_t()]
  def validate_commuter_rail_alerts do
    Alerts.list_all_open()
    |> Enum.filter(&(&1.primary_service_type == "2"))
    |> gather_alerts()
  end

  defp gather_alerts(alerts) do
    alerts
    |> Enum.map(fn alert ->
      %{
        alert_id: alert.alert_id,
        route_ids: alert |> Alert.gather_route_ids() |> Routes.expanding_green_line(),
        stop_ids: Alert.gather_stop_ids(alert),
        trip_ids: Alert.gather_trip_ids(alert)
      }
    end)
    |> Enum.reduce([], fn alert_map, acc ->
      invalid_stops = invalid_stops(alert_map.stop_ids, alert_map.route_ids)
      invalid_trips = invalid_trips(alert_map.trip_ids, alert_map.route_ids)

      if Enum.all?(
           [invalid_stops, invalid_trips],
           &Enum.empty?/1
         ) do
        acc
      else
        entity_results = %{
          alert_id: alert_map.alert_id,
          invalid_stops: invalid_stops,
          invalid_trips: invalid_trips
        }

        [entity_results | acc]
      end
    end)
  end

  @spec format_invalid_alerts([invalid_alert_t()], String.t()) :: String.t()
  # use to format a list of invalid alert structs for logging purposes
  def format_invalid_alerts(invalid_alerts, error_message_word, mode_word \\ "")
  def format_invalid_alerts([], _, _), do: "No invalid alerts found"

  def format_invalid_alerts(invalid_alerts, error_message_word, mode_word) do
    invalid_alert_info =
      Enum.map(invalid_alerts, fn invalid_alert ->
        entity_results =
          [
            format_entity_strings(invalid_alert.invalid_stops, "Stops"),
            format_entity_strings(invalid_alert.invalid_trips, "Trips")
          ]
          |> Enum.reject(&is_nil/1)

        "Alert #{invalid_alert.alert_id}:|" <> Enum.join(entity_results, "|")
      end)

    "The following #{mode_word}alerts have entities that are no longer associated with each other in #{error_message_word} GTFS:|" <>
      Enum.join(invalid_alert_info, "||")
  end

  defp invalid_stops([], _), do: []
  defp invalid_stops(_, []), do: []

  defp invalid_stops(stop_ids, route_ids) do
    found_stop_ids =
      StopsRepo.all("filter[route]": Enum.join(route_ids, ","))
      |> Enum.map(& &1.id)
      |> Enum.filter(&(&1 in stop_ids))

    stop_ids -- found_stop_ids
  end

  defp invalid_trips([], _), do: []
  defp invalid_trips(_, []), do: []

  defp invalid_trips(trip_ids, route_ids) do
    found_trip_ids =
      SchedulesRepo.by_route_ids(route_ids)
      |> Enum.map(& &1.trip.id)
      |> Enum.filter(&(&1 in trip_ids))

    trip_ids -- found_trip_ids
  end

  defp format_entity_strings([], _), do: nil

  defp format_entity_strings(items, category) do
    "#{category}: #{Enum.join(items, ", ")}"
  end
end
