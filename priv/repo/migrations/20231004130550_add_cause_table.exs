defmodule AlertsUI.Repo.Migrations.AddCauseTable do
  use Ecto.Migration

  def change do
    create table("causes") do
      add :name, :string, unique: true
      timestamps()
    end
  end
end
