defmodule AlertsUI.Repo.Migrations.ModifyCreatedTimestamp do
  use Ecto.Migration

  def change do
    execute(
      "ALTER TABLE alerts ALTER COLUMN created_timestamp SET DEFAULT CURRENT_TIMESTAMP AT TIME ZONE 'UTC';"
    )

    alter table("alerts") do
      modify :created_timestamp, :utc_datetime, null: false
    end
  end
end
