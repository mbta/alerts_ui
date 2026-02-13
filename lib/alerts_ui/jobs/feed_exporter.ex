defmodule AlertsUI.Jobs.FeedExporter do
  @moduledoc """
  Oban worker that periodically imports a source feed of alerts data and then
  writes the up-to-date version of our feed.
  """
  use Oban.Worker
  require Logger
  alias AlertsUI.FeedOutput.WriteFeed

  @impl Oban.Worker
  def perform(_job, opts \\ []) do
    export_feed(opts)
  end

  def export_feed(opts) do
    Logger.info("#{__MODULE__}: Exporting alerts feed")

    case :timer.tc(&WriteFeed.write_feed/1, [opts]) do
      {export_time, {:ok, _export_json}} ->
        Logger.info("#{__MODULE__}: Exported alerts feed: time_ms=#{export_time / 1_000}")
        :ok

      {_, {:error, reason}} ->
        Logger.warning("Error writing to file! #{reason}")
    end
  end
end
