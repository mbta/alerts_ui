defmodule :"Elixir.AlertsUI.Repo.Migrations.AddMissingForeignKeyIndexes" do
  use Ecto.Migration

  def change do
    create index(:alerts, [:user_id])
    create index(:informed_entities, [:alert_id])
    create index(:reminder_times, [:alert_id])
    create index(:active_period, [:alert_id])
  end
end
