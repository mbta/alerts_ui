defmodule AlertsUI.Repo.Migrations.ChangeReminderTimeType do
  use Ecto.Migration

  def change do
    execute("ALTER TABLE alerts RENAME COLUMN reminder_times TO reminder_times_unix;")

    execute("ALTER TABLE alerts ADD COLUMN reminder_times timestamp without time zone[];")

    execute("
      UPDATE alerts
      SET
        reminder_times = (
          SELECT
            array_agg(timestamp without time zone 'epoch' + reminder_time_unix * interval '1 second')
          FROM
            unnest(reminder_times_unix) AS reminder_time_unix);")

    execute("ALTER TABLE alerts DROP COLUMN reminder_times_unix;")
  end
end
