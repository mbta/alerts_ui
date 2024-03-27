defmodule AlertsUIWeb.ValidateLive do
  @moduledoc """
  LiveView for validating our alert feed compared with the previous version.
  """
  use AlertsUIWeb, :live_view

  alias AlertsUI.FeedOutput.CompareFeed
  alias ExAws.S3

  @enhanced_json_filename AlertsUI.config(:enhanced_json_output_filename)

  def mount(_params, _session, socket) do
    {:ok, ibi_json} = ibi_json()
    {:ok, ibi_data} = Jason.decode(ibi_json)

    {:ok, dev_orange_json} = dev_orange_json()
    {:ok, dev_orange_data} = Jason.decode(dev_orange_json)

    {:ok,
     assign(socket,
       ibi_json: ibi_json,
       ibi_data: ibi_data,
       ibi_alert_data: nil,
       ibi_alert_id: "",
       dev_orange_json: dev_orange_json,
       dev_orange_data: dev_orange_data,
       dev_orange_alert_data: nil,
       dev_orange_alert_id: "",
       comparison: nil
     )}
  end

  def handle_event("search", %{"ibi_alert_id" => ibi_alert_id}, socket) do
    ibi_alert_data = find_alert(socket.assigns.ibi_data, ibi_alert_id)

    comparison = compare_alerts(ibi_alert_data, socket.assigns.dev_orange_alert_data)

    {:noreply,
     assign(socket,
       ibi_alert_id: ibi_alert_id,
       ibi_alert_data: ibi_alert_data,
       comparison: comparison
     )}
  end

  def handle_event("search", %{"dev_orange_alert_id" => dev_orange_alert_id}, socket) do
    dev_orange_alert_data = find_alert(socket.assigns.dev_orange_data, dev_orange_alert_id)

    comparison = compare_alerts(socket.assigns.ibi_alert_data, dev_orange_alert_data)

    {:noreply,
     assign(socket,
       dev_orange_alert_id: dev_orange_alert_id,
       dev_orange_alert_data: dev_orange_alert_data,
       comparison: comparison
     )}
  end

  def pretty_print(obj), do: inspect(obj, pretty: true)

  defp ibi_json do
    get_ibi_feed()
    |> parse_ibi_response()
  end

  defp get_ibi_feed do
    get_http_fn = Application.get_env(:alerts_ui, :get_http_fn, &Req.get!/1)

    get_http_fn.(
      url: alert_api_url(),
      headers: %{"accept-encoding" => "gzip"},
      decode_body: false
    )
  end

  defp alert_api_url, do: Application.get_env(:alerts_ui, :alert_api_url)

  defp parse_ibi_response(%{status: 200, body: json_body}),
    do: {:ok, convert_newlines(json_body)}

  defp parse_ibi_response(_), do: :error

  defp convert_newlines(text), do: String.replace(text, "\r\n", "\n")

  defp dev_orange_json do
    make_request_fn = Application.get_env(:alerts_ui, :make_request_fn, &ExAws.request!/1)

    dev_orange_feed()
    |> make_request_fn.()
    |> parse_s3_response()
  end

  defp dev_orange_feed do
    get_obj_fn = Application.get_env(:alerts_ui, :get_obj_fn, &S3.get_object/2)

    get_obj_fn.(s3_bucket_name(), s3_file_path())
  end

  defp s3_bucket_name, do: System.get_env("S3_BUCKET_NAME", "")

  defp s3_file_path, do: "#{System.get_env("S3_BUCKET_PREFIX", "")}/#{@enhanced_json_filename}"

  defp parse_s3_response(%{body: json_body, status_code: 200}), do: {:ok, json_body}
  defp parse_s3_response(_), do: :error

  defp find_alert(json, id) do
    json
    |> alerts()
    |> Enum.find(:not_found, &matches_id?(&1, id))
  end

  defp alerts(json), do: Map.get(json, "entity")

  defp matches_id?(%{"id" => alert_id}, id), do: alert_id == id

  defp compare_alerts(nil, _dev_orange_alert_data), do: nil
  defp compare_alerts(_ibi_alert_data, nil), do: nil
  defp compare_alerts(:not_found, _dev_orange_alert_data), do: nil
  defp compare_alerts(_ibi_alert_data, :not_found), do: nil

  defp compare_alerts(ibi_alert_data, dev_orange_alert_data),
    do: CompareFeed.compare_alerts(ibi_alert_data, dev_orange_alert_data)
end
