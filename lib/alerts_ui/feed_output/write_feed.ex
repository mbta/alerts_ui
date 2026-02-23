defmodule AlertsUI.FeedOutput.WriteFeed do
  @moduledoc """
    Writes json and protobuf feeds to file (s3 or local)
  """
  @standard_json_output_filename AlertsUI.config(:standard_json_output_filename)
  @enhanced_json_output_filename AlertsUI.config(:enhanced_json_output_filename)
  @protobuf_output_filename AlertsUI.config(:protobuf_output_filename)
  @combined_enhanced_json_output_filename AlertsUI.config(:combined_enhanced_json_output_filename)
  @combined_enhanced_sita_json_output_filename AlertsUI.config(
                                                 :combined_enhanced_sita_json_output_filename
                                               )
  @combined_standard_json_output_filename AlertsUI.config(:combined_standard_json_output_filename)
  @combined_protobuf_output_filename AlertsUI.config(:combined_protobuf_output_filename)
  @write_module AlertsUI.config(:file_write_module)

  alias AlertsUI.Alerts
  alias AlertsUI.FeedOutput.{CreateGtfsJson, CreateGtfsProtobuf, CreateOutputAlert, Filters}
  alias AlertsUI.FeedReader

  @spec write_feed() :: {:ok, binary()} | {:error, String.t()}
  def write_feed(_opts \\ []) do
    recently_closed_alerts = get_recently_closed_alerts()
    open_alerts = get_open_alerts()
    enhanced_alerts = Enum.concat(open_alerts, recently_closed_alerts)
    ibi_enhanced_alerts = get_ibi_alerts(:ibi_enhanced_alerts)
    ibi_standard_alerts = get_ibi_alerts(:ibi_standard_alerts)

    rv =
      with {:ok, enhanced_alerts_json} <- write(:enhanced, enhanced_alerts),
           {:ok, _} <- write(:standard, open_alerts),
           {:ok, _} <- write(:enhanced, enhanced_alerts),
           {:ok, _} <- write(:protobuf, open_alerts),
           {:ok, _} <- write(:combined_enhanced, enhanced_alerts ++ ibi_enhanced_alerts),
           {:ok, _} <- write(:combined_enhanced_sita, enhanced_alerts ++ ibi_enhanced_alerts),
           {:ok, _} <- write(:combined_standard, open_alerts ++ ibi_standard_alerts),
           {:ok, _} <- write(:combined_protobuf, open_alerts ++ ibi_standard_alerts) do
        {:ok, enhanced_alerts_json |> Jason.decode!()}
      else
        {:error, reason} -> {:error, reason}
      end

    rv
  end

  defp get_open_alerts do
    Alerts.list_all_open()
    |> Alerts.update_end_if_estimated()
    |> Alerts.close_if_end_is_past()
    |> Alerts.filter_on_notification_period_start()
    |> Enum.map(&CreateOutputAlert.build_alert/1)
  end

  defp get_recently_closed_alerts do
    Alerts.list_all_recently_closed()
    |> Enum.map(&CreateOutputAlert.build_alert/1)
  end

  defp get_ibi_alerts(flavor) do
    {:ok, alerts_json} = FeedReader.alerts_json(flavor)
    {:ok, ibi_data} = Jason.decode(alerts_json)
    %{"entity" => entity} = ibi_data
    entity
  end

  @spec write_data(String.t(), String.t()) :: {:ok | :error, String.t()}
  defp write_data(data, filename) do
    case @write_module.write(filename, data) do
      :ok -> {:ok, data}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec write(atom(), list(any())) :: {:ok | :error, String.t()}
  def write(flavor, alerts)

  def write(:standard, alerts),
    do:
      CreateGtfsJson.output_standard_json(alerts)
      |> write_data(@standard_json_output_filename)

  def write(:enhanced, alerts),
    do:
      CreateGtfsJson.output_enhanced_json(alerts)
      |> write_data(@enhanced_json_output_filename)

  def write(:protobuf, alerts),
    do:
      CreateGtfsProtobuf.output_protobuf(alerts)
      |> write_data(@protobuf_output_filename)

  def write(:combined_enhanced, alerts),
    do:
      CreateGtfsJson.output_enhanced_json(alerts)
      |> write_data(@combined_enhanced_json_output_filename)

  def write(:combined_enhanced_sita, alerts),
    do:
      alerts
      |> Filters.filter_sita_alerts()
      |> CreateGtfsJson.output_enhanced_json()
      |> write_data(@combined_enhanced_sita_json_output_filename)

  def write(:combined_standard, alerts),
    do:
      CreateGtfsJson.output_standard_json(alerts)
      |> write_data(@combined_standard_json_output_filename)

  def write(:combined_protobuf, alerts),
    do:
      CreateGtfsProtobuf.output_protobuf(alerts)
      |> write_data(@combined_protobuf_output_filename)
end
