defmodule PocApiClient.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        {Oidcc.ProviderConfiguration.Worker,
         %{
           issuer: keycloak_issuer(),
           name: PocApiClient.OidccConfig
         }}
      ]

    opts = [strategy: :one_for_one, name: PocApiClient.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp keycloak_issuer, do: System.fetch_env!("POC_KEYCLOAK_ISSUER")
end
