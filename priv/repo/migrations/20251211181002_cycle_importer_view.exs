defmodule AlertsUI.Repo.Migrations.CycleImporterView do
  use Ecto.Migration

  alias AlertsUI.Models.LatestIBIAlert

  def up do
    execute(LatestIBIAlert.drop_view_sql())
    execute(LatestIBIAlert.create_view_sql())
  end

  def down, do: nil
end
