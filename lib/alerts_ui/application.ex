defmodule AlertsUI.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      AlertsUIWeb.Telemetry,
      # Start the Ecto repository
      AlertsUI.Repo,
      # Start the PubSub system
      {Phoenix.PubSub, name: AlertsUI.PubSub},
      # Start Finch
      {Finch, name: AlertsUI.Finch},
      # Start the Endpoint (http/https)
      AlertsUIWeb.Endpoint
      # Start a worker by calling: AlertsUI.Worker.start_link(arg)
      # {AlertsUI.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
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
