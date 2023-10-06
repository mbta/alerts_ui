defmodule AlertsUI.Models.Alert do
  @moduledoc """
    Models an alert
  """
  use AlertsUI.Schema
  alias AlertsUI.Repo
  alias AlertsUI.Models.Cause, as: Cause
  alias AlertsUI.Models.Effect, as: Effect


  schema "alerts" do
    field :alert_id, :string
    field :effect, Ecto.Enum, values: Repo.all(Effect) |> Enum.map(& &1.name)
    field :effect_detail, :string
    field :cause, Ecto.Enum, values: Repo.all(Cause) |> Enum.map(& &1.name)
    field :cause_detail, :string
    field :header_text, :string
    field :description_text, :string
    field :severity_level, :string
    field :url, :string
    field :service_effect_text, :string
    field :short_header_text, :string
    field :severity, :integer
    field :created_timestamp, :utc_datetime
    field :last_modified_timestamp, :utc_datetime
    field :last_push_notification_timestamp, :utc_datetime
    field :timeframe_text, :string
    field :alert_lifecycle, :string
    field :duration_certainty, :string
    embeds_one :active_period, :string
    field :image_url, :string
    field :image_alternative_text, :string
    timestamps()
  end
end
