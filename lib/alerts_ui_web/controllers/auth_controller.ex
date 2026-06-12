defmodule AlertsUIWeb.AuthController do
  @moduledoc """
  Handle interactions related to authentication via Keycloak.
  """
  use AlertsUIWeb, :controller

  require Logger

  alias AlertsUI.Models.User
  alias AlertsUIWeb.UserAuth
  alias Oidcc.ProviderConfiguration.Worker, as: ProviderConfiguration
  alias Plug.Conn

  plug(Ueberauth)

  @spec callback(Conn.t(), any) :: Conn.t()
  def callback(
        %{
          assigns: %{
            ueberauth_auth:
              %{
                info: %{
                  email: email,
                  first_name: first_name,
                  last_name: last_name
                },
                extra: %{
                  raw_info: %{
                    claims: %{"sub" => id, "auth_time" => auth_time},
                    userinfo: userinfo
                  }
                }
              } = auth
          }
        } = conn,
        _params
      ) do
    roles = parse_role(userinfo)
    user = User.new(id, email, first_name, last_name, roles)
    {:ok, logout_uri} = logout_uri(auth)

    UserAuth.log_in_user(conn, user, logout_uri, auth_time)
  end

  def callback(%{assigns: %{ueberauth_failure: failure}} = conn, _params) do
    Logger.info("Ueberauth failure: #{inspect(failure)}")
    UserAuth.log_out_user(conn, skip_oidc_sign_out: true)
  end

  def callback(%{assigns: assigns} = conn, params) do
    Logger.warning(
      "Unexpected Ueberauth callback assigns=#{inspect(assigns)} params=#{inspect(params)}"
    )

    UserAuth.log_out_user(conn, skip_oidc_sign_out: true)
  end

  @spec logout(Conn.t(), map()) :: Conn.t()
  def logout(conn, _params) do
    UserAuth.log_out_user(conn)
  end

  @spec request(Conn.t(), map()) :: Conn.t()
  def request(conn, _params) do
    conn
    |> redirect(to: "/not-found")
    |> halt()
  end

  # Parse the user's roles from the access token provided by Keycloak
  @spec parse_role(map()) :: [User.role()]
  defp parse_role(%{"resource_access" => %{"alerts-ui" => %{"roles" => roles}}})
       when is_list(roles),
       do: roles |> Enum.map(&String.to_existing_atom/1)

  defp parse_role(_), do: []

  @spec logout_uri(map()) :: {:ok, String.t()} | {:error, atom()}
  defp logout_uri(%Ueberauth.Auth{strategy: Ueberauth.Strategy.FakeKeycloak}) do
    {:ok, "fake logout url"}
  end

  defp logout_uri(%Ueberauth.Auth{strategy: Ueberauth.Strategy.Oidcc}) do
    provider_config =
      ProviderConfiguration.get_provider_configuration(:keycloak_issuer)

    case provider_config.end_session_endpoint do
      :undefined ->
        {:error, :end_session_endpoint_not_supported}

      end_session_endpoint ->
        client_id = Application.get_env(:ueberauth_oidcc, :providers)[:keycloak][:client_id]

        query =
          URI.encode_query(%{
            "client_id" => client_id,
            "post_logout_redirect_uri" => url(~p"/")
          })

        {:ok, URI.to_string(%{URI.parse(to_string(end_session_endpoint)) | query: query})}
    end
  end
end
