defmodule AlertsUI.Repo.Migrations.AssignRecurringOnRecurringAlerts do
  use Ecto.Migration

  def up do
    execute("""
      UPDATE alerts
      SET recurring = COALESCE((
        SELECT COUNT(*) >= 2
        FROM active_period
        WHERE active_period.alert_id = alerts.id
      ), false)
    """)
  end

  def down do
  end
end
