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

    :ok
  end
end
