defmodule AlertsUI.FeedOutput.GTFSProtobufDefinition do
  @moduledoc """
    Reads in GTFS protobuf definition
  """
  use Protox,
    files: [AlertsUI.config(:gtfs_proto_filename)],
    namespace: __MODULE__
end

defmodule AlertsUI.FeedOutput.CreateGtfsProtobuf do
  @moduledoc """
    Given a list of standard alerts, outputs a protobuf ready to write to file
  """
  alias AlertsUI.FeedOutput.{CreateOutputAlert, CreateStandardAlert}

  alias AlertsUI.FeedOutput.GTFSProtobufDefinition.TransitRealtime.{
    Alert,
    EntitySelector,
    FeedEntity,
    FeedHeader,
    FeedMessage,
    TimeRange,
    TranslatedImage,
    TranslatedString,
    TripDescriptor
  }

  def output_protobuf(alerts) do
    header = struct(FeedHeader, CreateOutputAlert.build_gtfs_header())

    entity =
      alerts
      |> Enum.map(&CreateStandardAlert.build_standard_alert/1)
      |> Enum.map(fn alert ->
        %FeedEntity{
          id: alert.id,
          alert: build_alert(alert.alert || alert["alert"])
        }
      end)

    {:ok, iodata, _size} =
      %FeedMessage{header: header, entity: entity}
      |> Protox.encode()

    IO.iodata_to_binary(iodata)
  end

  def build_alert(alert) do
    alert
    |> Map.Helpers.atomize_keys()
    |> Map.replace_lazy(:active_period, &Enum.map(&1, fn ap -> build_time_range(ap) end))
    |> Map.replace_lazy(:informed_entity, &Enum.map(&1, fn ie -> build_entity_selector(ie) end))
    |> Map.replace_lazy(:url, &build_translated_string/1)
    |> Map.replace_lazy(:header_text, &build_translated_string/1)
    |> Map.replace_lazy(:description_text, &build_translated_string/1)
    |> Map.replace_lazy(:tts_header_text, &build_translated_string/1)
    |> Map.replace_lazy(:tts_description_text, &build_translated_string/1)
    |> Map.replace_lazy(:image, &build_translated_image/1)
    |> Map.replace_lazy(:image_alternative_text, &build_translated_string/1)
    |> Map.replace_lazy(:cause_detail, &string_to_translated_string/1)
    |> Map.replace_lazy(:effect_detail, &string_to_translated_string/1)
    |> Map.replace_lazy(:cause, &enumify_value/1)
    |> Map.replace_lazy(:effect, &enumify_value/1)
    |> Map.replace_lazy(:severity_level, &enumify_value/1)
    |> then(fn alert -> struct(Alert, alert) end)
  end

  def build_entity_selector(informed_entity) do
    informed_entity
    |> Map.replace_lazy(:trip, &build_trip_descriptor/1)
    |> then(fn ie -> struct(EntitySelector, ie) end)
  end

  def build_trip_descriptor(trip) do
    trip
    |> Map.replace_lazy(:schedule_relationship, &enumify_value/1)
    |> then(fn trip -> struct(TripDescriptor, trip) end)
  end

  def build_time_range(time_range) do
    struct(TimeRange, time_range)
  end

  defp string_to_translated_string(%{translation: [_]} = input) do
    input |> build_translated_string()
  end

  defp string_to_translated_string(%{"translation" => [_]} = input) do
    input
    |> Map.Helpers.atomize_keys()
    |> build_translated_string()
  end

  defp string_to_translated_string(input_string) do
    %{
      translation: [
        %{
          text: input_string,
          language: "en"
        }
      ]
    }
    |> build_translated_string
  end

  def build_translated_string(translated_string) do
    translated_string
    |> Map.replace_lazy(
      :translation,
      &Enum.map(&1, fn translation -> struct(TranslatedString.Translation, translation) end)
    )
    |> then(fn ts -> struct(TranslatedString, ts) end)
  end

  def build_translated_image(translated_image) do
    translated_image
    |> Map.replace_lazy(
      :localized_image,
      &Enum.map(&1, fn localization -> struct(TranslatedImage.LocalizedImage, localization) end)
    )
    |> then(fn ti -> struct(TranslatedImage, ti) end)
  end

  def enumify_value(value) when is_atom(value), do: value
  def enumify_value(value) when is_number(value), do: value

  def enumify_value(value) do
    String.to_existing_atom(value)
  end
end
