defmodule AlertsUI.Jobs.SkateDetourAutocloseWorker do
  @moduledoc """
  Oban worker that checks the skate detours file in S3 and closes any
  open alerts with skate detour ids that do not appear in that list
  """
  use Oban.Worker

  require Logger
  alias AlertsUI.Alerts
  alias AlertsUI.SkateDetours.GetDetours

  @impl Oban.Worker
  def perform(_job) do
    alerts_closed_in_skate =
      GetDetours.get_detours()
      |> Enum.map(& &1.id)
      |> Alerts.get_nonmatching_skate_alerts()

    if Enum.empty?(alerts_closed_in_skate) do
      Logger.info("No Skate alerts were automatically closed")
    else
      closed_alert_ids =
        alerts_closed_in_skate
        |> Enum.map(
          &Alerts.close(
            &1,
            "(Closed automatically via Skate)",
            true,
            DateTime.now!("America/New_York") |> DateTime.truncate(:second)
          )
        )
        |> Enum.map_join(", ", & &1.alert_id)

      Logger.info("Automatically closed the following Skate alerts: #{closed_alert_ids}")
    end

    :ok
  end
end
