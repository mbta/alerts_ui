defmodule AlertsUI.Repo.Migrations.AddEffectName do
  use Ecto.Migration

  def change do
    alter table("alerts") do
      add :effect_name, :string
    end
  end
end
