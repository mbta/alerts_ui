defmodule AlertsUI.FeedOutput.CreateOutputAlert do
  @moduledoc """
  Turns an alert database entry into a map ready for output to JSON
  """
  alias AlertsUI.Models.{Alert, AlertLifecycle}
  alias AlertsUI.TimeframeText

  @spec build_alert(Alert.t(), DateTime.t()) :: %{id: String.t(), alert: map()}
  def build_alert(alert, current_time \\ DateTime.utc_now()) do
    %{
      id: alert.alert_id,
      alert:
        %{
          effect: alert.effect,
          effect_detail: alert.effect_detail |> maybe_build_translated_cause_effect_detail_string,
          cause: alert.cause || :UNKNOWN_CAUSE,
          cause_detail:
            (alert.cause_detail || "UNKNOWN_CAUSE")
            |> maybe_build_translated_cause_effect_detail_string,
          header_text: alert.header_text |> build_translated_string,
          description_text: alert.description_text |> build_translated_string,
          banner_text: alert.banner_text |> build_translated_string,
          severity_level: alert.severity_level,
          url: alert.url |> build_translated_string,
          service_effect_text: alert.service_effect_text |> build_translated_string,
          short_header_text: alert.short_header_text |> build_translated_string,
          severity: alert.severity,
          created_timestamp: alert.created_at |> date_time_to_unix(),
          last_modified_timestamp: alert.last_modified_timestamp |> date_time_to_unix(),
          last_push_notification_timestamp:
            alert.last_push_notification_timestamp |> date_time_to_unix(),
          closed_timestamp: alert.closed_timestamp |> date_time_to_unix(),
          timeframe_text:
            TimeframeText.timeframe_text(
              alert.active_period_start,
              alert.active_period_end,
              alert.recurring,
              alert.duration_certainty
            )
            |> build_translated_string,
          recurrence_text: alert.recurrence_text |> build_translated_string,
          alert_lifecycle: alert.active_period_start |> AlertLifecycle.get_alert_lifecycle(),
          duration_certainty: alert.duration_certainty,
          reminder_times:
            alert.reminder_times |> Enum.map(& &1.reminder_time) |> build_reminder_times(),
          active_period:
            build_active_period(alert.active_period, current_time, alert.closed_timestamp),
          image: alert.image_url |> build_translated_image,
          image_alternative_text: alert.image_alternative_text |> build_translated_string,
          tts_header_text: alert.tts_header_text |> build_translated_string,
          tts_description_text: alert.tts_description_text |> build_translated_string,
          informed_entity: alert.informed_entity |> build_informed_entities
        }
        |> Map.filter(&filter_out_nil_values/1)
    }
  end

  def build_gtfs_header do
    %{
      gtfs_realtime_version: "2.0",
      incrementality: :FULL_DATASET,
      timestamp: DateTime.utc_now() |> DateTime.to_unix()
    }
  end

  def build_active_period(active_period, current_time, nil) do
    active_period
    |> Enum.filter(&end_is_in_future(&1.end, current_time))
    |> build_one_time_active_periods
  end

  def build_active_period(_active_period, _current_time, _closed_timestamp), do: []

  def build_one_time_active_periods(nil), do: nil

  def build_one_time_active_periods(active_periods) do
    Enum.map(active_periods, &build_one_time_active_period/1)
  end

  defp end_is_in_future(nil, _current_time), do: true

  defp end_is_in_future(end_time, current_time) do
    DateTime.compare(end_time, current_time) in [:eq, :gt]
  end

  defp build_one_time_active_period(active_period) do
    %{
      start: active_period.start |> date_time_to_unix,
      end: get_in(active_period, [Access.key!(:end)]) |> date_time_to_unix
    }
    |> Map.filter(&filter_out_nil_values/1)
  end

  defp build_reminder_times([]), do: nil
  defp build_reminder_times(reminder_times), do: Enum.map(reminder_times, &date_time_to_unix/1)

  def build_informed_entities(nil), do: nil

  def build_informed_entities(informed_entities) do
    Enum.map(informed_entities, &build_informed_entity/1)
  end

  def build_informed_entity(informed_entity) do
    %{
      agency_id: informed_entity.agency_id,
      route_type: informed_entity.route_type,
      facility_id: informed_entity.facility_id,
      route_id: informed_entity.route_id,
      trip: informed_entity.trip |> build_trip,
      direction_id: informed_entity.direction_id,
      stop_id: informed_entity.stop_id,
      activities: informed_entity.activities
    }
    |> Map.filter(&filter_out_nil_values/1)
  end

  def build_trip(nil), do: nil

  def build_trip(trip) do
    %{
      route_id: trip.route_id,
      trip_id: trip.trip_id,
      direction_id: trip.direction_id,
      start_time: trip.start_time |> extended_time_to_string,
      start_date: trip.start_date |> date_to_string,
      schedule_relationship: trip.schedule_relationship
    }
    |> Map.filter(&filter_out_nil_values/1)
  end

  defp maybe_build_translated_cause_effect_detail_string(input_string) do
    if Application.get_env(:alerts_ui, :translated_cause_effect_detail) == true do
      build_translated_string(input_string)
    else
      input_string
    end
  end

  defp build_translated_string(nil), do: nil

  defp build_translated_string(input_string) do
    %{
      translation: [
        %{
          text: input_string |> String.replace(~r/(\r?\n)/, "\r\n"),
          language: "en"
        }
      ]
    }
  end

  defp build_translated_image(nil), do: nil

  defp build_translated_image(input_string) do
    %{
      localized_image: [
        %{
          url: input_string,
          language: "en",
          media_type: "application/octet-stream"
        }
      ]
    }
  end

  defp date_to_string(nil), do: nil
  defp date_to_string(date), do: date |> Date.to_string() |> String.replace("-", "")

  defp extended_time_to_string(nil), do: nil

  defp extended_time_to_string(ex_time) do
    timestring = Time.to_string(ex_time.time)

    case ex_time.relative_day do
      1 ->
        timestring

      2 ->
        [hours, minutes, seconds] = timestring |> String.split(":")
        relative_hours = (hours |> String.to_integer()) + 24
        [relative_hours, minutes, seconds] |> Enum.join(":")
    end
  end

  defp date_time_to_unix(nil), do: nil
  defp date_time_to_unix(times) when is_list(times), do: Enum.map(times, &date_time_to_unix/1)
  defp date_time_to_unix(time), do: DateTime.to_unix(time)

  defp filter_out_nil_values({_key, value}), do: !is_nil(value)
end
