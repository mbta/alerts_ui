defmodule AlertsUI.Repo.Migrations.AddNotificationDurationCertaintyToAlerts do
  use Ecto.Migration

  def change do
    alter table("alerts") do
      add :notification_duration_certainty, :duration_certainty
    end
  end
end
