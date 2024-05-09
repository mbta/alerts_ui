defmodule AlertsUI.FeedOutput.CreateOutputAlert do
  @moduledoc """
  Turns an alert database entry into a map ready for output to JSON
  """
  alias AlertsUI.Models.{Alert, AlertLifecycle}

  @spec build_alert(Alert.t()) :: map()
  def build_alert(alert) do
    # cause_detail and effect_detail should be translated_string types according to GTFS spec
    # but in the current feed they are simple strings

    %{
      id: Map.get(alert, :alert_id),
      alert:
        %{
          effect: Map.get(alert, :effect),
          effect_detail: Map.get(alert, :effect_detail),
          cause: Map.get(alert, :cause),
          cause_detail: Map.get(alert, :cause_detail),
          header_text: Map.get(alert, :header_text) |> build_translated_string,
          description_text: Map.get(alert, :description_text) |> build_translated_string,
          banner_text: Map.get(alert, :banner_text) |> build_translated_string,
          severity_level: Map.get(alert, :severity_level),
          url: Map.get(alert, :url) |> build_translated_string,
          service_effect_text: Map.get(alert, :service_effect_text) |> build_translated_string,
          short_header_text: Map.get(alert, :short_header_text) |> build_translated_string,
          severity: Map.get(alert, :severity),
          created_timestamp: Map.get(alert, :created_timestamp) |> date_time_to_unix(),
          last_modified_timestamp:
            Map.get(alert, :last_modified_timestamp) |> date_time_to_unix(),
          last_push_notification_timestamp:
            Map.get(alert, :last_push_notification_timestamp) |> date_time_to_unix(),
          closed_timestamp: Map.get(alert, :closed_timestamp) |> date_time_to_unix(),
          timeframe_text: Map.get(alert, :timeframe_text) |> build_translated_string,
          recurrence_text: Map.get(alert, :recurrence_text) |> build_translated_string,
          alert_lifecycle:
            Map.get(alert, :active_period_start) |> AlertLifecycle.get_alert_lifecycle(),
          duration_certainty: Map.get(alert, :duration_certainty),
          reminder_times: Map.get(alert, :reminder_times),
          active_period: Map.get(alert, :active_period) |> build_active_periods,
          image: Map.get(alert, :image_url) |> build_translated_image,
          image_alternative_text:
            Map.get(alert, :image_alternative_text) |> build_translated_string,
          tts_header_text: Map.get(alert, :tts_header_text) |> build_translated_string,
          tts_description_text: Map.get(alert, :tts_description_text) |> build_translated_string,
          informed_entity: Map.get(alert, :informed_entity) |> build_informed_entities
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

  def build_active_periods(nil), do: nil

  def build_active_periods(active_periods) do
    Enum.map(active_periods, &build_active_period/1)
  end

  defp build_active_period(active_period) do
    %{
      start: Map.get(active_period, :start) |> date_time_to_unix,
      end: Map.get(active_period, :end) |> date_time_to_unix
    }
    |> Map.filter(&filter_out_nil_values/1)
  end

  def build_informed_entities(nil), do: nil

  def build_informed_entities(informed_entities) do
    Enum.map(informed_entities, &build_informed_entity/1)
  end

  def build_informed_entity(informed_entity) do
    %{
      agency_id: Map.get(informed_entity, :agency_id),
      route_type: Map.get(informed_entity, :route_type),
      facility_id: Map.get(informed_entity, :facility_id),
      route_id: Map.get(informed_entity, :route_id),
      trip: Map.get(informed_entity, :trip) |> build_trip,
      direction_id: Map.get(informed_entity, :direction_id),
      stop_id: Map.get(informed_entity, :stop_id),
      activities: Map.get(informed_entity, :activities)
    }
    |> Map.filter(&filter_out_nil_values/1)
  end

  def build_trip(nil), do: nil

  def build_trip(trip) do
    %{
      route_id: Map.get(trip, :route_id),
      trip_id: Map.get(trip, :trip_id),
      direction_id: Map.get(trip, :direction_id),
      start_time: Map.get(trip, :start_time) |> extended_time_to_string,
      start_date: Map.get(trip, :start_date) |> date_to_string,
      schedule_relationship: Map.get(trip, :schedule_relationship)
    }
    |> Map.filter(&filter_out_nil_values/1)
  end

  defp build_translated_string(nil), do: nil

  defp build_translated_string(input_string) do
    %{
      translation: [
        %{
          text: input_string,
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
  defp date_time_to_unix(time), do: DateTime.to_unix(time)

  defp filter_out_nil_values({_key, value}), do: !is_nil(value)
end
