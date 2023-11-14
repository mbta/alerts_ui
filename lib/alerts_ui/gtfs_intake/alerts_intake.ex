defmodule AlertsUI.GTFSIntake.AlertsIntake do
  @moduledoc """
  Fetches the Alerts GTFS feed, parses it, and uses it to create or update alerts.
  """
  require Logger
  alias AlertsUI.Alerts
  alias AlertsUI.GTFSIntake.RealtimeEnhancedParser
  alias Req.Response

  @spec run :: :ok
  def run(opts \\ []) do
    opts
    |> fetch_feed()
    |> parse_response()
    |> Alerts.close_if_not_in_feed()
    |> Enum.each(&Alerts.create_or_modify_alert(&1))

    :ok
  end

  @spec fetch_feed(keyword()) :: Response.t()
  defp fetch_feed(opts) do
    get_fn = Keyword.get(opts, :get_fn, &Req.get!/1)

    get_fn.(
      url: alert_api_url(),
      headers: %{"accept-encoding" => "gzip"}
    )
  end

  @spec alert_api_url :: String.t()
  defp alert_api_url, do: Application.get_env(:alerts_ui, :alert_api_url)

  @spec parse_response(Response.t()) :: [map()]
  defp parse_response(%Response{status: 200, body: body}), do: parse_body(body)

  defp parse_response(_), do: []

  @spec parse_body(binary()) :: [map()]
  defp parse_body(body) do
    {time, parsed} = :timer.tc(RealtimeEnhancedParser, :parse, [body])

    Logger.info(fn ->
      "#{__MODULE__} Parsed alerts feed: records=#{length(parsed)} time=#{time / 1_000}"
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
      "#{__MODULE__}: Alerts feed parse error error=#{inspect(error)}\n#{Exception.format_stacktrace(trace)}\n body=#{inspect(body)}"
    end)
  end
end
