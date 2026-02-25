defmodule AlertsUI.Repo.Migrations.AddTrapezeMonitor do
  use Ecto.Migration

  def change do
    create table("trapeze_monitors") do
      add :checked_at, :utc_datetime, null: false
      add :processed_at, :utc_datetime
      add :work_order_changes, {:array, :string}, null: false
      add :checksum, :string
      add :result, :string, null: false
      add :reason, :string, null: false

      timestamps()
    end
  end
end
