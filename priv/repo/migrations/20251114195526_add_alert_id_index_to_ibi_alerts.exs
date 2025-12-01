defmodule AlertsUI.Repo.Migrations.AddAlertIdIndexToIbiAlerts do
  use Ecto.Migration

  def change do
    create index(:ibi_alerts, [:alert_id])
  end
end
