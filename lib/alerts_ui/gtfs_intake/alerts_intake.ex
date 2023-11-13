defmodule AlertsUI.GTFSIntake.AlertsIntake do
  @moduledoc """
  Fetches the Alerts GTFS feed, parses it, and uses it to create or update alerts.
  """
  require Logger
  alias AlertsUI.Alerts
  alias AlertsUI.GTFSIntake.RealtimeEnhancedParser
  alias AlertsUI.Models.Alert

  @spec run :: :ok
  def run(opts \\ []) do
    opts
    |> fetch_feed()
    |> parse_response()
    |> Alerts.close_if_not_in_feed()
    |> Enum.each(&Alerts.create_or_modify_alert(&1))

    :ok
  end

  @spec fetch_feed(keyword()) :: {:http_response, HTTPoison.Response.t()} | {:http_error, any()}
  defp fetch_feed(opts) do
    get_fn = Keyword.get(opts, :get_fn, &HTTPoison.get/3)

    headers = %{"accept-encoding" => "gzip"}

    get_opts = [
      timeout: 15_000,
      recv_timeout: 15_000,
      hackney: [pool: :alerts_import_pool]
    ]

    case get_fn.(alert_api_url(), headers, get_opts) do
      {:ok, %HTTPoison.Response{} = response} ->
        {:http_response, response}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.warning("Error fetching alerts feed, reason=#{reason}")
        {:http_error, reason}
    end
  end

  @spec alert_api_url :: String.t()
  defp alert_api_url, do: Application.get_env(:alerts_ui, :alert_api_url)

  @spec parse_response({:http_response, HTTPoison.Response.t()} | {:http_error, any()}) :: [
          AlertsUI.Models.Alert.t()
        ]
  defp parse_response(
         {:http_response, %HTTPoison.Response{status_code: 200, headers: headers, body: body}}
       ) do
    headers
    |> decode_body(body)
    |> parse_body()
  end

  defp parse_response({:http_error, _reason}), do: []

  defp decode_body(headers, body) do
    case find_header(headers, "content-encoding") do
      :error ->
        body

      {:ok, "gzip"} ->
        :zlib.gunzip(body)
    end
  end

  defp find_header(headers, match_header) do
    case Enum.find(headers, &(String.downcase(elem(&1, 0)) == match_header)) do
      {_, value} ->
        {:ok, value}

      _ ->
        :error
    end
  end

  @spec parse_body(binary()) :: [Alert.t()]
  defp parse_body(body) do
    {time, parsed} = :timer.tc(RealtimeEnhancedParser, :parse, [body])

    Logger.info(fn ->
      "#{__MODULE__} Parsed alerts feed: records=#{length(parsed)} time=#{time / 1000}"
    end)

    parsed
  rescue
    error ->
      log_parse_error(error, __STACKTRACE__, body)
      []
  catch
    error ->
      log_parse_error(error, __STACKTRACE__, body)
      []
  end

  defp log_parse_error(error, trace, body) do
    Logger.error(fn ->
      "#{__MODULE__}: Alerts feed parse error error=#{inspect(error)}\n#{Exception.format_stacktrace(trace)}\n body=#{body}"
    end)
  end
end
