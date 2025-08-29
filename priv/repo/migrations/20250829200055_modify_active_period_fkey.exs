defmodule AlertsUI.Repo.Migrations.ModifyActivePeriodFkey do
  use Ecto.Migration

  def change do
    alter table(:active_period) do
      modify :alert_id, references(:alerts, on_delete: :delete_all), from: references(:alerts)
    end
  end
end
