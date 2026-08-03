defmodule AlertsUIWeb.DownloadHistoryController do
  @moduledoc """
  """
  use AlertsUIWeb, :controller
  alias AlertsUI.AlertHistory
  alias AlertsUI.Alerts
  alias NimbleCSV.Spreadsheet, as: CSV

  require Logger

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
      Logger.info("[DEBUG]: Start time: #{start_time}")

      Phoenix.PubSub.broadcast(
        AlertsUI.PubSub,
        "file_downloading",
        {:download_started}
      )

      alert_ids = Alerts.list_a_month_of_commuter_rail(month, year)
      done_time = System.system_time(:millisecond)

      Logger.info(
        "[DEBUG]: Got #{length(alert_ids)} alert ids. Elapsed time: #{done_time - start_time}"
      )

      start_time = done_time

      histories =
        alert_ids
        |> Enum.map(fn alert_id ->
          Logger.info("[DEBUG]: Getting alert history for #{alert_id}")
          AlertHistory.alert_history(alert_id)
        end)

      done_time = System.system_time(:millisecond)
      Logger.info("[DEBUG]: Got histories. Elapsed time: #{done_time - start_time}")
      start_time = done_time

      file =
        histories |> List.flatten() |> AlertHistory.build_history_csv() |> CSV.dump_to_iodata()

      done_time = System.system_time(:millisecond)
      Logger.info("[DEBUG]: Made CSV file. Elapsed time: #{done_time - start_time}")

      # file =
      #   Alerts.list_a_month_of_commuter_rail(month, year)
      #   |> Enum.map(&AlertHistory.alert_history/1)
      #   |> List.flatten()
      #   |> AlertHistory.build_history_csv()
      #   |> CSV.dump_to_iodata()

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
