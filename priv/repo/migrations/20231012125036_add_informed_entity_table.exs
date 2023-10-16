defmodule AlertsUI.Repo.Migrations.AddInformedEntityTable do
  use Ecto.Migration
  alias AlertsUI.Models.Activity

  def change do
    activity_list =
      Activity.activities()
      |> Enum.map(&"'#{&1}'")
      |> Enum.join(", ")

    execute("CREATE TYPE activities AS ENUM (#{activity_list});")

    create table("informed_entities") do
      add :alert_id, references(:alerts)
      add :agency_id, :string
      add :route_id, :string
      add :route_type, :integer
      add :direction_id, :integer
      add :stop_id, :string
      add(:activities, {:array, :activities}, default: [])
      timestamps()
    end
  end
end
