defmodule AlertsUI.IBIImportWorker do
  @moduledoc """
  Kick off an IBI import.
  """

  use Oban.Worker

  require Logger

  alias AlertsUI.IBIAlertImporter
  alias Ecto.UUID

  @default_chunk_size 1000
  @bucket "mbta-alerts-ui-data-upload"
  @filename "ibi-alerts-source.csv"
	@directory System.tmp_dir!()
	@local_path "#{@directory}/#{@filename}"

  @impl Oban.Worker
  def perform(_job, _options \\ []) do
    import_id = UUID.generate()

    Logger.info("[import #{import_id}] starting")

		case File.stat(@local_path) do
      {:error, :enoent} ->
        Logger.info("[import #{import_id}] downloading source file to #{@local_path}")
        ExAws.download_file(@bucket, @filename, @local_path) |> ExAws.request!()
      {:error, error} ->
        Logger.error("[import #{import_id}] uh oh: #{error}")
        raise error, __STACKTRACE__
      {:ok, _} ->
        Logger.info("[import #{import_id}] source file exists at #{@local_path}")
    end

    IBIAlertImporter.import_ibi_alerts!(@local_path)
    Logger.info("[import #{import_id}] finished")
  end
end
