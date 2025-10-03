defmodule Elixir.AlertsUI.Repo.Migrations.PrimaryServiceTypeBackfill do
  use Ecto.Migration

  def change do
    execute("
      UPDATE alerts a SET primary_service_type='access' where (select facility_id from informed_entities ie where ie.alert_id = a.id LIMIT 1) is not null and a.primary_service_type is NULL;
    ")
    execute("
      UPDATE alerts a SET primary_service_type='systemwide' where (select route_id from informed_entities ie where ie.alert_id = a.id LIMIT 1) is null and a.primary_service_type is NULL;
    ")
    execute("
      UPDATE alerts a SET primary_service_type=(select route_type from informed_entities ie where ie.alert_id = a.id LIMIT 1) where a.primary_service_type is NULL;
    ")
  end
end
