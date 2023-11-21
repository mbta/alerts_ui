defmodule AlertsUI.Repo.Migrations.AddFacilityId do
  use Ecto.Migration

  def change do
    alter table("alerts") do
      add :recurrence_text, :string
      add :reminder_times, {:array, :integer}
    end

    alter table("informed_entities") do
      add :facility_id, :string
    end
  end
end
