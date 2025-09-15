defmodule AlertsUI.Repo.Migrations.BackfillNotificationEnd do
  use Ecto.Migration

  def change do
    # fill in any missing `active_period_start` fields
    execute("
      UPDATE alerts SET notification_period_end = active_period_end WHERE duration_certainty != 'ESTIMATED'
    ")
  end
end
