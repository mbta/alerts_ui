defmodule :"Elixir.AlertsUI.Repo.Migrations.BackfillIncorrectlyStoredDirections" do
  use Ecto.Migration

  defmodule AlertsUI.Repo.Migrations.BackfillCreatedTimestamp do
    use Ecto.Migration

    def change do
      execute(
        "UPDATE alerts SET original_direction_selections = array_remove(original_direction_selections, '|')"
      )
    end
  end
end
