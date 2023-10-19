defmodule AlertsUI.GTFSIntake.GTFSSupervisor do
  @moduledoc """
  Supervisor for realtime alert information from realtime GTFS.
  """
  use Supervisor
  alias AlertsUI.GTFSIntake.AlertsIntake
  alias AlertsUI.HttpProducer

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts)
  end

  @impl true
  def init(opts) do
    alert_api_url =
      Keyword.get(
        opts,
        :alert_api_url,
        Application.get_env(:alerts_ui, :alert_api_url)
      )

    source =
      http_source(
        :alert_updates,
        alert_api_url,
        AlertsUI.GTFSIntake.RealtimeEnhancedParser,
        headers: %{},
        params: %{}
      )

    consumer =
      Supervisor.child_spec(
        {AlertsIntake, subscribe_to: [{:alert_updates, [max_demand: 1]}]},
        []
      )

    Supervisor.init([source, consumer], strategy: :one_for_one)
  end

  @spec http_source(term(), String.t(), module(), keyword()) :: Supervisor.child_spec()
  defp http_source(source, url, parser, opts) do
    Supervisor.child_spec(
      {
        HttpProducer,
        {url, [name: source, parser: parser] ++ opts}
      },
      id: source
    )
  end
end
