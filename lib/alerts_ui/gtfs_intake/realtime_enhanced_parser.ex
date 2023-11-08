defmodule AlertsUI.GTFSIntake.RealtimeEnhancedParser do
  @moduledoc """
  Supervisor for realtime alert information from realtime GTFS.
  """
  alias AlertsUI.Models.ExtendedTime

  @spec parse(binary | []) :: [AlertsUI.Models.Alert.t()] | []
  def parse(binary) do
    binary
    |> Jason.decode!(strings: :copy)
    |> decode_entities()
  end

  @spec decode_entities(map()) :: [map()]
  defp decode_entities(%{"entity" => entities}),
    do: Enum.map(entities, &decode_feed_entity(&1))

  defp decode_feed_entity(%{"alert" => %{} = alert, "id" => id}),
    do: decode_alert(alert, id)

  defp decode_feed_entity(_), do: []

  @spec decode_alert(map, any) :: map()
  def decode_alert(alert, id) do
    %{
      alert_id: id,
      effect: Map.get(alert, "effect") |> parse_string_to_atom,
      effect_detail: Map.get(alert, "effect_detail"),
      cause: Map.get(alert, "cause") |> parse_string_to_atom,
      cause_detail: Map.get(alert, "cause_detail"),
      header_text: Map.get(alert, "header_text") |> parse_translated_string,
      description_text: Map.get(alert, "description_text") |> parse_translated_string,
      severity_level: Map.get(alert, "severity_level") |> parse_string_to_atom,
      url: Map.get(alert, "url") |> parse_translated_string,
      service_effect_text: Map.get(alert, "service_effect_text") |> parse_translated_string,
      short_header_text: Map.get(alert, "short_header_text") |> parse_translated_string,
      severity: Map.get(alert, "severity"),
      created_timestamp: Map.get(alert, "created_timestamp") |> parse_unix_time,
      last_modified_timestamp: Map.get(alert, "last_modified_timestamp") |> parse_unix_time,
      last_push_notification_timestamp:
        Map.get(alert, "last_push_notification_timestamp") |> parse_unix_time,
      closed_timestamp: Map.get(alert, "closed_timestamp") |> parse_unix_time,
      timeframe_text: Map.get(alert, "timeframe_text") |> parse_translated_string,
      alert_lifecycle: Map.get(alert, "alert_lifecycle") |> parse_string_to_atom,
      duration_certainty: Map.get(alert, "duration_certainty") |> parse_string_to_atom,
      active_period: Map.get(alert, "active_period") |> parse_active_periods,
      image_url: Map.get(alert, "image_url") |> parse_translated_string,
      image_alternative_text: Map.get(alert, "image_alternative_text") |> parse_translated_string,
      tts_header_text: Map.get(alert, "tts_header_text") |> parse_translated_string,
      tts_description_text: Map.get(alert, "tts_description_text") |> parse_translated_string,
      informed_entity: Map.get(alert, "informed_entity") |> decode_informed_entities
    }
  end

  @spec decode_trip(nil | [map()]) :: nil | [map()]
  defp decode_informed_entities(informed_entities) do
    Enum.map(informed_entities, fn informed_entity ->
      %{
        agency_id: Map.get(informed_entity, "agency_id"),
        route_id: Map.get(informed_entity, "route_id"),
        route_type: Map.get(informed_entity, "route_type"),
        direction_id: Map.get(informed_entity, "direction_id"),
        stop_id: Map.get(informed_entity, "stop_id"),
        activities: Map.get(informed_entity, "activities") |> Enum.map(&parse_string_to_atom(&1)),
        trip: Map.get(informed_entity, "trip") |> decode_trip
      }
    end)
  end

  @spec decode_trip(nil | map()) :: nil | map()
  defp decode_trip(nil), do: nil

  defp decode_trip(trip) do
    %{
      trip_id: Map.get(trip, "trip_id"),
      route_id: Map.get(trip, "route_id"),
      direction_id: Map.get(trip, "direction_id"),
      start_date: Map.get(trip, "start_date") |> date,
      start_time: Map.get(trip, "start_time") |> ExtendedTime.new() |> safe_to_map,
      schedule_relationship: Map.get(trip, "schedule_relationship") |> parse_string_to_atom
    }
  end

  @spec safe_to_map(nil | [map()]) :: nil | [map()]
  defp safe_to_map(nil), do: nil
  defp safe_to_map(struct), do: Map.from_struct(struct)

  @spec parse_active_periods(nil | [map()]) :: nil | [map()]
  defp parse_active_periods(nil), do: []

  defp parse_active_periods(periods_list) do
    Enum.map(periods_list, fn active_period ->
      %{
        start: Map.get(active_period, "start") |> parse_unix_time,
        end: Map.get(active_period, "end") |> parse_unix_time
      }
    end)
  end

  @spec parse_translated_string(nil | [map()]) :: String.t() | nil
  defp parse_translated_string(nil), do: nil

  defp parse_translated_string(%{"translation" => translations}) do
    case Enum.find(translations, &(&1["language"] == "en")) do
      %{"text" => text} -> text
      _ -> nil
    end
  end

  @spec parse_string_to_atom(nil | String.t()) :: nil | atom()
  defp parse_string_to_atom(nil), do: nil
  defp parse_string_to_atom(enum_string), do: String.to_atom(enum_string)

  @spec parse_unix_time(integer() | nil) :: DateTime.t() | nil
  defp parse_unix_time(nil), do: nil
  defp parse_unix_time(timestamp), do: DateTime.from_unix!(timestamp)

  @spec date(String.t() | nil) :: Date.t() | nil
  def date(nil), do: nil

  def date(<<year_str::binary-4, month_str::binary-2, day_str::binary-2>>) do
    Date.from_iso8601!("#{year_str}-#{month_str}-#{day_str}")
  end
end
