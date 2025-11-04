defmodule AlertsUI.FeedReader do
  @moduledoc """
  Contains the logic for loading IBI and dev_orange Alerts feeds in one place
  """

  alias ExAws.S3

  @doc """
  Fetch the IBI Alerts Feed as JSON

  ibi_json(:enhanced) -> IBI's enhanced feed (default)
  ibi_json(:standard) -> IBI's standard production feed (no dev version)
  """
  def ibi_json(flavor \\ :enhanced) do
    get_ibi_feed(flavor)
    |> parse_response()
  end

  defp get_ibi_feed(flavor) do
    get_http_fn = AlertsUI.config(:get_http_fn, &Req.get!/1)

    get_http_fn.(
      url: ibi_alerts_api_url(flavor),
      headers: %{"accept-encoding" => "gzip"},
      decode_body: false
    )
  end

  defp ibi_alerts_api_url(:enhanced), do: AlertsUI.config(:ibi_enhanced_alerts_api_url)
  defp ibi_alerts_api_url(:standard), do: AlertsUI.config(:ibi_standard_alerts_api_url)

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
