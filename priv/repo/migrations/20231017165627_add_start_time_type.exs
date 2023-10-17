defmodule AlertsUI.Repo.Migrations.AddStartTimeType do
  use Ecto.Migration

  def change do
    execute("
      alter table trip_descriptors
      alter column start_time
      type jsonb
      using to_jsonb(to_char(start_time::time, 'HH:MM:SS'))
    ")
  end
end
