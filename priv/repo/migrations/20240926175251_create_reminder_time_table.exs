defmodule AlertsUI.Repo.Migrations.CreateReminderTimeTable do
  use Ecto.Migration

  def change do
    create table("reminder_times") do
      add :alert_id, references(:alerts)
      add :reminder_time, :utc_datetime
      timestamps()
    end
  end
end
