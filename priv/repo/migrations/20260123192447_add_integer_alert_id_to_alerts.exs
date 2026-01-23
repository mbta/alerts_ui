defmodule AlertsUI.Repo.Migrations.AddIntegerAlertIdToAlerts do
  use Ecto.Migration

  def up do
    execute("
      ALTER TABLE alerts
        ADD COLUMN integer_alert_id INTEGER
        GENERATED ALWAYS AS (alert_id::INTEGER) STORED
      ")
  end

  def down do
    execute("ALTER TABLE alerts DROP COLUMN integer_alert_id CASCADE")
  end
end
