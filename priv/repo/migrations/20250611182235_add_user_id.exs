defmodule AlertsUI.Repo.Migrations.AddUserId do
  use Ecto.Migration

  def change do
    alter table("alerts") do
      add :user_id, references(:users)
    end
  end
end
