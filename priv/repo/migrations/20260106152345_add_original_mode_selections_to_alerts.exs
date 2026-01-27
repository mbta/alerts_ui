defmodule AlertsUI.Repo.Migrations.AddOriginalModeSelectionsToAlerts do
  use Ecto.Migration

  def change do
    alter table("alerts") do
      add :original_mode_selections, {:array, :integer}
    end
  end
end
