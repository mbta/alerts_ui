defmodule AlertsUI.Repo.Migrations.AddNotificationPeriodEnd do
  use Ecto.Migration

  def change do
    alter table("alerts") do
      add :notification_period_end, :utc_datetime
    end
  end
end
