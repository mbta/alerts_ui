defmodule AlertsUI.Repo.Migrations.RemoveRecurrenceDataFromOneTimeAlerts do
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

    execute("""
      UPDATE alerts
      SET recurrence_days = NULL,
          recurrence_text = NULL,
          recurrence_start_time = NULL,
          recurrence_end_time = NULL
       WHERE recurring = false
    """)
  end

  def down do
  end
end
