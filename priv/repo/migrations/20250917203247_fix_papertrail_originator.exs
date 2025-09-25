defmodule AlertsUI.Repo.Migrations.FixPapertrailOriginator do
  use Ecto.Migration

  def change do
    drop constraint(:versions, "versions_originator_id_fkey")

    alter table(:versions) do
      modify :originator_id, references(:users)
    end
  end
end
