defmodule AlertsUIWeb.DownloadHistoryController do
  @moduledoc """
  """
  use AlertsUIWeb, :controller
  alias AlertsUI.AlertHistory
  alias AlertsUI.Alerts
  alias NimbleCSV.Spreadsheet, as: CSV

  def index(conn, _params) do
    %{month: previous_month_name} = previous_month_with_year()
    render(conn, :download_history, previous_month_name: previous_month_name)
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

  def export(conn, _params) do
    file =
      Alerts.list_most_recent_month_commuter_rail()
      |> Enum.map(&AlertHistory.alert_history/1)
      |> List.flatten()
      |> AlertHistory.build_history_csv()
      |> CSV.dump_to_iodata()

    %{month: previous_month, year: previous_year} = previous_month_with_year()

    send_download(conn, {:binary, file},
      filename: "Commuter_Rail_Alert_History_#{previous_month}_#{previous_year}.csv"
    )
  end

  defp previous_month_with_year(now \\ DateTime.utc_now()) do
    now = DateTime.shift_zone!(now, "America/New_York")
    previous_month = now.month - 1
    year_modifier = if previous_month == 12, do: -1, else: 0
    previous_year = now.year + year_modifier

    %{month: Timex.month_name(previous_month), year: previous_year}
  end
end
