defmodule AlertsUI.FeedOutput.WriteFeed do
  @moduledoc """
    Writes json and protobuf feeds to file (s3 or local)
  """
  @enhanced_json_output_filename AlertsUI.config(:enhanced_json_output_filename)
  @protobuf_output_filename AlertsUI.config(:protobuf_output_filename)
  @write_module AlertsUI.config(:file_write_module)

  alias AlertsUI.Alerts
  alias AlertsUI.FeedOutput.{CreateGtfsJson, CreateGtfsProtobuf, CreateOutputAlert}

  @spec write_feed() :: {:ok, binary()} | {:error, String.t()}
  def write_feed(_opts \\ []) do
    alerts =
      Alerts.list_all_open()
      |> Enum.map(&CreateOutputAlert.build_alert/1)

    with {:ok, alerts_json} <- write_json_file(alerts),
         :ok <- write_protobuf_file(alerts) do
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
