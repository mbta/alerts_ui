defmodule AlertsUI.Repo.Migrations.AddOriginalRouteSelection do
  use Ecto.Migration

  def change do
    alter table("alerts") do
      add :original_route_selections, {:array, :string}
    end
  end
end
