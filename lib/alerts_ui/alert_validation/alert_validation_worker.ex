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
    base_url = AlertsUI.config(:base_url)
    api_key = AlertsUI.config(:api_key)

    AlertValidator.validate_alerts(base_url, api_key)
    |> log_results()
  end

  @spec log_results({integer(), {:ok, binary()}} | {integer(), {:error, String.t()}}) :: :ok
  defp log_results([]), do: Logger.info("#{__MODULE__}: No invalid alert ids found")

  defp log_results(invalid_alert_ids),
    do:
      Logger.info(
        "#{__MODULE__}: Found invalid alerts ids: #{Enum.join(invalid_alert_ids, ", ")}"
      )
end
