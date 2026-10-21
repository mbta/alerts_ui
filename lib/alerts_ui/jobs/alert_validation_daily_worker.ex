defmodule AlertsUI.Jobs.AlertValidationDailyWorker do
  @moduledoc """
  Oban worker that checks the informed entities of open alerts for validity
  once a day, against the production API.
  """
  use Oban.Worker

  require Logger

  alias AlertsUI.AlertValidation.AlertValidator

  @impl Oban.Worker
  def perform(_job) do
    base_url = AlertsUI.config(:api_url)
    api_key = AlertsUI.config(:api_key)

    AlertValidator.validate_alerts(base_url, api_key)
    |> AlertValidator.format_invalid_alerts("current")
    |> Logger.info()

    AlertValidator.validate_commuter_rail_alerts(base_url, api_key)
    |> AlertValidator.format_invalid_alerts("current", "Commuter Rail ")
    |> Logger.info()
  end
end
