defmodule AlertsUI.AlertValidation.AlertValidator do
  @moduledoc """
    Checks open alerts that have duration certainties of KNOWN or UNKNOWN against
    provided API url. If they have any routes, trips, stops, or facilities no
    longer present in the URL, the alert IDs are logged so Splunk can alert
    interested parties.
  """

  alias AlertsUI.Alerts
  alias AlertsUI.Models.Alert
  alias MBTAV3API.Facilities.Repo, as: FacilitiesRepo
  alias MBTAV3API.Routes.Repo, as: RoutesRepo
  alias MBTAV3API.Schedules.Repo, as: SchedulesRepo
  alias MBTAV3API.Stops.Repo, as: StopsRepo

  @type invalid_alert_t :: %{
          alert_id: String.t(),
          invalid_routes: [String.t()],
          invalid_stops: [String.t()],
          invalid_trips: [String.t()],
          invalid_facilities: [String.t()]
        }

  @spec validate_alerts(String.t(), String.t()) :: [invalid_alert_t()]
  def validate_alerts(
        base_url \\ Application.get_env(:alerts_ui, :api_url),
        api_key \\ Application.get_env(:alerts_ui, :api_key)
      ) do
    Alerts.list_all_open()
    |> Enum.reject(&(&1.primary_service_type == "2"))
    |> gather_alerts(base_url: base_url, api_key: api_key)
  end

  @spec validate_commuter_rail_alerts(String.t(), String.t()) :: [invalid_alert_t()]
  def validate_commuter_rail_alerts(
        base_url \\ Application.get_env(:alerts_ui, :api_url),
        api_key \\ Application.get_env(:alerts_ui, :api_key)
      ) do
    Alerts.list_all_open()
    |> Enum.filter(&(&1.primary_service_type == "2"))
    |> gather_alerts(base_url: base_url, api_key: api_key)
  end

  defp gather_alerts(alerts, api_opts) do
    alerts
    |> Enum.map(fn alert ->
      %{
        alert_id: alert.alert_id,
        route_ids: Alert.gather_route_ids(alert),
        stop_ids: Alert.gather_stop_ids(alert),
        trip_ids: Alert.gather_trip_ids(alert),
        facility_ids: Alert.gather_facility_ids(alert)
      }
    end)
    |> Enum.reduce([], fn alert_map, acc ->
      invalid_routes = invalid_routes(alert_map.route_ids, api_opts)
      invalid_stops = invalid_stops(alert_map.stop_ids, api_opts)
      invalid_trips = invalid_trips(alert_map.trip_ids, api_opts)
      invalid_facilities = invalid_facilities(alert_map.facility_ids, api_opts)

      if Enum.all?(
           [invalid_routes, invalid_stops, invalid_trips, invalid_facilities],
           &Enum.empty?/1
         ) do
        acc
      else
        entity_results = %{
          alert_id: alert_map.alert_id,
          invalid_routes: invalid_routes,
          invalid_stops: invalid_stops,
          invalid_trips: invalid_trips,
          invalid_facilities: invalid_facilities
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
            format_entity_strings(invalid_alert.invalid_routes, "Routes"),
            format_entity_strings(invalid_alert.invalid_stops, "Stops"),
            format_entity_strings(invalid_alert.invalid_trips, "Trips"),
            format_entity_strings(invalid_alert.invalid_facilities, "Facilities")
          ]
          |> Enum.reject(&is_nil/1)

        "Alert #{invalid_alert.alert_id}:|" <> Enum.join(entity_results, "|")
      end)

    "The following #{mode_word}alerts have entities that no longer exist in #{error_message_word} GTFS:|" <>
      Enum.join(invalid_alert_info, "||")
  end

  defp invalid_routes([], _), do: []

  defp invalid_routes(route_ids, api_opts) do
    found_route_ids =
      RoutesRepo.all(
        ["filter[id]": Enum.join(route_ids, ",")],
        Keyword.put(api_opts, :reject_hidden, false)
      )
      |> maybe_include_virtual_green_line(route_ids)
      |> Enum.map(& &1.id)

    route_ids -- found_route_ids
  end

  defp invalid_stops([], _), do: []

  defp invalid_stops(stop_ids, api_opts) do
    found_stop_ids =
      StopsRepo.all(["filter[id]": Enum.join(stop_ids, ",")], api_opts) |> Enum.map(& &1.id)

    stop_ids -- found_stop_ids
  end

  defp invalid_trips([], _), do: []

  defp invalid_trips(trip_ids, api_opts) do
    found_trip_ids = SchedulesRepo.trips_by_ids(trip_ids, [], api_opts) |> Enum.map(& &1.id)
    trip_ids -- found_trip_ids
  end

  defp invalid_facilities([], _), do: []

  defp invalid_facilities(facility_ids, api_opts) do
    found_facility_ids =
      facility_ids
      |> Enum.map(&FacilitiesRepo.get(&1, [], api_opts))
      |> Enum.reject(&is_nil/1)
      |> Enum.map(& &1.id)

    facility_ids -- found_facility_ids
  end

  defp format_entity_strings([], _), do: nil

  defp format_entity_strings(items, category) do
    "#{category}: #{Enum.join(items, ", ")}"
  end

  defp maybe_include_virtual_green_line(returned_routes, ids) do
    if "Green" in ids do
      [RoutesRepo.green_line() | returned_routes]
    else
      returned_routes
    end
  end
end
