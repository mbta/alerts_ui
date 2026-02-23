defmodule AlertsUI.Jobs.FeedChecker do
  @moduledoc """
  Oban worker that periodically imports a source feed of alerts data and then
  writes the up-to-date version of our feed.
  """
  use Oban.Worker
  require Logger
  alias AlertsUI.FeedReader

  @impl Oban.Worker
  def perform(_job, opts \\ []) do
    check_feed(opts)
  end

  def check_feed(_opts) do
    Logger.info("#{__MODULE__}: calculating checksums")

    enhanced_checksum = get_checksum(:enhanced_json)
    standard_checksum = get_checksum(:standard_json)
    sita_checksum = get_checksum(:enhanced_sita_json)
    pb_checksum = get_checksum(:standard_protobuf)

    Logger.info(
      "Feed checksums: enhanced=#{enhanced_checksum} standard=#{standard_checksum} sita=#{sita_checksum} protobuf=#{pb_checksum}"
    )
  end

  defp get_checksum(flavor) do
    {:ok, file} = FeedReader.alerts_json(flavor)
    :crypto.hash(:md5, file) |> Base.encode16()
  end
end
