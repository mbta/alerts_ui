defmodule AlertsUI.Repo.Migrations.AddAlertTable do
  use Ecto.Migration

  def change do
    drop table("causes")
    drop table("effects")

    cause_list =
      AlertsUI.Models.Cause.causes()
      |> Enum.map(&"'#{&1}'")
      |> Enum.join(", ")

    effect_list =
      AlertsUI.Models.Effect.effects()
      |> Enum.map(&"'#{&1}'")
      |> Enum.join(", ")

    execute("CREATE TYPE effects AS ENUM (#{effect_list});")

    execute("CREATE TYPE causes AS ENUM (#{cause_list});")

    create table("alerts") do
      add :alert_id, :string
      add :effect, :effects
      add :effect_detail, :string
      add :cause, :causes
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
