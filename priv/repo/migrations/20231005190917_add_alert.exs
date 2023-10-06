defmodule AlertsUI.Repo.Migrations.AddAlertTable do
  use Ecto.Migration

  def change do
    create table("alerts") do
      add :alert_id, :string
      add :effect, :string
      add :effect_detail, :string
      add :cause, :string
      add :cause_detail, :string
      add :header_text, :string
      add :description_text, :string
      add :severity_level, :string
      add :url, :string
      add :service_effect_text, :string
      add :short_header_text, :string
      add :severity, :integer
      add :created_timestamp, :utc_datetime
      add :last_modified_timestamp, :utc_datetime
      add :last_push_notification_timestamp, :utc_datetime
      add :timeframe_text, :string
      add :alert_lifecycle, :string
      add :duration_certainty, :string
      add(:active_period, {:array, :string}, default: [])
      add :image_url, :string
      add :image_alternative_text, :string
      timestamps()
    end
  end
end
