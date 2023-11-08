defmodule AlertsUI.FeedOutput.AlertsOutput do
  @moduledoc """
  Outputs a GTFS Alert feed
  """
  use GenServer
  alias AlertsUI.Alerts
  require Logger

  @thirty_seconds 30_000

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @spec init(any()) :: {:ok, any()}
  def init(opts) do
    Process.send_after(self(), :output, @thirty_seconds)
    {:ok, opts}
  end

  def handle_info(:output, state) do
    Process.send_after(self(), :output, @thirty_seconds)

    Alerts.list_all_open()
    |> Enum.map(& &1.alert_id)
    |> length
    |> Logger.info()

    {:noreply, state}
  end
end
