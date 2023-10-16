defmodule AlertsUI.Repo.Migrations.AddTripDescriptorTable do
  use Ecto.Migration
  alias AlertsUI.Models.ScheduleRelationship

  def change do
    schedule_relationship_list =
      ScheduleRelationship.schedule_relationships()
      |> Enum.map(&"'#{&1}'")
      |> Enum.join(", ")

    execute("CREATE TYPE schedule_relationships AS ENUM (#{schedule_relationship_list});")

    create table("trip_descriptors") do
      add :informed_entity_id, references(:informed_entities)
      add :trip_id, :string
      add :route_id, :string
      add :direction_id, :integer
      add :start_time, :time
      add :start_date, :date
      add :schedule_relationship, :schedule_relationships
      timestamps()
    end
  end
end
