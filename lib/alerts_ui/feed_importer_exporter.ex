defmodule AlertsUi.FeedImporterExporter do
  @moduledoc """
  Oban worker that periodically imports a source feed of alerts data and then
  writes the up-to-date version of our feed.
  """
  use Oban.Worker
  require Logger
  alias AlertsUI.Alerts
  alias AlertsUI.FeedOutput.{CreateGtfsJson, CreateGtfsProtobuf, CreateOutputAlert}
  alias AlertsUI.GTFSIntake.AlertsIntake

  @json_output_filename AlertsUI.config(:json_output_filename)
  @protobuf_output_filename AlertsUI.config(:protobuf_output_filename)
  @write_fn AlertsUI.config(:file_write_function)

  @impl Oban.Worker
  def perform(_job, opts \\ []) do
    Logger.info("#{__MODULE__}: Importing alerts feed")

    {import_time, :ok} = :timer.tc(AlertsIntake, :run, [opts])

    Logger.info("#{__MODULE__}: Imported alerts feed: time_ms=#{import_time / 1_000}")

    Logger.info("#{__MODULE__}: Exporting alerts feed")

    {export_time, _} = :timer.tc(__MODULE__, :write_feed, [])

    Logger.info("#{__MODULE__}: Exported alerts feed: time_ms=#{export_time / 1_000}")

    :ok
  end

  @spec write_feed() :: any()
  def write_feed do
    alerts =
      Alerts.list_all_open()
      |> Enum.map(&CreateOutputAlert.build_alert/1)

    write_json_file(alerts)
    write_protobuf_file(alerts)
  end

  defp write_json_file(alerts) do
    alerts_json = CreateGtfsJson.output_json(alerts)
    @write_fn.(@json_output_filename, alerts_json)
  end

  defp write_protobuf_file(alerts) do
    alerts_protobuf = CreateGtfsProtobuf.output_protobuf(alerts)
    @write_fn.(@protobuf_output_filename, alerts_protobuf)
  end
end
