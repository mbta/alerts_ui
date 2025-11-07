defmodule AlertsUI.AlertValidation.AlertValidationWorker do
  @moduledoc """
  Oban worker that checks the informed entities of open alerts for validity, against the production API.
  """
  use Oban.Worker

  require Logger
  require Ecto.Query

  alias AlertsUI.AlertValidation.AlertValidator

  @impl Oban.Worker
  def perform(_job) do
    base_url = AlertsUI.config(:api_url)
    api_key = AlertsUI.config(:api_key)

    AlertValidator.validate_alerts(base_url, api_key)
    |> AlertValidator.format_invalid_alerts()
    |> Logger.info()
  end
end
