defmodule AlertsUI.Repo.Migrations.AddIndexToIntegerAlertId do
  use Ecto.Migration

  def change do
    create index(:alerts, [:integer_alert_id])
  end
end
