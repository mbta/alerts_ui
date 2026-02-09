defmodule AlertsUI.Repo.Migrations.AddWorkOrderIdToAlerts do
  use Ecto.Migration

  def change do
    alter table("alerts") do
      add :work_order_id, :string
    end
  end
end
