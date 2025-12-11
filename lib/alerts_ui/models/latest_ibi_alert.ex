defmodule AlertsUI.Models.LatestIBIAlert do
  @moduledoc """
  A view representing the latest version of each alert.
  """

  alias AlertsUI.Models.IBIAlert

  use AlertsUI.Schema

  def create_view_sql do
    """
      CREATE VIEW latest_ibi_alerts AS
        SELECT * FROM ibi_alerts
        INNER JOIN (
          SELECT max(i.integer_version_no) AS version, i.alert_id AS version_alert_id
          FROM ibi_alerts i
          GROUP BY version_alert_id
        ) versions ON
        versions.version_alert_id = ibi_alerts.alert_id AND
        versions.version = ibi_alerts.integer_version_no
        WHERE ibi_alerts.alert_time_type != 'Template'
    """
  end

  def drop_view_sql, do: "DROP VIEW latest_ibi_alerts"

  schema "latest_ibi_alerts" do
    Enum.each(IBIAlert.fields(), fn field_name -> field field_name, :string end)
    timestamps()
  end
end
