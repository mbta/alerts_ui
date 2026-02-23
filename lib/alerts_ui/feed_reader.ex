defmodule AlertsUI.FeedReader do
  @moduledoc """
  Contains the logic for loading feeds from S3 buckets
  """

  @doc """
  Fetch an Alerts Feed as JSON

  alerts_json(:ibi_enhanced_alerts) -> IBI's enhanced feed
  alerts_json(:ibi_standard_alerts) -> IBI's standard production feed

  alerts_json(:enhanced_json) -> Our enhanced feed
  alerts_json(:enhanced_sita_json) -> Our enhanced modified SITA feed
  alerts_json(:standard_json) -> Our standard feed
  alerts_json(:standard_protobuf) -> Our protobuf feed (ok, this one isn't JSON.)
  """
  def alerts_json(flavor) do
    get_feed(flavor)
    |> parse_response()
  end

  defp get_feed(flavor) do
    get_http_fn = AlertsUI.config(:get_http_fn, &Req.get!/1)

    get_http_fn.(
      url: alerts_api_url(flavor),
      headers: %{"accept-encoding" => "gzip"},
      decode_body: false
    )
  end

  defp alerts_api_url(:ibi_enhanced_alerts), do: AlertsUI.config(:ibi_enhanced_alerts_api_url)
  defp alerts_api_url(:ibi_standard_alerts), do: AlertsUI.config(:ibi_standard_alerts_api_url)

  defp alerts_api_url(:enhanced_json), do: build_s3_path() <> "alerts_feed_enhanced.json"

  defp alerts_api_url(:enhanced_sita_json),
    do: build_s3_path() <> "alerts_feed_enhanced_SITA.json"

  defp alerts_api_url(:standard_json), do: build_s3_path() <> "alerts_feed.json"
  defp alerts_api_url(:standard_protobuf), do: build_s3_path() <> "alerts_feed.pb"

  defp build_s3_path do
    "https://#{System.get_env("S3_BUCKET_NAME", "")}.s3.amazonaws.com/#{System.get_env("S3_BUCKET_PREFIX", "")}/"
  end

  defp parse_response(%{status: 200, body: json_body}),
    do: {:ok, convert_newlines(json_body)}

  defp parse_response(%{status_code: 200, body: json_body}),
    do: {:ok, json_body}

  defp parse_response(_),
    do: :error

  defp convert_newlines(text), do: String.replace(text, "\r\n", "\n")
end
