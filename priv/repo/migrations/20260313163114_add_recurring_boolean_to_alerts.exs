defmodule AlertsUI.Repo.Migrations.AddRecurringBooleanToAlerts do
  use Ecto.Migration

  def change do
    alter table(:alerts) do
      add :recurring, :boolean, default: false, null: false
    end
  end
end
