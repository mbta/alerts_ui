defmodule AlertsUI.FeedReader do
  @moduledoc """
  Contains the logic for loading IBI and dev_orange Alerts feeds in one place
  """

  alias ExAws.S3

  @doc """
  Fetch the IBI Alerts Feed as JSON
  """
  def ibi_json do
    get_ibi_feed()
    |> parse_response()
  end

  defp get_ibi_feed do
    get_http_fn = AlertsUI.config(:get_http_fn, &Req.get!/1)

    get_http_fn.(
      url: alert_api_url(),
      headers: %{"accept-encoding" => "gzip"},
      decode_body: false
    )
  end

  defp alert_api_url, do: AlertsUI.config(:alert_api_url)

  defp convert_newlines(text), do: String.replace(text, "\r\n", "\n")

  @doc """
  Fetch the Dev Orange feed from S3
  """
  def dev_orange_json do
    make_request_fn = AlertsUI.config(:make_request_fn, &ExAws.request!/1)

    dev_orange_feed()
    |> make_request_fn.()
    |> parse_response()
  end

  defp dev_orange_feed do
    get_obj_fn = AlertsUI.config(:get_obj_fn, &S3.get_object/2)

    get_obj_fn.(s3_bucket_name(), s3_file_path())
  end

  defp s3_bucket_name,
    do: AlertsUI.config(:s3_bucket_name)

  defp s3_file_path,
    do: "#{AlertsUI.config(:s3_bucket_prefix)}/#{enhanced_json_filename()}"

  defp enhanced_json_filename,
    do: AlertsUI.config(:enhanced_json_output_filename)

  defp parse_response(%{status: 200, body: json_body}),
    do: {:ok, convert_newlines(json_body)}

  defp parse_response(%{status_code: 200, body: json_body}),
    do: {:ok, json_body}

  defp parse_response(_),
    do: :error
end
