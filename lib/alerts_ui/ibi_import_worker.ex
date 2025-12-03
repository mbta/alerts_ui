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
    Logger.info("[import #{id}] worker called")

    case File.stat(@local_path) do
      {:error, :enoent} ->
        Logger.info("[import #{id}] downloading source file to #{@local_path}")

        try do
          ExAws.S3.download_file(@bucket, @filename, @local_path) |> ExAws.request!()
        rescue
          e ->
            Logger.error("[import #{id}] download failed: #{inspect(e)}")
            reraise e, __STACKTRACE__
        end

      {:error, error} ->
        Logger.error("[import #{id}] uh oh: #{error}")
        raise "#{error}"

      {:ok, _} ->
        Logger.info("[import #{id}] source file exists at #{@local_path}")
    end

    Logger.info("[import #{id}] calling importer")
    IBIAlertImporter.import_ibi_alerts!(@local_path, id)
    Logger.info("[import #{id}] worker finished")
  end
end
