defmodule AlertsUI.Repo.Migrations.AddBannerText do
  use Ecto.Migration

  def change do
    alter table("alerts") do
      add :banner_text, :string
    end
  end
end
