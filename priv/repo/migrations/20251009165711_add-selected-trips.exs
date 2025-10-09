defmodule :"Elixir.AlertsUI.Repo.Migrations.Add-selected-trips" do
  use Ecto.Migration

  def change do
    alter table("alerts") do
      add :original_trip_selections, {:array, :string}
    end
  end
end
