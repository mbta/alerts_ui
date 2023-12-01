defmodule AlertsUI.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    load_runtime_config()

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
        {Oban, Application.fetch_env!(:alerts_ui, Oban)}
      ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    Oban.Telemetry.attach_default_logger()
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

  @doc """
  Check system environment variables at runtime and load them into the application environment.

  Will recursively check the keys below in the application config for any {:system, "ENVIRONMENT_VARIABLE"},
  and replace them with the value in the given environment variable.

  """
  @spec load_runtime_config :: :ok
  def load_runtime_config do
    application_keys = [
      :alert_api_url
    ]

    for application_key <- application_keys do
      Application.put_env(
        :alerts_ui,
        application_key,
        runtime_config(Application.get_env(:alerts_ui, application_key))
      )
    end

    :ok
  end

  @spec runtime_config(any()) :: any()
  defp runtime_config(list) when is_list(list) do
    Enum.map(list, fn elem ->
      case elem do
        {key, value} when is_atom(key) ->
          {key, runtime_config(value)}

        _ ->
          elem
      end
    end)
  end

  defp runtime_config({:system, environment_variable}) do
    System.get_env(environment_variable)
  end

  defp runtime_config(value) do
    value
  end
end
