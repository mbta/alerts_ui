defmodule AlertsUI.Repo.Migrations.ModifyAlertId do
  use Ecto.Migration

  def change do
    execute("CREATE SEQUENCE alert_id_seq OWNED BY alerts.alert_id;")

    execute(
      "SELECT SETVAL('alert_id_seq', (select max(cast(alert_id as integer)) from alerts), false);"
    )

    execute("ALTER TABLE alerts ALTER COLUMN alert_id SET DEFAULT nextval('alert_id_seq');")
  end
end
