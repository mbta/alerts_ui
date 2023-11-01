defmodule AlertsUI.Repo.Migrations.ModifyTypes do
  use Ecto.Migration

  def change do
    execute("ALTER TYPE effects ADD VALUE IF NOT EXISTS 'ACCESSIBILITY_ISSUE';")

    execute("ALTER TYPE alert_lifecycles ADD VALUE IF NOT EXISTS 'UPCOMING_ONGOING';")

    alter table("alerts") do
      modify :description_text, :text, from: :string
      modify :effect, :effects
      modify :alert_lifecycle, :alert_lifecycles
    end
  end
end
