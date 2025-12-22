defmodule AlertsUI.Repo.Migrations.RenameInformedEntityColumns do
  use Ecto.Migration

  def change do
    for t <- [:route, :direction, :trip, :stop, :facility] do
      rename table(:ibi_alerts), :"informed_#{t}_id", to: :"informed_#{t}_list"
    end
  end
end
