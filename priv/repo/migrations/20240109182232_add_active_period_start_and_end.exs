defmodule AlertsUI.Repo.Migrations.AddActivePeriodStartAndEnd do
  use Ecto.Migration

  def change do
    alter table("alerts") do
      add :active_period_start, :utc_datetime, default: nil
      add :active_period_end, :utc_datetime, default: nil
    end
  end
end
