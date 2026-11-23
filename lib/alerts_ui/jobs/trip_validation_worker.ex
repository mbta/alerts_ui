defmodule AlertsUI.Jobs.TripValidationWorker do
  @moduledoc """
  Oban worker that checks the informed entities of open alerts to verify their trips are still
  within active service dates.

  Runs once a day, right after end of service (3AM)
  """
  use Oban.Worker

  alias AlertsUI.AlertValidation.AlertValidator

  require Logger

  @impl Oban.Worker
  def perform(_job) do
    base_url = AlertsUI.config(:api_url)
    api_key = AlertsUI.config(:api_key)

    AlertValidator.validate_trips_of_alerts(base_url, api_key)
    |> log_results()
  end

  def log_results(nil), do: :ok

  def log_results(trip_id_map) do
    trip_id_map
    |> Map.keys()
    |> Enum.map(fn trip_id ->
      %{alert_ids: alert_ids, last_service_date: last_service_date} = trip_id_map[trip_id]

      Logger.warning(
        "Trip #{trip_id} will be invalid after #{last_service_date} but is still listed in alert(s) #{alert_ids}"
      )
    end)

    :warning
  end
end
