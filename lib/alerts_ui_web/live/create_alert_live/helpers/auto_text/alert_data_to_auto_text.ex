defmodule AlertsUIWeb.CreateAlertLive.Helpers.AutoText.AlertDataToAutoText do
  @moduledoc """
    Converts alert data to an auto text struct
  """
  alias AlertsUIWeb.CreateAlertLive.Helpers.AutoText.BuildAutoText
  alias MBTAV3API.Stops.Repo, as: StopsRepo

  def build_autotext_data(alert_data) do
    route_type = Map.get(alert_data, :route_type)
    routes = Map.get(alert_data, :routes, [])
    schedules = Map.get(alert_data, :schedules, [])

    end_datetime =
      build_one_time_active_period_end(
        Map.get(alert_data, :active_period_end),
        Map.get(alert_data, :active_period_end_specifier),
        Map.get(alert_data, :alert_timing)
      )

    branch_name = calcuate_branch_name(route_type, routes, schedules)

    conversion =
      %{
        route_type: route_type,
        effect_name: Map.get(alert_data, :effect_name),
        routes: routes,
        stops: get_stops(alert_data),
        schedules: schedules,
        facilities: Map.get(alert_data, :facilities),
        service_types: Map.get(alert_data, :service_types),
        direction: get_direction(Map.get(alert_data, :direction)),
        connection_points: Map.get(alert_data, :connection_points),
        missed_stops: Map.get(alert_data, :missed_stops),
        branch_name: branch_name,
        severity: Map.get(alert_data, :severity) |> safe_string_to_int(),
        cause_detail: Map.get(alert_data, :cause_detail),
        start_specifier: Map.get(alert_data, :active_period_start_specifier, :now),
        end_specifier: Map.get(alert_data, :active_period_end_specifier, :later_today),
        start_time_specifier: Map.get(alert_data, :active_period_start_time_specifier, :now),
        end_time_specifier:
          Map.get(alert_data, :active_period_end_time_specifier, :end_of_service),
        start_datetime: Map.get(alert_data, :active_period_start),
        end_datetime: end_datetime,
        start_date: Map.get(alert_data, :active_period_start_date),
        end_date: Map.get(alert_data, :active_period_end_date),
        start_time: Map.get(alert_data, :active_period_start_time),
        end_time: Map.get(alert_data, :active_period_end_time),
        alert_timing: Map.get(alert_data, :alert_timing),
        recurrence_days: Map.get(alert_data, :recurrence_days),
        current_time: Map.get(alert_data, :current_time)
      }
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)

    BuildAutoText |> struct!(conversion) |> maybe_reverse_stops()
  end

  defp get_direction("0"), do: [0]
  defp get_direction("1"), do: [1]
  defp get_direction("default"), do: [0, 1]
  defp get_direction(direction), do: direction

  defp safe_string_to_int(val) when is_binary(val), do: String.to_integer(val)
  defp safe_string_to_int(val), do: val

  defp build_one_time_active_period_end(end_datetime, _, _), do: end_datetime

  defp get_stops(%{stops: stops}) when is_list(stops) do
    dedup_stops(stops)
  end

  defp get_stops(%{facilities: nil}), do: []

  defp get_stops(%{facilities: facilities}) do
    # gets stops from facilities when there is are facilities with stops in the alert.
    facilities |> Enum.map(fn %{stop: stop} -> stop end) |> Enum.reject(&is_nil/1)
  end

  defp get_stops(_), do: nil

  defp dedup_stops(stops) when is_list(stops), do: Enum.uniq(stops)

  defp maybe_reverse_stops(autotext) do
    # if we have "both directions" selected but all our trips are for
    # inbound (eg direction 1) we want to reverse the trips
    # so they show up in the inbound order in the autotext
    trip_directions =
      unless Enum.empty?(autotext.schedules) do
        autotext.schedules |> Enum.map(& &1.trip.direction_id) |> Enum.uniq()
      end

    if trip_directions == [1] && autotext.direction == [0, 1] do
      Map.put(autotext, :stops, Enum.reverse(autotext.stops))
    else
      autotext
    end
  end

  def calcuate_branch_name(2, [route], [schedule]) do
    # if this is a commuter rail alert with 1 selected route and schedule
    # and the route name contains a slash (eg Franklin/Foxboro Line)
    # then determine a new line name by finding which of the 2 branch names
    # appears in the list of stop names of the schedule's trip.
    # if both halves appear, because the route does not truly branch,
    # (eg Framingham/Worcester Line) then use the one which appears at the beginning
    # or end of the list. If start AND end of trip is branch names, return nil (use normal route name)
    if String.contains?(route.name, "/") do
      [branch_one, branch_two] = String.split(route.name, "/")
      branch_two = String.replace_trailing(branch_two, " Line", "")

      stop_names =
        schedule.trip.id
        |> StopsRepo.by_trip()
        |> Stream.map(& &1.name)
        |> Enum.into([])

      [branch_one, branch_two]
      |> Enum.filter(fn branch_name ->
        branch_name_in_stop_names?(branch_name, stop_names)
      end)
      |> branch_name(stop_names)
    else
      nil
    end
  end

  def calcuate_branch_name(_route_type, _routes, _schedules), do: nil

  defp branch_name_in_stop_names?(branch_name, stop_names) do
    Enum.any?(stop_names, fn stop_name -> String.contains?(stop_name, branch_name) end)
  end

  defp branch_name([branch_name], _stop_names), do: branch_name <> " Line"

  defp branch_name([_branch_one, _branch_two] = branch_names, [_ | _] = stop_names) do
    first_stop_name = List.first(stop_names)
    last_stop_name = List.last(stop_names)

    case Enum.filter([first_stop_name, last_stop_name], &(&1 in branch_names)) do
      [terminus_stop] -> terminus_stop <> " Line"
      _ -> nil
    end
  end

  defp branch_name(_branch_names, _stop_names), do: nil
end
