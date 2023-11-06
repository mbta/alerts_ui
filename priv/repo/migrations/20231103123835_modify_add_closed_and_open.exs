defmodule AlertsUI.Repo.Migrations.ModifyAddClosedAndOpen do
  use Ecto.Migration

  def change do
    unique_index("alerts", [:alert_id])

    alter table("alerts") do
      add :closed_timestamp, :utc_datetime
      add :open, :boolean, default: false
    end
  end
end
