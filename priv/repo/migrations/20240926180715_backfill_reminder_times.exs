defmodule AlertsUI.Repo.Migrations.BackfillReminderTimes do
  use Ecto.Migration

  def change do
    execute("INSERT INTO reminder_times (id, alert_id, reminder_time, created_at, updated_at)
      SELECT gen_random_uuid(), alerts.id, timestamp without time zone 'epoch' + rt * interval '1 second', clock_timestamp(), clock_timestamp()
      FROM alerts, unnest(alerts.reminder_times) AS rt")

    alter table("alerts") do
      remove :reminder_times
    end
  end
end
