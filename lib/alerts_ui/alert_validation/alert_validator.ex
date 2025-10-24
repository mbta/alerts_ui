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

  def validate_alerts(
        base_url \\ Application.get_env(:alerts_ui, :api_url),
        api_key \\ Application.get_env(:alerts_ui, :api_key)
      ) do
    api_opts = [base_url: base_url, api_key: api_key]

    Alerts.list_all_open()
    |> Enum.map(fn alert ->
      informed_entities = alert.informed_entity

      %{
        alert_id: alert.alert_id,
        route_ids: Alert.gather_route_ids(informed_entities),
        stop_ids: Alert.gather_stop_ids(informed_entities),
        trip_ids: Alert.gather_trip_ids(informed_entities),
        facility_ids: Alert.gather_facility_ids(informed_entities)
      }
    end)
    |> Enum.reduce([], fn alert_map, acc ->
      routes_ok? = routes_ok?(alert_map.route_ids, api_opts)
      stops_ok? = stops_ok?(alert_map.stop_ids, api_opts)
      trips_ok? = trips_ok?(alert_map.trip_ids, api_opts)
      facilities_ok? = facilities_ok?(alert_map.facility_ids, api_opts)

      if Enum.all?([routes_ok?, stops_ok?, trips_ok?, facilities_ok?]) do
        acc
      else
        [alert_map.alert_id | acc]
      end
    end)
  end

  defp routes_ok?([], _), do: true

  defp routes_ok?(route_ids, api_opts) do
    found_routes = RoutesRepo.all(["filter[id]": Enum.join(route_ids, ",")], api_opts)
    length(found_routes) == length(route_ids)
  end

  defp stops_ok?([], _), do: true

  defp stops_ok?(stop_ids, api_opts) do
    found_stops = StopsRepo.all(["filter[id]": Enum.join(stop_ids, ",")], api_opts)
    length(found_stops) == length(stop_ids)
  end

  defp trips_ok?([], _), do: true

  defp trips_ok?(trip_ids, api_opts) do
    found_trips = SchedulesRepo.trips_by_ids(trip_ids, [], api_opts)
    length(found_trips) == length(trip_ids)
  end

  defp facilities_ok?([], _), do: true

  defp facilities_ok?(facility_ids, api_opts) do
    found_facilities = FacilitiesRepo.all(["filter[id]": Enum.join(facility_ids, ",")], api_opts)
    length(found_facilities) == length(facility_ids)
  end
end
