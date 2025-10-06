defmodule AlertsUIWeb.DownloadHistoryController do
  @moduledoc """
  """
  use AlertsUIWeb, :controller
  alias AlertsUI.AlertHistory
  alias NimbleCSV.RFC4180, as: CSV

  def export(conn, %{"alert_id" => alert_id}) do
    file =
      alert_id
      |> AlertHistory.alert_history()
      |> AlertHistory.build_history_csv()
      |> CSV.dump_to_iodata()

    formatted_date = Calendar.strftime(DateTime.now!("America/New_York"), "%Y_%m_%d")

    send_download(conn, {:binary, file},
      filename: "Alert_#{alert_id}_History_#{formatted_date}.csv"
    )
  end
end
