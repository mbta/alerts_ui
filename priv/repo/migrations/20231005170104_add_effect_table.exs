defmodule AlertsUI.Repo.Migrations.AddEffectTable do
  use Ecto.Migration

  def change do
    create table("effects") do
      add :name, :string, unique: true
      timestamps()
    end
  end
end
