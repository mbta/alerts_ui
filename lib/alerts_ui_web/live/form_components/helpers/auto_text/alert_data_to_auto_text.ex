defmodule AlertsUIWeb.FormComponents.Helpers.AutoText.AlertDataToAutoText do
  @moduledoc """
    Converts alert data to an auto text struct
  """
  alias AlertsUIWeb.FormComponents.Helpers.AutoText.BuildAutoText

  def build_autotext_data(alert_data) do
    end_datetime =
      build_one_time_active_period_end(
        Map.get(alert_data, :active_period_end),
        Map.get(alert_data, :active_period_end_specifier),
        Map.get(alert_data, :alert_timing)
      )

    conversion =
      %{
        route_type: Map.get(alert_data, :route_type),
        effect_name: Map.get(alert_data, :effect_name),
        routes: Map.get(alert_data, :routes, []),
        stops: get_stops(alert_data),
        schedules: Map.get(alert_data, :schedules, []),
        facilities: Map.get(alert_data, :facilities),
        service_types: Map.get(alert_data, :service_types),
        direction: get_direction(Map.get(alert_data, :direction)),
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
end
