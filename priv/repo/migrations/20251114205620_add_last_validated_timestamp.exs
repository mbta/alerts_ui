defmodule AlertsUI.Repo.Migrations.AddLastValidatedTimestamp do
  use Ecto.Migration

  def change do
    create table(:last_gtfs_validation) do
      add :datetime_of_last_validation, :utc_datetime
      timestamps()
    end
  end
end
