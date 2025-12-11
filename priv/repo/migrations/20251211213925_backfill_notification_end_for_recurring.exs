defmodule AlertsUI.Repo.Migrations.BackfillNotificationEndForRecurring do
  use Ecto.Migration

  def change do
    # fix the recurring alerts notification_period_end
    execute("
      UPDATE alerts SET notification_period_end = active_period_end WHERE duration_certainty != 'ESTIMATED' AND recurrence_start_time is not NULL
    ")
  end
end
