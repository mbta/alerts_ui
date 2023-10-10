defmodule AlertsUI.Models.Alert do
  @moduledoc """
    Models an alert
  """
  use AlertsUI.Schema
  alias AlertsUI.Models.{AlertLifecycle, Cause, DurationCertainty, Effect, SeverityLevel}

  @cause Cause.causes() |> Enum.map(&String.to_atom(&1))
  @effect Effect.effects() |> Enum.map(&String.to_atom(&1))
  @severity_level SeverityLevel.severity_levels() |> Enum.map(&String.to_atom(&1))
  @alert_lifecycle AlertLifecycle.alert_lifecycles() |> Enum.map(&String.to_atom(&1))
  @duration_certainty DurationCertainty.duration_certainties() |> Enum.map(&String.to_atom(&1))

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
    embeds_one :active_period, :string
    field :image_url, :string
    field :image_alternative_text, :string
    timestamps()
  end
end
