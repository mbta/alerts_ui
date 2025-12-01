defmodule AlertsUI.Repo.Migrations.AddIsClosedIndexToIbiAlerts do
  use Ecto.Migration

  def change do
    create index(:ibi_alerts, [:is_closed])
  end
end
