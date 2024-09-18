defmodule AlertsUI.FeedOutput.WriteFeed do
  @moduledoc """
    Writes json and protobuf feeds to file (s3 or local)
  """
  @standard_json_output_filename AlertsUI.config(:standard_json_output_filename)
  @enhanced_json_output_filename AlertsUI.config(:enhanced_json_output_filename)
  @protobuf_output_filename AlertsUI.config(:protobuf_output_filename)
  @write_module AlertsUI.config(:file_write_module)

  alias AlertsUI.Alerts
  alias AlertsUI.FeedOutput.{CreateGtfsJson, CreateGtfsProtobuf, CreateOutputAlert}

  @spec write_feed() :: {:ok, binary()} | {:error, String.t()}
  def write_feed(_opts \\ []) do
    recently_closed_alerts = get_recently_closed_alerts()

    open_alerts =
      Alerts.list_all_open()
      |> Alerts.close_if_end_is_past()
      |> Alerts.filter_on_notification_period_start()
      |> Enum.map(&CreateOutputAlert.build_alert/1)

    with {:ok, enhanced_alerts_json} <-
           write_enhanced_json_file(Enum.concat(open_alerts, recently_closed_alerts)),
         :ok <- write_standard_json_file(open_alerts),
         :ok <- write_protobuf_file(open_alerts) do
      {:ok, enhanced_alerts_json |> Jason.decode!()}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp get_recently_closed_alerts do
    Alerts.list_all_recently_closed()
    |> Enum.map(&CreateOutputAlert.build_alert/1)
  end

  defp write_standard_json_file(alerts) do
    alerts_json = CreateGtfsJson.output_standard_json(alerts)

    case @write_module.write(@standard_json_output_filename, alerts_json) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp write_enhanced_json_file(alerts) do
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
