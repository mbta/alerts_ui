defmodule AlertsUI.Repo.Migrations.BackfillAlertFields do
  use Ecto.Migration

  def change do
    # fill in any missing `active_period_start` fields
    execute("
      UPDATE alerts SET active_period_start = '01-01-2023' WHERE active_period_start IS NULL 
    ")

    # sync any missing `notification_period_start` with `active_period_start`
    execute("
      UPDATE alerts SET notification_period_start = active_period_start WHERE notification_period_start IS NULL 
    ")

    # make `active_period_start` non-nullable
    execute("ALTER TABLE alerts ALTER COLUMN active_period_start SET NOT NULL")

    # for alerts with no active periods, leave `active_period_end`, `notification_period_end`
    # and `closed_timestamp` unchanged if present, set to the first not null value of that
    # group, or one hour after `active_period_start` if all all null
    execute("
      UPDATE alerts SET
        active_period_end = COALESCE(active_period_end, closed_timestamp, notification_period_end, active_period_start + INTERVAL '1 hour'),
        closed_timestamp = COALESCE(closed_timestamp, active_period_end, notification_period_end, active_period_start + INTERVAL '1 hour'),
        notification_period_end = COALESCE(notification_period_end, closed_timestamp, active_period_end, active_period_start + INTERVAL '1 hour')
      WHERE id NOT IN(SELECT alert_id FROM active_period);
    ")
  end
end
