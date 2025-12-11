defmodule AlertsUI.Repo.Migrations.CreateLatestIBIAlertsView do
  use Ecto.Migration

  alias AlertsUI.Models.LatestIBIAlert

  def up do
    execute("
      ALTER TABLE ibi_alerts
        ADD COLUMN integer_version_no INTEGER
        GENERATED ALWAYS AS (version_no::INTEGER) STORED
      ")

    execute("
      CREATE INDEX latest_ibi_alerts_join_index ON ibi_alerts (integer_version_no, alert_id)
    ")

    execute(LatestIBIAlert.create_view_sql())

  def down do
    execute("ALTER TABLE ibi_alerts DROP COLUMN integer_version_no CASCADE")
    execute(LatestIBIAlert.drop_view_sql())
  end
end
