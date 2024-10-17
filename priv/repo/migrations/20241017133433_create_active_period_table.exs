defmodule AlertsUI.Repo.Migrations.CreateActivePeriodTable do
  use Ecto.Migration

  def change do
    create table("active_period") do
      add :alert_id, references(:alerts)
      add :start, :utc_datetime
      add :end, :utc_datetime
      timestamps()
    end
  end
end
