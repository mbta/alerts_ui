defmodule AlertsUI.FeedOutput.CreateStandardAlert do
  @moduledoc """
    Given a list of alerts, outputs a standard map ready to output to protobuf or JSON
  """

  @valid_trip_fields ~w(trip_id route_id direction_id start_time start_date schedule_relationship)a
  @valid_entity_fields ~w(agency_id route_id route_type trip stop_id direction_id)a
  @valid_alert_fields ~w(active_period informed_entity cause effect url header_text description_text tts_header_text tts_description_text severity_level image image_alternative_text cause_detail effect_detail)a

  def build_standard_alert(alert) do
    alert
    |> Map.take(@valid_alert_fields)
  end

  def build_standard_entity(informed_entity) do
    informed_entity
    |> Map.take(@valid_entity_fields)
    |> Map.replace_lazy(:trip, &build_standard_trip/1)
  end

  def build_standard_trip(trip) do
    trip
    |> Map.take(@valid_trip_fields)
  end
end
