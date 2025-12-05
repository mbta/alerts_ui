defmodule :"Elixir.AlertsUI.Repo.Migrations.Backfill-notification-period-start" do
  use Ecto.Migration

  def change do
    # fill in any missing `notification_period_start` fields
    execute("
      UPDATE alerts SET notification_period_start = active_period_start WHERE notification_period_start IS NULL
    ")
  end
end
