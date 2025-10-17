defmodule AlertsUI.FeedOutput.CreateStandardAlert do
  @moduledoc """
    Given a list of alerts, outputs a standard map ready to output to protobuf or JSON
  """

  @valid_trip_fields ~w(trip_id route_id direction_id start_time start_date schedule_relationship)a
  @valid_entity_fields ~w(agency_id route_id route_type trip stop_id direction_id)a
  @valid_alert_fields ~w(active_period informed_entity cause effect url header_text description_text tts_header_text tts_description_text severity_level image image_alternative_text cause_detail effect_detail)a
  @agnostic_valid_fields @valid_alert_fields ++ Enum.map(@valid_alert_fields, &to_string/1)

  @spec build_standard_alert(%{id: String.t(), alert: map()} | %{String.t() => String.t()}) :: %{
          id: String.t(),
          alert: map()
        }
  def build_standard_alert(%{"id" => alert_id, "alert" => alert}),
    do: build_standard_alert(alert_id, alert)

  def build_standard_alert(%{id: alert_id, alert: alert}),
    do: build_standard_alert(alert_id, alert)

  @spec build_standard_alert(alert_id: String.t(), alert: map()) :: %{
          id: String.t(),
          alert: map()
        }
  def build_standard_alert(alert_id, alert) do
    standard_alert =
      alert
      |> Map.take(@agnostic_valid_fields)
      |> Map.replace_lazy(:informed_entity, &Enum.map(&1, fn ie -> build_standard_entity(ie) end))

    %{
      id: alert_id,
      alert: standard_alert
    }
  end

  defp build_standard_entity(informed_entity) do
    informed_entity
    |> Map.take(@valid_entity_fields)
    |> Map.replace_lazy(:trip, &build_standard_trip/1)
  end

  defp build_standard_trip(trip) do
    trip
    |> Map.take(@valid_trip_fields)
  end
end
