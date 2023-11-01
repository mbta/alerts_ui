defmodule AlertsUI.Repo.Migrations.AddTtsFields do
  use Ecto.Migration

  def change do
    execute("ALTER TYPE schedule_relationships ADD VALUE IF NOT EXISTS 'DUPLICATED';")
    execute("ALTER TYPE schedule_relationships ADD VALUE IF NOT EXISTS 'DELETED';")

    alter table("alerts") do
      add :tts_header_text, :string
      add :tts_description_text, :string
    end

    alter table("trip_descriptors") do
      modify :schedule_relationship, :schedule_relationships
    end
  end
end
