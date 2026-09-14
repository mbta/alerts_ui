defmodule AlertsUI.Repo.Migrations.RemoveTrapezeFeatureFlag do
  use Ecto.Migration

  def up do
    execute("DELETE FROM feature_flags WHERE NAME = 'Trapeze Import';")
  end

  def down do
    execute(
      "INSERT INTO feature_flags (id, name, created_at, updated_at) VALUES (gen_random_uuid(), 'Trapeze Import', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);"
    )
  end
end
