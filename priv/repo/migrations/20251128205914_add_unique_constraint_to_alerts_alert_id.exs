defmodule AlertsUI.Repo.Migrations.AddUniqueConstraintToAlertsAlertId do
  use Ecto.Migration

  def change do
    create unique_index(:alerts, :alert_id)
  end
end
