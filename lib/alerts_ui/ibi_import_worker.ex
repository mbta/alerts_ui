defmodule AlertsUI.IBIImportWorker do
  @moduledoc """
  Kick off an IBI import.
  """

  use Oban.Worker, unique: true

  require Logger

  alias AlertsUI.IBIAlertImporter

  @bucket "mbta-alerts-ui-data-upload"
  @filename "ibi-alerts-source.csv"
	@directory System.tmp_dir!()
	@local_path "#{@directory}/#{@filename}"

  def bucket, do: @bucket
  def filename, do: @filename

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"id" => id}}, _options \\ []) do
    Logger.info("[import #{id}] starting")

		case File.stat(@local_path) do
      {:error, :enoent} ->
        Logger.info("[import #{id}] downloading source file to #{@local_path}")
        ExAws.S3.download_file(@bucket, @filename, @local_path) |> ExAws.request!()
      {:error, error} ->
        Logger.error("[import #{id}] uh oh: #{error}")
        raise "#{error}"
      {:ok, _} ->
        Logger.info("[import #{id}] source file exists at #{@local_path}")
    end

    IBIAlertImporter.import_ibi_alerts!(@local_path)
    Logger.info("[import #{id}] finished")
  end
end
