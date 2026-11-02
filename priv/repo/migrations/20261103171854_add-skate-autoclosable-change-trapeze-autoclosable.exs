defmodule :"Elixir.AlertsUI.Repo.Migrations.Add-skate-autoclosable-change-trapeze-autoclosable" do
  use Ecto.Migration

  def change do
    alter table("alerts") do
      add :trapeze_autoclosable, :boolean, default: false, null: false
      add :skate_autoclosable, :boolean, default: false, null: false
    end

    execute "UPDATE alerts SET trapeze_autoclosable = can_close_automatically;"
  end
end
