defmodule AlertsUIWeb.FormComponents.Helpers.AutoText.AlertDataToAutoText do

  alias AlertsUIWeb.FormComponents.Helpers.AutoText.BuildAutoText

  def do_it(alert_data) do
    # alert_data |> IO.inspect(label: :alrt_data)
    facility = Enum.find(Map.get(alert_data, :available_facilities, []), fn facility -> facility.id == Map.get(alert_data, :facility_id) end)

    conversion = %{
      route_type: Map.get(alert_data, :route_type),
      effect_name: Map.get(alert_data, :effect_name),

      routes: [],
      stops: [],
      schedules: [],
      facility: nil,

      service_types: Map.get(alert_data, :service_types),
      direction: get_direction(Map.get(alert_data, :direction)),
      severity: Map.get(alert_data, :severity) |> safe_string_to_int(),
      cause_detail: Map.get(alert_data, :cause_detail), #"TIE_REPLACEMENT
      start_specifier: Map.get(alert_data, :active_period_start_specifier),
      end_specifier: Map.get(alert_data, :active_period_end_specifier),
      start_datetime: Map.get(alert_data, :active_period_end),
      end_datetime: Map.get(alert_data, :active_period_start),
      start_date: Map.get(alert_data, :active_period_start_date),
      end_date: Map.get(alert_data, :active_period_end_date),
      start_time: Map.get(alert_data, :active_period_start_time),
      end_time: Map.get(alert_data, :active_period_end_time),
      alert_timing: Map.get(alert_data, :alert_timing),
      recurrence_days: Map.get(alert_data, :recurrence_days)
    } |> Enum.reject(fn {_k,v} -> is_nil(v) end)

    struct!(BuildAutoText, conversion)# |> IO.inspect(label: :strut)
  end

  defp get_direction("0"), do: [0]
  defp get_direction("1"), do: [0]
  defp get_direction("default"), do: [0, 1]
  defp get_direction(direction), do: direction


  defp safe_string_to_int(val) when is_binary(val), do: String.to_integer(val)
  defp safe_string_to_int(val), do: val
end
