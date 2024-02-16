defmodule AlertsUI.GTFSIntake.RealtimeEnhancedParser do
  @moduledoc """
  Supervisor for realtime alert information from realtime GTFS.
  """
  alias AlertsUI.Models.ActivePeriod
  alias AlertsUI.Models.ExtendedTime

  @spec parse(map()) :: [map()]
  def parse(alert_data) do
    decode_entities(alert_data)
  end

  @spec decode_entities(map()) :: [map()]
  defp decode_entities(%{"entity" => entities}),
    do: Enum.map(entities, &decode_feed_entity(&1))

  defp decode_feed_entity(%{"alert" => %{} = alert, "id" => id}),
    do: decode_alert(alert, id)

  defp decode_feed_entity(_), do: []

  @spec decode_alert(map, any) :: map()
  def decode_alert(alert, id) do
    active_periods = alert |> Map.get("active_period") |> parse_active_periods

    %{
      alert_id: id,
      effect: alert |> Map.get("effect") |> parse_string_to_atom(),
      effect_detail: Map.get(alert, "effect_detail"),
      cause: alert |> Map.get("cause") |> parse_string_to_atom(),
      cause_detail: Map.get(alert, "cause_detail"),
      banner_text: alert |> Map.get("banner_text") |> parse_translated_string(),
      header_text: alert |> Map.get("header_text") |> parse_translated_string(),
      description_text: alert |> Map.get("description_text") |> parse_translated_string(),
      severity_level: alert |> Map.get("severity_level") |> parse_string_to_atom(),
      url: alert |> Map.get("url") |> parse_translated_string(),
      service_effect_text: alert |> Map.get("service_effect_text") |> parse_translated_string(),
      short_header_text: alert |> Map.get("short_header_text") |> parse_translated_string(),
      severity: Map.get(alert, "severity"),
      created_timestamp: alert |> Map.get("created_timestamp") |> parse_unix_time(),
      last_modified_timestamp: alert |> Map.get("last_modified_timestamp") |> parse_unix_time(),
      last_push_notification_timestamp:
        alert |> Map.get("last_push_notification_timestamp") |> parse_unix_time(),
      closed_timestamp: alert |> Map.get("closed_timestamp") |> parse_unix_time(),
      timeframe_text: alert |> Map.get("timeframe_text") |> parse_translated_string(),
      recurrence_text: alert |> Map.get("recurrence_text") |> parse_translated_string(),
      alert_lifecycle: alert |> Map.get("alert_lifecycle") |> parse_string_to_atom(),
      duration_certainty: alert |> Map.get("duration_certainty") |> parse_string_to_atom(),
      reminder_times: alert |> Map.get("reminder_times"),
      active_period: active_periods,
      active_period_start: ActivePeriod.start_time_of_first_active_period(active_periods),
      active_period_end: ActivePeriod.end_time_of_last_active_period(active_periods),
      image_url: alert |> Map.get("image") |> parse_translated_image(),
      image_alternative_text:
        alert |> Map.get("image_alternative_text") |> parse_translated_string(),
      tts_header_text: alert |> Map.get("tts_header_text") |> parse_translated_string(),
      tts_description_text: alert |> Map.get("tts_description_text") |> parse_translated_string(),
      informed_entity: alert |> Map.get("informed_entity") |> decode_informed_entities()
    }
  end

  @spec decode_trip(nil | [map()]) :: nil | [map()]
  defp decode_informed_entities(informed_entities) do
    Enum.map(informed_entities, fn informed_entity ->
      %{
        agency_id: Map.get(informed_entity, "agency_id"),
        route_id: Map.get(informed_entity, "route_id"),
        route_type: Map.get(informed_entity, "route_type"),
        facility_id: Map.get(informed_entity, "facility_id"),
        direction_id: Map.get(informed_entity, "direction_id"),
        stop_id: Map.get(informed_entity, "stop_id"),
        activities:
          informed_entity |> Map.get("activities") |> Enum.map(&parse_string_to_atom(&1)),
        trip: informed_entity |> Map.get("trip") |> decode_trip()
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
      start_date: trip |> Map.get("start_date") |> date(),
      start_time: trip |> Map.get("start_time") |> ExtendedTime.new() |> safe_to_map(),
      schedule_relationship: trip |> Map.get("schedule_relationship") |> parse_string_to_atom()
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
        start: active_period |> Map.get("start") |> parse_unix_time(),
        end: active_period |> Map.get("end") |> parse_unix_time()
      }
    end)
  end

  @spec parse_translated_image(nil | [map()]) :: String.t() | nil
  defp parse_translated_image(nil), do: nil

  defp parse_translated_image(%{"localized_image" => localized_images}) do
    case Enum.find(localized_images, &(&1["language"] == "en")) do
      %{"url" => url} -> url
      _ -> nil
    end
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
