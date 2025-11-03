defmodule AlertsUI.Repo.Migrations.ConvertAlertVarcharsToText do
  use Ecto.Migration

  @varchars [
    :effect_detail,
    :cause_detail,
    :tts_header_text,
    :tts_description_text,
    :image_alternative_text,
    :service_effect_text,
    :short_header_text,
    :timeframe_text,
    :image_url,
    :recurrence_text,
    :banner_text,
    :effect_name,
    :plaintext_reminder_selections,
    :url,
    :primary_service_type
  ]

  @varchar_arrays [
    :original_trip_selections,
    :original_facility_selections,
    :original_direction_selections,
    :original_stop_selections,
    :original_route_selections
  ]

  def change do
    alter table(:alerts) do
      Enum.each(@varchars, fn field -> modify field, :text end)
      Enum.each(@varchar_arrays, fn field -> modify field, {:array, :text} end)
    end
  end
end
