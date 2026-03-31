defmodule AlertsUI.Repo.Migrations.ChangeWorkOrderEntriesToBeText do
  use Ecto.Migration

  def change do
    alter table("trapeze_monitors") do
      modify :work_order_changes, {:array, :text}, from: {:array, :string}
    end
  end
end
