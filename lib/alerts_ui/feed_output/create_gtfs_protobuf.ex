defmodule AlertsUI.FeedOutput.GTFSProtobufDefinition do
  @moduledoc """
    Reads in GTFS protobuf definition
  """
  use Protobuf, from: AlertsUI.config(:gtfs_proto_filename)
end

defmodule AlertsUI.FeedOutput.CreateGtfsProtobuf do
  @moduledoc """
    Given a list of standard alerts, outputs a protobuf ready to write to file
  """
  alias AlertsUI.FeedOutput.{CreateOutputAlert, CreateStandardAlert}

  alias AlertsUI.FeedOutput.GTFSProtobufDefinition.{
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

  @spec output_protobuf([map()]) :: binary()
  def output_protobuf(alerts) do
    header = FeedHeader.new(CreateOutputAlert.build_gtfs_header())

    entity =
      alerts
      |> Enum.map(&CreateStandardAlert.build_standard_alert/1)
      |> Enum.map(fn alert ->
        %{
          id: alert.id,
          alert: build_alert(alert.alert || alert["alert"])
        }
        |> FeedEntity.new()
      end)

    FeedMessage.new(header: header, entity: entity)
    |> FeedMessage.encode()
  end

  @spec build_alert(map()) :: Alert.t()
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
    |> Alert.new()
  end

  @spec build_entity_selector(map()) :: EntitySelector.t()
  def build_entity_selector(informed_entity) do
    informed_entity
    |> Map.replace_lazy(:trip, &build_trip_descriptor/1)
    |> EntitySelector.new()
  end

  @spec build_trip_descriptor(map()) :: TripDescriptor.t()
  def build_trip_descriptor(trip) do
    trip
    |> Map.replace_lazy(:schedule_relationship, &enumify_value/1)
    |> TripDescriptor.new()
  end

  @spec build_time_range(map()) :: TimeRange.t()
  def build_time_range(time_range) do
    time_range
    |> TimeRange.new()
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

  @spec build_translated_string(map()) :: TranslatedString.t()
  def build_translated_string(translated_string) do
    translated_string
    |> Map.replace_lazy(
      :translation,
      &Enum.map(&1, fn translation -> TranslatedString.Translation.new(translation) end)
    )
    |> TranslatedString.new()
  end

  @spec build_translated_image(map()) :: TranslatedImage.t()
  def build_translated_image(translated_image) do
    translated_image
    |> Map.replace_lazy(
      :localized_image,
      &Enum.map(&1, fn localization -> TranslatedImage.LocalizedImage.new(localization) end)
    )
    |> TranslatedImage.new()
  end

  @spec enumify_value(atom() | number() | String.t()) :: atom() | number()
  def enumify_value(value) when is_atom(value), do: value
  def enumify_value(value) when is_number(value), do: value

  def enumify_value(value) do
    String.to_existing_atom(value)
  end
end
