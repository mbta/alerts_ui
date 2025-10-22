defmodule :"Elixir.AlertsUI.Repo.Migrations.Add-selected-directions" do
  use Ecto.Migration

  def change do
    alter table("alerts") do
      add :original_facility_selections, {:array, :string}
      add :original_direction_selections, {:array, :string}
    end
  end
end
