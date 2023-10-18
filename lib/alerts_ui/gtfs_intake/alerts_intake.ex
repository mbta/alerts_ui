defmodule AlertsUI.GTFSIntake.AlertsIntake do
  @moduledoc """
  Consumes output from the Alerts GTFS feed and does things to them.
  """
  use GenStage
  require Logger
  alias AlertsUI.Alerts

  @spec start_link(any) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(opts) do
    GenStage.start_link(__MODULE__, opts)
  end

  @impl GenStage
  def init(opts) do
    {:consumer, :the_state_does_not_matter, opts}
  end

  # If we get a reply after we've already timed out, ignore it
  @impl GenStage
  def handle_info({reference, _}, state) when is_reference(reference),
    do: {:noreply, [], state}

  @impl GenStage
  def handle_events(events, _from, state) do
    events
    |> List.flatten()
    |> Enum.each(&Alerts.create_alert(&1))

    {:noreply, [], state}
  end
end
