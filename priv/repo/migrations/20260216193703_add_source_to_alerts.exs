defmodule AlertsUI.Repo.Migrations.AddSourceToAlerts do
  use Ecto.Migration

  def up do
    execute("CREATE TYPE sources AS ENUM ('ALERTS_MANAGER', 'IBI', 'TRAPEZE')")

    alter table("alerts") do
      add :source, :sources, default: "ALERTS_MANAGER", null: false
    end

    execute("UPDATE alerts SET source = 'IBI' WHERE legacy = true")

    alter table("alerts") do
      remove :legacy
    end
  end

  def down do
    alter table("alerts") do
      add :legacy, :boolean, default: false, null: false
    end

    execute("UPDATE alerts SET legacy = true WHERE source = 'IBI'")

    alter table("alerts") do
      remove :source
    end

    execute("DROP TYPE sources CASCADE")
  end
end
