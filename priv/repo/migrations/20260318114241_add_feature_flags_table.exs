defmodule AlertsUI.Repo.Migrations.AddFeatureFlagsTable do
  use Ecto.Migration

  def change do
    create table("feature_flags") do
      add :name, :string, null: false, unique: true
      add :enabled, :boolean, null: false, default: false

      timestamps()
    end
  end
end
