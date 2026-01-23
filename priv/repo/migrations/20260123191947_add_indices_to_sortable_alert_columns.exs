defmodule AlertsUI.Repo.Migrations.AddIndicesToSortableAlertColumns do
  use Ecto.Migration

  def change do
    create index(:alerts, [:draft])
    create index(:alerts, [:active_period_start])
    create index(:alerts, [:active_period_end])
    create index(:alerts, [:notification_period_start])
    create index(:alerts, [:notification_period_end])
    create index(:alerts, [:duration_certainty])
    create index(:alerts, [:effect_detail])
  end
end
