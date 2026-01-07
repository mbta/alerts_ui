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
        facility: Map.get(alert_data, :facility),
        service_types: Map.get(alert_data, :service_types),
        direction: get_direction(Map.get(alert_data, :direction)),
        severity: Map.get(alert_data, :severity) |> safe_string_to_int(),
        cause_detail: Map.get(alert_data, :cause_detail),
        start_specifier: Map.get(alert_data, :active_period_start_specifier),
        end_specifier: Map.get(alert_data, :active_period_end_specifier),
        start_time_specifier: Map.get(alert_data, :active_period_start_time_specifier),
        end_time_specifier: Map.get(alert_data, :active_period_end_time_specifier),
        start_datetime: Map.get(alert_data, :active_period_start),
        end_datetime: end_datetime,
        start_date: Map.get(alert_data, :active_period_start_date),
        end_date: Map.get(alert_data, :active_period_end_date),
        start_time: Map.get(alert_data, :active_period_start_time),
        end_time: Map.get(alert_data, :active_period_end_time),
        alert_timing: Map.get(alert_data, :alert_timing),
        recurrence_days: Map.get(alert_data, :recurrence_days)
      }
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)

    struct!(BuildAutoText, conversion)
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

  defp get_stops(%{facility: facility}) when not is_nil(facility) do
    # gets stop from facility when there is a facility in the alert.
    [Map.get(facility, :stop)]
  end

  defp get_stops(_), do: nil

  defp dedup_stops(stops) when is_list(stops), do: Enum.uniq(stops)
  defp dedup_stops(_), do: []
end
