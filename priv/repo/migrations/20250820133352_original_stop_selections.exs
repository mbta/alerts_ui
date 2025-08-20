defmodule AlertsUI.Repo.Migrations.OriginalStopSelections do
  use Ecto.Migration

  def change do
    alter table("alerts") do
      add :original_stop_selections, {:array, :string}
    end
  end
end
