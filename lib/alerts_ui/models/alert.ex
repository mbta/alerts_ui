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
    DurationCertainty,
    Effect,
    InformedEntity,
    SeverityLevel
  }

  @permitted_fields ~w(
  id
  created_at
  updated_at
  alert_id
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
  reminder_times
  tts_header_text
  tts_description_text
  image_url
  image_alternative_text)a

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
          effect: atom() | nil,
          effect_detail: String.t() | nil,
          cause: atom() | nil,
          cause_detail: String.t() | nil,
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
          reminder_times: [integer()] | nil,
          active_period: [ActivePeriod.t()] | nil,
          image_url: String.t() | nil,
          image_alternative_text: String.t() | nil,
          image_url: String.t() | nil,
          tts_header_text: String.t() | nil,
          tts_description_text: String.t() | nil,
          informed_entity: [InformedEntity.t()]
        }

  @derive {
    Flop.Schema,
    filterable: [:closed_timestamp],
    sortable: [:alert_id, :created_timestamp, :active_period],
    default_order: %{
      order_by: [:created_timestamp, :alert_id],
      order_directions: [:desc, :desc]
    }
  }

  schema "alerts" do
    field :alert_id, :string
    field :effect, Ecto.Enum, values: @effect
    field :effect_detail, :string
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
    field :reminder_times, {:array, :integer}
    embeds_many :active_period, ActivePeriod, on_replace: :delete
    field :image_url, :string
    field :image_alternative_text, :string
    field :tts_header_text, :string
    field :tts_description_text, :string
    has_many :informed_entity, InformedEntity, on_replace: :nilify
    timestamps()
  end

  @spec changeset(any(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = alert, params) do
    alert
    |> cast(params, @permitted_fields)
    |> cast_embed(:active_period, required: false, with: &ActivePeriod.changeset/2)
    |> cast_assoc(:informed_entity, required: true, with: &InformedEntity.changeset/2)
    |> validate_inclusion(:effect, @effect)
    |> validate_inclusion(:cause, @cause)
    |> validate_inclusion(:severity_level, @severity_level)
    |> validate_inclusion(:alert_lifecycle, @alert_lifecycle)
    |> validate_inclusion(:duration_certainty, @duration_certainty)
    |> validate_required([:header_text, :alert_id])
    |> validate_length(:informed_entity, min: 1)
    |> unique_constraint(:alert_id)
  end
end
