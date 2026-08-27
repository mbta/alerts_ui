defmodule AlertsUI.Jobs.FeedWriter do
  @moduledoc """
  Oban worker that periodically writes the up-to-date version of our alerts feed.
  """
  use Oban.Worker

  require Logger

  alias AlertsUI.FeedOutput.WriteFeed

  @impl Oban.Worker
  def perform(_job, opts \\ []) do
    Logger.info("#{__MODULE__}: Writing alerts feed")

    :timer.tc(&WriteFeed.write_feed/1, [opts])
    |> log_results()
  end

  @spec log_results({integer(), {:ok, binary()}} | {integer(), {:error, String.t()}}) :: :ok
  defp log_results({export_time, {:ok, _export_json}}) do
    Logger.info("#{__MODULE__}: Wrote alerts feed: time_ms=#{export_time / 1_000}")
  end

  defp log_results({_, {:error, reason}}) do
    Logger.error("Error writing to file: #{reason}")
    {:error, reason}
  end
end
