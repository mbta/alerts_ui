defmodule AlertsUI.Repo.Migrations.SplitRecurrenceTimesOnAlerts do
  use Ecto.Migration

  def up do
    alter table(:alerts) do
      add :recurrence_start_time, :time
      add :recurrence_end_time, :time
    end

    execute """
    UPDATE alerts SET recurrence_start_time = recurrence_times[1], recurrence_end_time = recurrence_times[2];
    """

    alter table(:alerts), do: remove :recurrence_times
  end

  def down do
    alter table(:alerts) do
      add :recurrence_times, {:array, :time}
    end

    execute """
    UPDATE alerts SET recurrence_times = ARRAY[recurrence_start_time, recurrence_end_time];
    """

    alter table(:alerts) do
      remove :recurrence_start_time
      remove :recurrence_end_time
    end
  end
end
