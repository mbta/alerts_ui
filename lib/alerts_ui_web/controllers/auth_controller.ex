defmodule AlertsUIWeb.AuthController do
  @moduledoc """
  Handle interactions related to authentication via Keycloak.
  """
  use AlertsUIWeb, :controller

  require Logger

  alias AlertsUI.Models.User
  alias AlertsUIWeb.UserAuth
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
                    claims: %{"sub" => id},
                    userinfo: userinfo
                  }
                }
              } = auth
          }
        } = conn,
        _params
      ) do
    IO.inspect(auth, label: "full auth")
    roles = userinfo
    |> IO.inspect()
    |> parse_role()
    user = User.new(id, email, first_name, last_name, roles)
    |> IO.inspect(label: "User from Keycloak")
    {:ok, logout_uri} = logout_uri(auth)

    UserAuth.log_in_user(conn, user, logout_uri)
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

  defp parse_role(_), do: [:viewer]

  @spec logout_uri(map()) :: {:ok, String.t()}
  defp logout_uri(%Ueberauth.Auth{strategy: Ueberauth.Strategy.FakeKeycloak}) do
    {:ok, "fake logout url"}
  end

  defp logout_uri(%Ueberauth.Auth{strategy: Ueberauth.Strategy.Oidcc} = auth) do
    logout_params = %{post_logout_redirect_uri: url(~p"/")}
    UeberauthOidcc.initiate_logout_url(auth, logout_params)
  end
end
