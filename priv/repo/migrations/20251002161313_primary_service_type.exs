defmodule AlertsUI.Repo.Migrations.PrimaryServiceType do
  use Ecto.Migration

  def change do
    alter table("alerts") do
      add :primary_service_type, :string
    end

    execute("
      UPDATE alerts a SET primary_service_type = (select route_type from informed_entities ie join alerts a on ie.alert_id = a.id LIMIT 1) WHERE a.primary_service_type IS NULL
    ")
  end
end
