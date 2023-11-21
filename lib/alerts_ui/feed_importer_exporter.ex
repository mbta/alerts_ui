defmodule AlertsUi.FeedImporterExporter do
  @moduledoc """
  Oban worker that periodically imports a source feed of alerts data and then
  writes the up-to-date version of our feed.
  """
  use Oban.Worker
  require Logger
  alias AlertsUI.FeedOutput.{CompareFeed, WriteFeed}
  alias AlertsUI.GTFSIntake.AlertsIntake

  @impl Oban.Worker
  def perform(_job, opts \\ []) do
    import_json = import_feed(opts)

    export_json = export_feed(opts)

    compare_feeds(import_json, export_json)
    :ok
  end

  def import_feed(opts) do
    Logger.info("#{__MODULE__}: Importing alerts feed")

    {import_time, {:ok, import_json}} = :timer.tc(&AlertsIntake.run/1, [opts])

    Logger.info("#{__MODULE__}: Imported alerts feed: time_ms=#{import_time / 1_000}")
    import_json
  end

  def export_feed(opts) do
    Logger.info("#{__MODULE__}: Exporting alerts feed")

    {export_time, {:ok, export_json}} = :timer.tc(&WriteFeed.write_feed/1, [opts])

    Logger.info("#{__MODULE__}: Exported alerts feed: time_ms=#{export_time / 1_000}")
    export_json
  end

  def compare_feeds(import_json, export_json) do
    filtered_import =
      Enum.filter(import_json["entity"], &is_nil(Map.get(&1["alert"], "closed_timestamp")))

    with :ok <- CompareFeed.compare_headers(import_json["header"], export_json["header"]),
         :ok <- CompareFeed.compare_entity_lists(filtered_import, export_json["entity"]) do
      Logger.info("Export ok!")
    else
      {error_message, data} ->
        Logger.warning(
          "Export mismatch problem: #{error_message}. Error data: #{data |> inspect}"
        )
    end
  end
end
