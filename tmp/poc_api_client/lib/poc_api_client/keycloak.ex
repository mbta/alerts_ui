defmodule PocApiClient.Keycloak do
  @moduledoc """
  Signs in an API client via Keycloak.
  """

  require Logger

  def token do
    {:ok, %Oidcc.Token{access: %Oidcc.Token.Access{token: token}}} =
      Oidcc.client_credentials_token(PocApiClient.OidccConfig, client_id(), client_secret(), %{})

    {:ok, token}
  end

  defp client_id, do: System.fetch_env!("POC_CLIENT_ID")
  defp client_secret, do: System.fetch_env!("POC_CLIENT_SECRET")
end
