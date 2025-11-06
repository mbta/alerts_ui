defmodule AlertsUI.Models.Alert do
  @moduledoc """
    Models an alert

    Notes on some fields:
    several fields are meant to store information about the things that were originally selected on the form, for
    use when editing/duplicating alerts, building alert history, and anywhere else convenient. The fields named
    original_<something>_selection are used for this purpose. They consist of an array of strings, which are pipe-
    delineated- "name|id". This module contains funcions for splitting those apart and returning just the names or ids.
    Primary service type is the selected route type from the form and can be string of a number 0-4, "access", or "systemwide"

    plaintext_reminder_selections is just a string of datetimes in EST. It's meant to be used for version history purposes and nothing else.
    It is not used for the form.

    Recurrence times are stored in their original EST form. They are meant for front-end use only.
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

  alias AlertsUI.Models.User

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
  effect_name
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
  notification_period_start
  notification_period_end
  recurrence_days
  recurrence_times
  original_route_selections
  original_stop_selections
  original_trip_selections
  original_direction_selections
  original_facility_selections
  plaintext_reminder_selections
  primary_service_type)a

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
          effect_name: String.t() | nil,
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
          notification_period_start: DateTime.t() | nil,
          notification_period_end: DateTime.t() | nil,
          original_route_selections: [String.t()] | nil,
          original_stop_selections: [String.t()] | nil,
          original_trip_selections: [String.t()] | nil,
          original_direction_selections: [String.t()] | nil,
          original_facility_selections: [String.t()] | nil,
          plaintext_reminder_selections: String.t() | nil,
          user_id: User.id(),
          primary_service_type: String.t(),
          recurrence_days: [String.t()],
          recurrence_times: [Time.t()] | nil
        }

  @derive {
    Flop.Schema,
    filterable: [
      :alert_id,
      :effect_detail,
      :text_content,
      :effects,
      :routes,
      :service_type,
      :timeline,
      :multi_column_search
    ],
    sortable: [
      # service,
      :effect_detail,
      :integer_alert_id,
      :active_period_start,
      :active_period_end,
      :duration_certainty,
      :notification_period_end,
      :notification_period_start
    ],
    adapter_opts: [
      alias_fields: [:integer_alert_id],
      compound_fields: [text_content: [:header_text, :description_text]],
      custom_fields: [
        effects: [
          filter: {CustomFilters, :effects_filter, []},
          ecto_type: {:array, :string},
          operators: [:==]
        ],
        routes: [
          filter: {CustomFilters, :routes_filter, []},
          ecto_type: {:array, :string},
          operators: [:==]
        ],
        service_type: [
          filter: {CustomFilters, :service_type_filter, []},
          bindings: [:informed_entity],
          ecto_type: {:array, :string},
          operators: [:==]
        ],
        timeline: [
          filter: {CustomFilters, :timeline_filter, []},
          ecto_type: :string,
          operators: [:==]
        ],
        multi_column_search: [
          filter: {CustomFilters, :multi_column_search_filter, []},
          ecto_type: :string,
          operators: [:==]
        ]
      ]
    ]
  }

  schema "alerts" do
    belongs_to :user, User, on_replace: :nilify
    field :alert_id, :string
    field :effect, Ecto.Enum, values: @effect
    field :effect_detail, :string
    field :effect_name, :string
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
    has_many :active_period, ActivePeriod, on_replace: :delete
    field :active_period_start, :utc_datetime
    field :active_period_end, :utc_datetime
    field :image_url, :string
    field :image_alternative_text, :string
    field :tts_header_text, :string
    field :tts_description_text, :string
    has_many :informed_entity, InformedEntity, on_replace: :nilify
    field :draft, :boolean, default: false
    field :notification_period_start, :utc_datetime
    field :notification_period_end, :utc_datetime
    field :plaintext_reminder_selections, :string
    field :primary_service_type, :string

    field :recurrence_days, {:array, Ecto.Enum},
      values: ~w[sunday monday tuesday wednesday thursday friday saturday]a

    field :recurrence_times, {:array, :time}
    field :original_route_selections, {:array, :string}
    field :original_stop_selections, {:array, :string}
    field :original_trip_selections, {:array, :string}
    field :original_direction_selections, {:array, :string}
    field :original_facility_selections, {:array, :string}

    timestamps()
  end

  @spec changeset(any(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = alert, params) do
    alert
    |> cast(params, @permitted_fields)
    |> cast_assoc(:active_period, required: false, with: &ActivePeriod.changeset/2)
    |> cast_assoc(:informed_entity, required: true, with: &InformedEntity.changeset/2)
    |> cast_assoc(:reminder_times, required: false, with: &ReminderTime.changeset/2)
    |> validate_change(:recurrence_days, fn :recurrence_days, recurrence_days ->
      active_period_start =
        Map.get(params, :active_period_start) |> DateTime.shift_zone!("America/New_York")

      cond do
        Enum.empty?(recurrence_days) ->
          []

        Timex.weekday(active_period_start) in Enum.map(recurrence_days, &Timex.day_to_num/1) ->
          []

        true ->
          [
            recurrence_days: {"Alert start day must match a selected day of the week.", []}
          ]
      end
    end)
    |> validate_timestamps()
    |> validate_inclusion(:effect, @effect)
    |> validate_inclusion(:cause, @cause)
    |> validate_inclusion(:severity_level, @severity_level)
    |> validate_inclusion(:alert_lifecycle, @alert_lifecycle)
    |> validate_inclusion(:duration_certainty, @duration_certainty)
    |> validate_required([:header_text], message: "is required")
    |> validate_length(:informed_entity, min: 1)
    |> validate_length(:active_period, min: 1)
    |> unique_constraint(:alert_id)
  end

  @spec draft_changeset(any(), map()) :: Ecto.Changeset.t()
  def draft_changeset(%__MODULE__{} = alert, params) do
    alert
    |> cast(params, @permitted_fields)
    |> cast_assoc(:active_period, required: false, with: &ActivePeriod.changeset/2)
    |> cast_assoc(:informed_entity, required: false, with: &InformedEntity.changeset/2)
    |> cast_assoc(:reminder_times, required: false, with: &ReminderTime.changeset/2)
    |> validate_acceptance(:draft, message: "draft status must be true")
    |> validate_inclusion(:effect, @effect)
    |> validate_inclusion(:cause, @cause)
    |> validate_inclusion(:severity_level, @severity_level)
    |> validate_inclusion(:alert_lifecycle, @alert_lifecycle)
    |> validate_inclusion(:duration_certainty, @duration_certainty)
    |> unique_constraint(:alert_id)
  end

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
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  def gather_stop_ids(informed_entities) do
    informed_entities
    |> Enum.map(&Map.get(&1, :stop_id))
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  def gather_parent_stop_ids(informed_entities) do
    informed_entities
    |> Enum.map(fn ie ->
      ie_stop_id = Map.get(ie, :stop_id)
      parent_stop = StopsRepo.get_parent(ie_stop_id) || %{}
      Map.get(parent_stop, :id) || ie_stop_id
    end)
    |> Enum.reject(&is_nil/1)
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
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  def get_original_names(nil), do: []

  def get_original_names(names_and_ids) do
    Enum.map(names_and_ids, fn name_and_id ->
      name_and_id |> String.split("|") |> get_name
    end)
  end

  def get_original_ids(nil), do: []

  def get_original_ids(names_and_ids) do
    Enum.map(names_and_ids, fn name_and_id ->
      name_and_id |> String.split("|") |> get_id
    end)
  end

  defp get_name([name, _id]), do: name
  # backwards compatibility for older alerts
  defp get_name([name]), do: name

  defp get_id([id]), do: id
  defp get_id([_name, id]), do: id

  @spec simple_subway_type(Route.type_int()) :: Route.type_int()
  defp simple_subway_type(0), do: 1
  defp simple_subway_type(route_type), do: route_type

  @spec validate_timestamps(Ecto.Changeset.t()) :: Ecto.Changeset.t()
  defp validate_timestamps(changeset) do
    active_period_end = get_field(changeset, :active_period_end)
    duration_certainty = get_field(changeset, :duration_certainty)

    if duration_certainty == :UNKNOWN && active_period_end do
      add_error(changeset, :active_period_end, "Alerts of unknown duration can't have end times")
    else
      changeset
    end
  end
end
