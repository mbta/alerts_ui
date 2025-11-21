defmodule AlertsUI.Repo.Migrations.AddBooleanColumnForLegacyAlerts do
  use Ecto.Migration

  def change do
    alter table(:alerts) do
      add :legacy, :boolean
    end
  end
end
