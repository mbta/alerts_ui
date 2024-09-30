defmodule AlertsUI.Repo.Migrations.BackfillReminderTimes do
  use Ecto.Migration

  def change do
    execute("INSERT INTO reminder_times (id, alert_id, reminder_time, created_at, updated_at)
      SELECT gen_random_uuid(), alerts.id, timestamp without time zone 'epoch' + rt * interval '1 second', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM alerts, unnest(alerts.reminder_times) AS rt")

    alter table("alerts") do
      remove :reminder_times
    end
  end

  def down do
    alter table("alerts") do
      add :reminder_times, {:array, :integer}
    end

    execute("WITH reminder_agg AS (
    select array_agg(cast(extract(epoch from reminder_time) as integer)) as rt
	    FROM reminder_times)
    UPDATE alerts
    SET reminder_times = reminder_agg.rt
    FROM reminder_agg, reminder_times
    where reminder_times.alert_id = alerts.id;")
  end
end
