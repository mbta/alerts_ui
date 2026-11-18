defmodule :"Elixir.AlertsUI.Repo.Migrations.Remove-can-close-automatically-column" do
  use Ecto.Migration

  def change do
    alter table("alerts") do
      remove_if_exists :can_close_automatically
      remove_if_exists :timeframe_text
    end
  end
end
