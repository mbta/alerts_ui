defmodule :"Elixir.AlertsUI.Repo.Migrations.Recurrence-times-column" do
  use Ecto.Migration

  def change do
    alter table("alerts") do
      add :recurrence_times, {:array, :time}
    end
  end
end
