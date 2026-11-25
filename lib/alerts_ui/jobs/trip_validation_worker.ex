defmodule AlertsUI.Jobs.TripValidationWorker do
  @moduledoc """
  Oban worker that checks the informed entities of open alerts to verify their trips are still
  within active service dates.
  """
  use Oban.Worker

  alias AlertsUI.AlertValidation.AlertValidator

  require Logger

  @impl Oban.Worker
  def perform(_job) do
    base_url = AlertsUI.config(:api_url)
    api_key = AlertsUI.config(:api_key)

    Logger.info("#{__MODULE__}: Validating trips")

    AlertValidator.validate_trips_of_alerts(base_url, api_key)
    |> log_results()
  end

  def log_results(trip_id_map) when map_size(trip_id_map) == 0 do
    Logger.info("#{__MODULE__}: All trips on open alerts are still in service")
    :ok
  end

  def log_results(trip_id_map) do
    trip_id_map
    |> Map.keys()
    |> Enum.each(fn trip_id ->
      %{alert_ids: alert_ids, last_service_date: last_service_date} = trip_id_map[trip_id]

      Logger.warning(
        "#{__MODULE__}: Trip #{trip_id} will be invalid after #{last_service_date} but is still listed in alert(s) #{Enum.join(alert_ids, ",")}"
      )
    end)

    :ok
  end
end
