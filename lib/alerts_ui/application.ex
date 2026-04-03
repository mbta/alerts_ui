defmodule AlertsUI.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # load_runtime_config()

    children =
      [
        {Ecto.Migrator,
         repos: Application.fetch_env!(:alerts_ui, :ecto_repos),
         skip: AlertsUI.config(:skip_migrations) == true},
        # Start the Telemetry supervisor
        AlertsUIWeb.Telemetry,
        # Start the Ecto repository
        AlertsUI.Repo,
        # Start the PubSub system
        {Phoenix.PubSub, name: AlertsUI.PubSub},
        # Start the Endpoint (http/https)
        AlertsUIWeb.Endpoint,
        {Oban, Application.fetch_env!(:alerts_ui, Oban)},
        {AlertsUI.CacheWarmer, []}
      ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    Oban.Telemetry.attach_default_logger()

    :ok =
      :telemetry.attach(
        "ecto-handler",
        [:alerts_ui, :repo, :query],
        &AlertsUI.Telemetry.handle_event/4,
        %{}
      )

    :ok =
      :telemetry.attach(
        "vm-queue-logger",
        [:vm, :total_run_queue_lengths],
        &AlertsUI.Telemetry.handle_event/4,
        %{}
      )

    :ok =
      :telemetry.attach(
        "vm-memory-logger",
        [:vm, :memory],
        &AlertsUI.Telemetry.handle_event/4,
        %{}
      )

    opts = [strategy: :one_for_one, name: AlertsUI.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    AlertsUIWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
