defmodule AlertsUI.Repo.Migrations.BackfillCreatedTimestamp do
  use Ecto.Migration

  def change do
    # fill in any missing `created_timestamp` fields
    # For AM alerts, created_timestamp == created_at
    # For IBI alerts, created_timestamp is different and came from the IBI import
    execute("
      UPDATE alerts SET created_timestamp = created_at WHERE created_timestamp IS NULL
    ")
  end
end
