defmodule AlertsUI.Repo.Migrations.CreateLatestIBIAlertsView do
  use Ecto.Migration

  def up do
    execute("
      ALTER TABLE ibi_alerts
        ADD COLUMN integer_version_no INTEGER
        GENERATED ALWAYS AS (version_no::INTEGER) STORED
      ")

    execute("
      CREATE INDEX latest_ibi_alerts_join_index ON ibi_alerts (integer_version_no, alert_id)
    ")

    execute("
      CREATE VIEW latest_ibi_alerts AS
        SELECT * FROM ibi_alerts
        INNER JOIN (
          SELECT max(i.integer_version_no) AS version, i.alert_id AS version_alert_id
          FROM ibi_alerts i
          GROUP BY version_alert_id
        ) versions ON
        versions.version_alert_id = ibi_alerts.alert_id AND
        versions.version = ibi_alerts.integer_version_no
    ")
  end

  def down do
    execute("ALTER TABLE ibi_alerts DROP COLUMN integer_version_no CASCADE")
  end
end
