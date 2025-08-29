defmodule AlertsUI.Repo.Migrations.ModifyInformedEntitiesFkey do
  use Ecto.Migration

  def change do
    alter table(:informed_entities) do
      modify :alert_id, references(:alerts, on_delete: :delete_all), from: references(:alerts)
    end
  end
end
