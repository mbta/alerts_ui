defmodule AlertsUi.FeedImporterExporter do
  @moduledoc """
  Oban worker that periodically imports a source feed of alerts data and then
  writes the up-to-date version of our feed.
  """
  use Oban.Worker
  require Logger

  @impl Oban.Worker
  def perform(_job) do
    Logger.info("FeedImporterExporter: Importing the source feed")

    Logger.info("FeedImporterExporter: Writing the service alerts feed")

    :ok
  end
end
