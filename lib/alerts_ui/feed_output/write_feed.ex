defmodule AlertsUI.FeedOutput.WriteFeed do
  @moduledoc """
    Writes feeds to local file
  """
  @enhanced_json_output_filename AlertsUI.config(:enhanced_json_output_filename)
  @protobuf_output_filename AlertsUI.config(:protobuf_output_filename)

  alias AlertsUI.Alerts
  alias AlertsUI.FeedOutput.{CreateGtfsJson, CreateGtfsProtobuf, CreateOutputAlert}

  @spec write_feed() :: any()
  def write_feed(opts \\ []) do
    alerts =
      Alerts.list_all_open()
      |> Enum.map(&CreateOutputAlert.build_alert/1)

    write_protobuf_file(alerts, opts)

    alerts_json = write_json_file(alerts, opts)
    {:ok, alerts_json |> Jason.decode!()}
  end

  defp write_json_file(alerts, opts) do
    write_fn = Keyword.get(opts, :write_fn, &File.write/2)
    alerts_json = CreateGtfsJson.output_enhanced_json(alerts)
    write_fn.(@enhanced_json_output_filename, alerts_json)
    alerts_json
  end

  defp write_protobuf_file(alerts, opts) do
    write_fn = Keyword.get(opts, :write_fn, &File.write/2)
    alerts_protobuf = CreateGtfsProtobuf.output_protobuf(alerts)
    write_fn.(@protobuf_output_filename, alerts_protobuf)
  end
end
