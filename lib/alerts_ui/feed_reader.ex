defmodule AlertsUI.FeedReader do
  @moduledoc """
  Contains the logic for loading feeds from S3 buckets
  """

  @doc """
  Fetch an Alerts Feed as JSON

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

  @doc """
  Fetch the Dev Orange feed from S3
  """
  def dev_orange_json do
    make_request_fn = AlertsUI.config(:make_request_fn, &ExAws.request!/1)

    skate_feed()
    |> make_request_fn.()
    |> parse_response()
  end

  defp skate_feed do
    get_obj_fn = AlertsUI.config(:get_obj_fn, &ExAws.S3.get_object/2)

    get_obj_fn.(skate_bucket_name(), skate_file_path())
  end

  defp skate_bucket_name,
    do: AlertsUI.config(:skate_bucket_name)

  defp skate_file_path,
    do: AlertsUI.config(:skate_file_path)
end
