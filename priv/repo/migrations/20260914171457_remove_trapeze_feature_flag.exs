defmodule AlertsUI.Repo.Migrations.RemoveTrapezeFeatureFlag do
  use Ecto.Migration

  def up do
    execute(
      "DELETE FROM feature_flags WHERE NAME IN ('Trapeze Import', 'Trapeze Close Time When Noticed');"
    )
  end

  def down do
    # Only 'Trapeze Import' here. 'Trapeze Close Time When Noticed' was an artifact of dev-orange that was not used
    execute(
      "INSERT INTO feature_flags (id, name, created_at, updated_at) VALUES (gen_random_uuid(), 'Trapeze Import', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);"
    )
  end
end
