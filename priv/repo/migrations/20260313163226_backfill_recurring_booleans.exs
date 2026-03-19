defmodule AlertsUI.Repo.Migrations.BackfillRecurringBooleans do
  use Ecto.Migration

  def up do
    execute(
      "UPDATE alerts SET recurring = true WHERE recurrence_days IS NOT NULL AND recurrence_days != '{}'"
    )
  end

  def down do
    execute("UPDATE alerts SET recurring = false")
  end
end
