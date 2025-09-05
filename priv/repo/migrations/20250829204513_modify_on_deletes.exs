defmodule AlertsUI.Repo.Migrations.ModifyOnDeletes do
  use Ecto.Migration

  def change do
    alter table(:informed_entities) do
      modify :alert_id, references(:alerts, on_delete: :delete_all), from: references(:alerts)
    end

    alter table(:active_period) do
      modify :alert_id, references(:alerts, on_delete: :delete_all), from: references(:alerts)
    end

    alter table(:reminder_times) do
      modify :alert_id, references(:alerts, on_delete: :delete_all), from: references(:alerts)
    end

    alter table(:trip_descriptors) do
      modify :informed_entity_id, references(:informed_entities, on_delete: :delete_all),
        from: references(:informed_entities)
    end
  end
end
