defmodule AlertsUIWeb.DownloadHistoryController do
  @moduledoc """
  """
  use AlertsUIWeb, :controller
  alias AlertsUI.AlertHistory
  alias AlertsUI.Alerts
  alias NimbleCSV.Spreadsheet, as: CSV

  def export(conn, %{"alert_id" => alert_id}) do
    file =
      alert_id
      |> AlertHistory.alert_history()
      |> AlertHistory.build_history_csv()
      |> CSV.dump_to_iodata()

    formatted_date = Calendar.strftime(DateTime.now!("America/New_York"), "%Y-%m-%d")

    send_download(conn, {:binary, file},
      filename: "Alert_#{alert_id}_History_#{formatted_date}.csv"
    )
  end

  def export_bulk(conn, %{"month" => month, "year" => year}) do
    with {month, _} <- Integer.parse(month),
         {year, _} <- Integer.parse(year) do
      start_time = System.system_time(:millisecond)

      Phoenix.PubSub.broadcast(
        AlertsUI.PubSub,
        "file_downloading",
        {:download_started}
      )

      file =
        Alerts.list_a_month_of_commuter_rail(month, year)
        |> Enum.map(&AlertHistory.alert_history/1)
        |> List.flatten()
        |> AlertHistory.build_history_csv()
        |> CSV.dump_to_iodata()

      Phoenix.PubSub.broadcast(
        AlertsUI.PubSub,
        "file_downloading",
        {:download_finished}
      )

      send_download(conn, {:binary, file},
        filename: "Commuter_Rail_Alert_History_#{month}-#{year}.csv"
      )
    else
      :error -> send_resp(conn, 400, "Bad request")
    end
  end
end
