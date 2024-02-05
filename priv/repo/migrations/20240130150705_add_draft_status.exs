defmodule AlertsUI.Repo.Migrations.AddDraftStatus do
  use Ecto.Migration

  def change do
    alter table("alerts") do
      add :draft, :boolean, default: false, required: true
    end
  end
end
