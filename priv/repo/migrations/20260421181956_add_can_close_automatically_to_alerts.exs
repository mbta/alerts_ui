defmodule AlertsUI.Repo.Migrations.AddCanCloseAutomaticallyToAlerts do
  use Ecto.Migration

  def change do
    alter table("alerts") do
      add :can_close_automatically, :boolean, default: false, null: false
    end
  end
end
