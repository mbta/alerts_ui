defmodule AlertsUI.Models.Alert do
  @moduledoc """
    Models an alert
  """
  use AlertsUI.Schema
  import Ecto.Changeset

  alias AlertsUI.Models.{
    ActivePeriod,
    AlertLifecycle,
    Cause,
    CustomFilters,
    DurationCertainty,
    Effect,
    InformedEntity,
    ReminderTime,
    SeverityLevel
  }

  alias MBTAV3API.Routes.Route
  alias MBTAV3API.Stops.Repo, as: StopsRepo

  @permitted_fields ~w(
  id
  created_at
  updated_at
  alert_id
  draft
  banner_text
  effect
  effect_detail
  cause
  cause_detail
  header_text
  description_text
  severity_level
  url
  service_effect_text
  short_header_text
  severity
  created_timestamp
  last_modified_timestamp
  last_push_notification_timestamp
  closed_timestamp
  timeframe_text
  recurrence_text
  alert_lifecycle
  duration_certainty
  tts_header_text
  tts_description_text
  image_url
  image_alternative_text
  active_period_start
  active_period_end
  notification_period_start)a

  @cause Cause.causes()
  @effect Effect.effects()
  @severity_level SeverityLevel.severity_levels()
  @alert_lifecycle AlertLifecycle.alert_lifecycles()
  @duration_certainty DurationCertainty.duration_certainties()

  @type t :: %__MODULE__{
          id: Ecto.UUID,
          created_at: DateTime.t(),
          updated_at: DateTime.t(),
          alert_id: String.t(),
          banner_text: String.t() | nil,
          effect: atom() | nil,
          effect_detail: String.t() | nil,
          cause: atom() | nil,
          cause_detail: String.t() | nil,
          draft: boolean(),
          header_text: String.t(),
          description_text: String.t(),
          severity_level: atom() | nil,
          url: String.t() | nil,
          service_effect_text: String.t() | nil,
          short_header_text: String.t() | nil,
          severity: integer() | nil,
          created_timestamp: DateTime.t() | nil,
          last_modified_timestamp: DateTime.t() | nil,
          last_push_notification_timestamp: DateTime.t() | nil,
          closed_timestamp: DateTime.t() | nil,
          timeframe_text: String.t() | nil,
          recurrence_text: String.t() | nil,
          alert_lifecycle: atom() | nil,
          duration_certainty: atom() | nil,
          reminder_times: [ReminderTime.t()] | nil,
          active_period: [ActivePeriod.t()] | nil,
          active_period_start: DateTime.t() | nil,
          active_period_end: DateTime.t() | nil,
          image_url: String.t() | nil,
          image_alternative_text: String.t() | nil,
          tts_header_text: String.t() | nil,
          tts_description_text: String.t() | nil,
          informed_entity: [InformedEntity.t()],
          notification_period_start: DateTime.t() | nil
        }

  @derive {
    Flop.Schema,
    filterable: [:alert_id, :effect_detail, :text_content, :service_type, :timeline],
    sortable: [
      :integer_alert_id,
      :created_at,
      :active_period_start,
      :active_period_end,
      :closed_timestamp
    ],
    adapter_opts: [
      alias_fields: [:integer_alert_id],
      compound_fields: [text_content: [:header_text, :description_text]],
      custom_fields: [
        service_type: [
          filter: {CustomFilters, :service_type_filter, []},
          ecto_type: :string,
          operators: [:==],
          bindings: [:informed_entity]
        ],
        timeline: [
          filter: {CustomFilters, :timeline_filter, []},
          ecto_type: :string,
          operators: [:==]
        ]
      ]
    ],
    default_order: %{
      order_by: [:created_at, :integer_alert_id, :active_period_start, :active_period_end],
      order_directions: [:desc_nulls_last, :desc_nulls_last, :desc_nulls_last, :desc_nulls_last]
    }
  }

  schema "alerts" do
    field :alert_id, :string
    field :effect, Ecto.Enum, values: @effect
    field :effect_detail, :string
    field :banner_text, :string
    field :cause, Ecto.Enum, values: @cause
    field :cause_detail, :string
    field :header_text, :string
    field :description_text, :string, default: ""
    field :severity_level, Ecto.Enum, values: @severity_level
    field :url, :string
    field :service_effect_text, :string
    field :short_header_text, :string
    field :severity, :integer
    field :created_timestamp, :utc_datetime
    field :last_modified_timestamp, :utc_datetime
    field :last_push_notification_timestamp, :utc_datetime
    field :closed_timestamp, :utc_datetime
    field :timeframe_text, :string
    field :recurrence_text, :string
    field :alert_lifecycle, Ecto.Enum, values: @alert_lifecycle
    field :duration_certainty, Ecto.Enum, values: @duration_certainty
    has_many :reminder_times, ReminderTime, on_replace: :delete
    embeds_many :active_period, ActivePeriod, on_replace: :delete
    field :active_period_start, :utc_datetime
    field :active_period_end, :utc_datetime
    field :image_url, :string
    field :image_alternative_text, :string
    field :tts_header_text, :string
    field :tts_description_text, :string
    has_many :informed_entity, InformedEntity, on_replace: :nilify
    field :draft, :boolean, default: false
    field :notification_period_start, :utc_datetime
    timestamps()
  end

  @spec changeset(any(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = alert, params) do
    current_time = Map.get(params, :current_time)

    alert
    |> cast(params, @permitted_fields)
    |> cast_embed(:active_period, required: false, with: &ActivePeriod.changeset/2)
    |> cast_assoc(:informed_entity, required: true, with: &InformedEntity.changeset/2)
    |> cast_assoc(:reminder_times, required: false, with: &ReminderTime.changeset/2)
    |> validate_change(:active_period_start, fn :active_period_start, active_period_start ->
      if is_nil(current_time) or
           DateTime.compare(active_period_start, DateTime.truncate(current_time, :second)) in [
             :eq,
             :gt
           ] do
        []
      else
        [active_period_start: "Effect can't start in the past"]
      end
    end)
    |> validate_inclusion(:effect, @effect)
    |> validate_inclusion(:cause, @cause)
    |> validate_inclusion(:severity_level, @severity_level)
    |> validate_inclusion(:alert_lifecycle, @alert_lifecycle)
    |> validate_inclusion(:duration_certainty, @duration_certainty)
    |> validate_required([:header_text], message: "is required")
    |> validate_length(:informed_entity, min: 1)
    |> unique_constraint(:alert_id)
  end

  @spec draft_changeset(any(), map()) :: Ecto.Changeset.t()
  def draft_changeset(%__MODULE__{} = alert, params) do
    alert
    |> cast(params, @permitted_fields)
    |> cast_embed(:active_period, required: false, with: &ActivePeriod.changeset/2)
    |> cast_assoc(:informed_entity, required: false, with: &InformedEntity.changeset/2)
    |> validate_acceptance(:draft, message: "draft status must be true")
    |> validate_inclusion(:effect, @effect)
    |> validate_inclusion(:cause, @cause)
    |> validate_inclusion(:severity_level, @severity_level)
    |> validate_inclusion(:alert_lifecycle, @alert_lifecycle)
    |> validate_inclusion(:duration_certainty, @duration_certainty)
    |> unique_constraint(:alert_id)
  end

  @spec entities_with_icons(t()) :: [String.t()]
  def entities_with_icons(%__MODULE__{informed_entity: entities}) do
    entities
    |> Enum.flat_map(&routes_or_facilities/1)
    |> Enum.uniq()
  end

  @spec routes_or_facilities(InformedEntity.t()) :: [String.t()]
  defp routes_or_facilities(%InformedEntity{route_id: route_id}) when not is_nil(route_id),
    do: [route_id]

  defp routes_or_facilities(%InformedEntity{activities: activities})
       when not is_nil(activities) do
    activities
    |> Enum.filter(&InformedEntity.facility_activity?/1)
    |> Enum.map(&combine_bike_activities/1)
    |> Enum.map(&Atom.to_string/1)
  end

  defp routes_or_facilities(_), do: []

  defp combine_bike_activities(:bringing_bike), do: :bike
  defp combine_bike_activities(:store_bike), do: :bike
  defp combine_bike_activities(other), do: other

  def get_direction([]), do: nil

  def get_direction(informed_entities) do
    directions_list =
      informed_entities
      |> Enum.map(fn ie ->
        if is_nil(Map.get(ie, :direction_id)) do
          trip = Map.get(ie, :trip) || %{}
          Map.get(trip, :direction_id)
        else
          ie.direction_id
        end
      end)
      |> Enum.uniq()
      |> Enum.filter(&(!is_nil(&1)))

    if length(directions_list) == 1 do
      hd(directions_list) |> Integer.to_string()
    else
      nil
    end
  end

  @spec systemwide?(t()) :: boolean()
  def systemwide?(%__MODULE__{informed_entity: informed_entities}),
    do: Enum.any?(informed_entities, &(!InformedEntity.route_id?(&1)))

  @spec get_route_type(t()) :: Route.type_int() | nil
  def get_route_type(%__MODULE__{informed_entity: informed_entities} = alert) do
    if systemwide?(alert) do
      nil
    else
      do_get_route_type(informed_entities)
    end
  end

  def do_get_route_type([]), do: nil

  def do_get_route_type(informed_entities) do
    case Enum.any?(informed_entities, &(InformedEntity.route_type(&1) in [0, 1])) do
      true ->
        1

      false ->
        informed_entities
        |> hd()
        |> InformedEntity.route_type()
    end
  end

  @spec service_types(t()) :: [Route.type_int()]
  def service_types(%__MODULE__{informed_entity: informed_entities} = alert) do
    if systemwide?(alert) do
      informed_entities
      |> Enum.map(&InformedEntity.route_type(&1))
      |> Enum.map(&simple_subway_type/1)
      |> Enum.uniq()
    else
      []
    end
  end

  def gather_route_ids(informed_entities) do
    informed_entities
    |> Enum.map(&Map.get(&1, :route_id))
    |> Enum.filter(&(!is_nil(&1)))
    |> Enum.uniq()
  end

  def gather_facility_ids(informed_entities) do
    informed_entities
    |> Enum.map(&Map.get(&1, :facility_id))
    |> Enum.filter(&(!is_nil(&1)))
    |> Enum.uniq()
  end

  def gather_parent_stop_ids(informed_entities) do
    informed_entities
    |> Enum.map(fn ie ->
      ie_stop_id = Map.get(ie, :stop_id)
      parent_stop = StopsRepo.get_parent(ie_stop_id) || %{}
      Map.get(parent_stop, :id) || ie_stop_id
    end)
    |> Enum.filter(&(!is_nil(&1)))
    |> Enum.uniq()
  end

  def gather_trip_ids(informed_entities) do
    informed_entities
    |> Enum.map(fn ie ->
      case Map.get(ie, :trip) do
        nil -> nil
        trip -> Map.get(trip, :trip_id)
      end
    end)
    |> Enum.filter(&(!is_nil(&1)))
    |> Enum.uniq()
  end

  @spec simple_subway_type(Route.type_int()) :: Route.type_int()
  defp simple_subway_type(0), do: 1
  defp simple_subway_type(route_type), do: route_type
end
