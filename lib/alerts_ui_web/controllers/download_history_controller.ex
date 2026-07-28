defmodule AlertsUIWeb.DownloadHistoryController do
  @moduledoc """
  """
  use AlertsUIWeb, :controller
  alias AlertsUI.AlertHistory
  alias AlertsUI.Alerts
  alias NimbleCSV.Spreadsheet, as: CSV

  def index(conn, _params) do
    now = DateTime.shift_zone!(DateTime.utc_now(), "America/New_York")

    previous_month = rem(now.month + 10, 12) + 1

    render(conn, :download_history,
      years: year_options(now),
      months: month_options(),
      current_year: now.year,
      previous_month: previous_month
    )
  end

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
      file =
        Alerts.list_a_month_of_commuter_rail(month, year)
        |> Enum.map(&AlertHistory.alert_history/1)
        |> List.flatten()
        |> AlertHistory.build_history_csv()
        |> CSV.dump_to_iodata()

      send_download(conn, {:binary, file},
        filename: "Commuter_Rail_Alert_History_#{month}-#{year}.csv"
      )
    else
      :error -> send_resp(conn, 400, "Bad request")
    end
  end

  defp month_options do
    1..12 |> Enum.to_list() |> Enum.map(fn month -> {Timex.month_name(month), month} end)
  end

  defp year_options(now) do
    2013..now.year |> Enum.to_list() |> Enum.reverse() |> Enum.map(fn year -> {year, year} end)
  end
end
