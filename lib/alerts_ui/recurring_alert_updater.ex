defmodule AlertsUI.RecurringAlertUpdater do
  @moduledoc """
  Oban worker that periodically adds new active periods to recurring alerts
  with no end.
  """
  use Oban.Worker

  require Logger

  alias AlertsUI.Alerts

  @impl Oban.Worker
  def perform(_job, opts \\ []) do
    Logger.info("#{__MODULE__}: Updating recurring alerts")

    :timer.tc(&update_alerts/1, [opts])
    |> log_results()
  end

  defp update_alerts(_opts) do
    update_results =
      Alerts.list_all_open()
      |> Alerts.filter_on_notification_period_start()
      |> Enum.filter(&is_nil(&1.active_period_end))
      |> Enum.map(&Alerts.update_recurring_active_periods/1)
      |> List.flatten()

    errors =
      Enum.map(update_results, fn {status, error} ->
        if status == :ok do
          nil
        else
          error
        end
      end)
      |> Enum.reject(&is_nil/1)

    if Enum.empty?(errors) do
      :ok
    else
      {:error, errors}
    end

    :ok
  end

  @spec log_results({integer(), :ok} | {integer(), {:error, String.t()}}) :: :ok
  defp log_results({export_time, :ok}),
    do: Logger.info("#{__MODULE__}: Wrote alerts feed: time_ms=#{export_time / 1_000}")

  defp log_results({_, {:error, errors}}),
    do: Logger.warning("Error updating recurring alerts: #{Enum.join(errors, ", ")}")
end
