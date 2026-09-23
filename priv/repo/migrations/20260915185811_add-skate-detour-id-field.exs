defmodule :"Elixir.AlertsUI.Repo.Migrations.Add-skate-detour-id-field" do
  use Ecto.Migration

  def change do
    alter table("alerts") do
      add :skate_detour_id, :integer
    end
  end
end
