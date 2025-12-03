defmodule :"Elixir.AlertsUI.Repo.Migrations.Backfill-last-modified-timestamp" do
  use Ecto.Migration

  def change do
    # fill in any missing `last_modified_timestamp` fields
    execute("
      UPDATE alerts SET last_modified_timestamp = updated_at WHERE last_modified_timestamp is NULL
    ")
  end
end
