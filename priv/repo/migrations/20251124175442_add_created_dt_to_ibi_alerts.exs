defmodule AlertsUI.Repo.Migrations.AddCreatedDtToIbiAlerts do
  use Ecto.Migration

  def change do
    alter table(:ibi_alerts) do
      add :created_dt, :text
    end
  end
end
