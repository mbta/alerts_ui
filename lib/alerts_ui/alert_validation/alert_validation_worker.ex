defmodule AlertsUI.AlertValidation.AlertValidationWorker do
  @moduledoc """
  Oban worker that checks the informed entities of open alerts for validity, against the production API.
  """
  use Oban.Worker

  require Logger

  alias AlertsUI.AlertValidation.AlertValidator

  @impl Oban.Worker
  def perform(_job) do
    base_url = Application.get_env(:alerts_ui, :api_url)
    api_key = Application.get_env(:alerts_ui, :api_key)

    AlertValidator.validate_alerts(base_url, api_key)
    |> log_results()
  end

  @spec log_results({integer(), {:ok, binary()}} | {integer(), {:error, String.t()}}) :: :ok
  defp log_results([]), do: :ok

  defp log_results(invalid_alert_ids),
    do:
      Logger.info(
        "#{__MODULE__}: Invalid alerts ids found: #{Enum.join(invalid_alert_ids, ", ")}"
      )
end
