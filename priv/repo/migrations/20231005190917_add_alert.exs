defmodule AlertsUI.Repo.Migrations.AddAlertTable do
  use Ecto.Migration
  alias AlertsUI.Models.{AlertLifecycle, DurationCertainty, Cause, Effect, SeverityLevel}

  def change do
    drop table("causes")
    drop table("effects")

    cause_list =
      Cause.causes()
      |> Enum.map(&"'#{&1}'")
      |> Enum.join(", ")

    effect_list =
      Effect.effects()
      |> Enum.map(&"'#{&1}'")
      |> Enum.join(", ")

    severity_level_list =
      SeverityLevel.severity_levels()
      |> Enum.map(&"'#{&1}'")
      |> Enum.join(", ")

    alert_lifecycle_list =
      AlertLifecycle.alert_lifecycles()
      |> Enum.map(&"'#{&1}'")
      |> Enum.join(", ")

    duration_certainty_list =
      DurationCertainty.duration_certainties()
      |> Enum.map(&"'#{&1}'")
      |> Enum.join(", ")

    execute("CREATE TYPE effects AS ENUM (#{effect_list});")

    execute("CREATE TYPE causes AS ENUM (#{cause_list});")

    execute("CREATE TYPE severity_levels AS ENUM (#{severity_level_list});")

    execute("CREATE TYPE alert_lifecycles AS ENUM (#{alert_lifecycle_list});")

    execute("CREATE TYPE duration_certainty AS ENUM (#{duration_certainty_list});")

    create table("alerts") do
      add :alert_id, :string
      add :effect, :effects
      add :effect_detail, :string
      add :cause, :causes
      add :cause_detail, :string
      add :header_text, :string
      add :description_text, :string
      add :severity_level, :severity_levels
      add :url, :string
      add :service_effect_text, :string
      add :short_header_text, :string
      add :severity, :integer
      add :created_timestamp, :utc_datetime
      add :last_modified_timestamp, :utc_datetime
      add :last_push_notification_timestamp, :utc_datetime
      add :timeframe_text, :string
      add :alert_lifecycle, :alert_lifecycles
      add :duration_certainty, :duration_certainty
      add(:active_period, {:array, :map}, default: [])
      add :image_url, :string
      add :image_alternative_text, :string
      timestamps()
    end
  end
end
