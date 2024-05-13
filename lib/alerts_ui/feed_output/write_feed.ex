defmodule AlertsUI.FeedOutput.WriteFeed do
  @moduledoc """
    Writes json and protobuf feeds to file (s3 or local)
  """
  @enhanced_json_output_filename AlertsUI.config(:enhanced_json_output_filename)
  @protobuf_output_filename AlertsUI.config(:protobuf_output_filename)
  @write_module AlertsUI.config(:file_write_module)

  alias AlertsUI.Alerts
  alias AlertsUI.FeedOutput.{CreateGtfsJson, CreateGtfsProtobuf, CreateOutputAlert}
  @spec compare_feed :: boolean()
  defp compare_feed,
    do: Application.get_env(:alerts_ui, :compare_feed) == "true"

  @spec write_feed() :: {:ok, binary()} | {:error, String.t()}
  def write_feed(_opts \\ []) do
    open_alerts =
      Alerts.list_all_open()
      |> Enum.map(&CreateOutputAlert.build_alert/1)

    recently_closed_alerts =
      Alerts.list_all_recently_closed()
      |> Enum.map(&CreateOutputAlert.build_alert/1)

    # when we diff we want to compare only closed alerts. Remove this line
    # when diffing is turned off
    recently_closed_alerts = if compare_feed(), do: [], else: recently_closed_alerts

    with {:ok, alerts_json} <- write_json_file(Enum.concat(open_alerts, recently_closed_alerts)),
         :ok <- write_protobuf_file(open_alerts) do
      {:ok, alerts_json |> Jason.decode!()}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp write_json_file(alerts) do
    alerts_json = CreateGtfsJson.output_enhanced_json(alerts)

    case @write_module.write(@enhanced_json_output_filename, alerts_json) do
      :ok -> {:ok, alerts_json}
      {:error, reason} -> {:error, reason}
    end
  end

  defp write_protobuf_file(alerts) do
    alerts_protobuf = CreateGtfsProtobuf.output_protobuf(alerts)
    @write_module.write(@protobuf_output_filename, alerts_protobuf)
  end
end
