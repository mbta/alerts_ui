defmodule AlertsUI.Models.Alert do
  @moduledoc """
    Models an alert
  """
  use AlertsUI.Schema

  alias AlertsUI.Models.{
    ActivePeriod,
    AlertLifecycle,
    Cause,
    DurationCertainty,
    Effect,
    InformedEntity,
    SeverityLevel
  }

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
          timeframe_text: String.t() | nil,
          alert_lifecycle: atom() | nil,
          duration_certainty: atom() | nil,
          active_period: [String.t()] | nil,
          image_url: String.t() | nil,
          image_alternative_text: String.t() | nil,
          informed_entity: [InformedEntity.t()]
        }

  schema "alerts" do
    field :alert_id, :string
    field :effect, Ecto.Enum, values: @effect
    field :effect_detail, :string
    field :cause, Ecto.Enum, values: @cause
    field :cause_detail, :string
    field :header_text, :string
    field :description_text, :string
    field :severity_level, Ecto.Enum, values: @severity_level
    field :url, :string
    field :service_effect_text, :string
    field :short_header_text, :string
    field :severity, :integer
    field :created_timestamp, :utc_datetime
    field :last_modified_timestamp, :utc_datetime
    field :last_push_notification_timestamp, :utc_datetime
    field :timeframe_text, :string
    field :alert_lifecycle, Ecto.Enum, values: @alert_lifecycle
    field :duration_certainty, Ecto.Enum, values: @duration_certainty
    embeds_many :active_period, ActivePeriod
    field :image_url, :string
    field :image_alternative_text, :string
    has_many :informed_entity, InformedEntity
    timestamps()
  end
end
