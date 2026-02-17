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
    # {:ok, enhanced_json} = FeedReader.ibi_json(:enhanced)
    # {:ok, standard_json} = FeedReader.ibi_json(:standard)
    #TODO  not authorized to perform: s3:ListBucket on resource: \\\"arn:aws:s3:::mbta-alerts-ui\\\" because no identity-based policy allows the s3:ListBucket action<
    # enhanced_checksum = :crypto.hash(:md5, enhanced_json) |> Base.encode16
    # standard_checksum = :crypto.hash(:md5, standard_json) |> Base.encode16

    enhanced_checksum = get_checksum(:combined_enhanced_json)
    standard_checksum = get_checksum(:combined_standard_json)
    sita_checksum = get_checksum(:combined_enhanced_sita_json)
    pb_checksum = get_checksum(:combined_protobuf)

    # checksums = [enhanced_checksum, standard_checksum]
    Logger.info(
      "Feed checksums: enhanced=#{enhanced_checksum} standard=#{standard_checksum} sita=#{sita_checksum} protobuf=#{pb_checksum}"
    )

    # IO.inspect([enhanced_checksum, standard_checksum, sita_checksum, pb_checksum])
    # case :timer.tc(&WriteFeed.write_feed/1, [opts]) do
    #   {export_time, {:ok, _export_json}} ->
    #     Logger.info("#{__MODULE__}: Exported alerts feed: time_ms=#{export_time / 1_000}")
    #     :ok

    #   {_, {:error, reason}} ->
    #     Logger.warning("Error writing to file! #{reason}")
    # end
  end

  defp get_checksum(flavor) do
    {:ok, file} = FeedReader.alerts_manager_json(flavor)
    :crypto.hash(:md5, file) |> Base.encode16()
  end
end
