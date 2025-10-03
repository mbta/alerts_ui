defmodule AlertsUI.Repo.Migrations.PrimaryServiceType do
  use Ecto.Migration

  def change do
    alter table("alerts") do
      add :primary_service_type, :string
    end
  end
end
