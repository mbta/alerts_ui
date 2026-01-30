defmodule AlertsUIWeb.UserAuth do
  @moduledoc """
  Context for user authentication operations.
  """

  use AlertsUIWeb, :verified_routes

  require Logger

  import Plug.Conn
  import Phoenix.Controller

  alias AlertsUI.Models.User
  alias Oidcc.{ClientContext, Token}
  alias Plug.Conn

  @doc """
  Logs the user in.

  It renews the session ID and clears the whole session
  to avoid fixation attacks. See the renew_session
  function to customize this behaviour.

  It also sets a `:live_socket_id` key in the session,
  so LiveView sessions are identified and automatically
  disconnected on log out. The line can be safely removed
  if you are not using LiveView.
  """
  # todo fix any
  @spec log_in_user(Conn.t(), User.t(), String.t(), any()) :: Conn.t()
  def log_in_user(conn, user, logout_uri, auth_time) do
    user_return_to = get_session(conn, :user_return_to)

    conn
    |> renew_session()
    |> put_current_user_in_session(user)
    |> put_session(:logout_uri, logout_uri)
    |> put_session(:last_auth_time, auth_time)
    |> redirect(to: user_return_to || signed_in_path(conn))
  end

  @doc """
  Logs the user out.

  It clears all session data for safety. See renew_session.

  Redirects the user to the Keycloak signout endpoint unless the
  `skip_oidc_sign_out` option is set.
  """
  @spec log_out_user(Conn.t(), keyword()) :: Conn.t()
  def log_out_user(conn, opts \\ []) do
    if live_socket_id = get_session(conn, :live_socket_id) do
      AlertsUIWeb.Endpoint.broadcast(live_socket_id, "disconnect", %{})
    end

    logout_uri = Conn.get_session(conn, :logout_uri)

    redirect_to =
      if Keyword.get(opts, :skip_oidc_sign_out, false) or is_nil(logout_uri) do
        [to: ~p"/"]
      else
        [external: logout_uri]
      end

    conn
    |> renew_session()
    |> redirect(redirect_to)
  end

  @doc """
  Authenticates the user by looking into the session.
  """
  def fetch_current_user(conn, _opts) do
    {user, conn} = ensure_session_user(conn)
    assign(conn, :current_user, user)
  end

  @doc """
  Handles mounting and authenticating the current_user in LiveViews.

  ## `on_mount` arguments

    * `:mount_current_user` - Assigns current_user to socket assigns based on
      session user, or nil if there's no session user.

    * `:ensure_authenticated` - Authenticates the user from the session, and
      assigns the current_user to socket assigns based on session user.
      Redirects to login page if there's no logged user.

    * `:redirect_if_user_is_authenticated` - Authenticates the user from the session.
      Redirects to signed_in_path if there's a logged user.

  ## Examples

  Use the `on_mount` lifecycle macro in LiveViews to mount or authenticate
  the current_user:

      defmodule AlertsUIWeb.PageLive do
        use AlertsUIWeb, :live_view

        on_mount {AlertsUIWeb.UserAuth, :mount_current_user}
        ...
      end

  Or use the `live_session` of your router to invoke the on_mount callback:

      live_session :authenticated, on_mount: [{AlertsUIWeb.UserAuth, :ensure_authenticated}] do
        live "/profile", ProfileLive, :index
      end
  """
  def on_mount(:mount_current_user, _params, session, socket) do
    {:cont, mount_current_user(socket, session)}
  end

  def on_mount(:ensure_authenticated, _params, session, socket) do
    socket =
      socket
      |> mount_current_user(session)
      |> mount_auth_times(session)

    if socket.assigns.current_user do
      {:cont, socket}
    else
      socket = Phoenix.LiveView.redirect(socket, to: ~p"/auth/keycloak")

      {:halt, socket}
    end
  end

  def on_mount(:redirect_if_user_is_authenticated, _params, session, socket) do
    socket = mount_current_user(socket, session)

    if socket.assigns.current_user do
      {:halt, Phoenix.LiveView.redirect(socket, to: signed_in_path(socket))}
    else
      {:cont, socket}
    end
  end

  def max_session_time do
    Application.get_env(:alerts_ui, __MODULE__)[:max_session_time]
  end

  def idle_time do
    Application.get_env(:alerts_ui, __MODULE__)[:idle_time]
  end

  @doc """
  Plug used for routes that require the user to be authenticated.

  If you want to enforce the user email is confirmed before
  they use the application at all, here would be a good place.
  """
  def require_authenticated_user(conn, _opts) do
    last_auth_time = get_session(conn, :last_auth_time)

    if conn.assigns[:current_user] && last_auth_time do
      now = System.system_time(:second)
      last_active = get_session(conn, :last_active, now)

      # last_auth_time is when the user entered their password at the SSO provider
      auth_time_expires = last_auth_time + max_session_time()
      # last_active is time of last request
      idle_time_expires = last_active + idle_time()
      # did either timeout expire?
      if min(auth_time_expires, idle_time_expires) < now do
        conn
        |> maybe_store_return_to()
        |> log_out_user()
        |> halt()
      else
        put_session(conn, :last_active, now)
      end
    else
      conn
      |> maybe_store_return_to()
      |> redirect(to: ~p"/auth/keycloak")
      |> halt()
    end
  end

  def require_roles(conn, opts) do
    required_roles = Keyword.get(opts, :required_roles, [])
    user = conn.assigns[:current_user]

    if user && Enum.all?(required_roles, fn x -> x in user.roles end) do
      conn
    else
      conn
      |> put_flash(:error, "You don't have permission to access that page")
      |> redirect(to: "/")
      |> halt()
    end
  end

  @doc """
  Plug used for API routes that require the user to be authenticated.
  """
  def require_authenticated_api_user(conn, _opts) do
    with {:ok, token} <- get_authorization_token(conn),
         {:ok, client_context} <-
           ClientContext.from_configuration_worker(
             keycloak_issuer(),
             keycloak_client_id(),
             keycloak_client_secret()
           ),
         {:ok,
          %{
            "resource_access" => %{
              "alerts-ui" => %{"roles" => roles}
            }
          }} <- Token.validate_jwt(token, client_context, %{signing_algs: ["RS256"]}),
         true <- "api-writer" in roles do
      conn
    else
      false ->
        conn
        |> put_status(401)
        |> json(%{error: :unauthorized})
        |> halt()

      {:ok, _claims} ->
        conn
        |> put_status(403)
        |> json(%{error: :unauthorized})
        |> halt()

      {:error, _error} ->
        conn
        |> put_status(401)
        |> json(%{error: :unauthenticated})
        |> halt()
    end
  end

  # This function renews the session ID and erases the whole
  # session to avoid fixation attacks. If there is any data
  # in the session you may want to preserve after log in/log out,
  # you must explicitly fetch the session data before clearing
  # and then immediately set it after clearing, for example:
  #
  #     defp renew_session(conn) do
  #       preferred_locale = get_session(conn, :preferred_locale)
  #
  #       conn
  #       |> configure_session(renew: true)
  #       |> clear_session()
  #       |> put_session(:preferred_locale, preferred_locale)
  #     end
  #
  defp renew_session(conn) do
    conn
    |> configure_session(renew: true)
    |> clear_session()
  end

  @spec ensure_session_user(Conn.t()) :: {User.t(), Conn.t()} | {nil, Conn.t()}
  defp ensure_session_user(conn) do
    if user = get_session(conn, :user) do
      {user, conn}
    else
      {nil, conn}
    end
  end

  defp mount_auth_times(socket, session) do
    socket
    |> Phoenix.Component.assign_new(:last_auth_time, fn ->
      session["last_auth_time"]
    end)
    |> Phoenix.Component.assign_new(:last_active, fn ->
      session["last_active"]
    end)
  end

  defp mount_current_user(socket, session) do
    Phoenix.Component.assign_new(socket, :current_user, fn ->
      session["user"]
    end)
  end

  defp put_current_user_in_session(conn, user) do
    conn
    |> put_session(:user, user)
    |> put_session(:live_socket_id, "users_sessions:#{User.keycloak_id(user)}")
  end

  defp maybe_store_return_to(%{method: "GET"} = conn) do
    put_session(conn, :user_return_to, current_path(conn))
  end

  defp maybe_store_return_to(conn), do: conn

  defp signed_in_path(_conn), do: ~p"/"

  @spec get_authorization_token(Conn.t()) :: {:ok, String.t()} | {:error, String.t()}
  defp get_authorization_token(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] -> {:ok, token}
      _ -> {:error, "No token"}
    end
  end

  @spec keycloak_issuer :: atom()
  defp keycloak_issuer do
    {_, base_opts} = Application.get_env(:ueberauth, Ueberauth)[:providers][:keycloak]
    base_opts[:issuer]
  end

  @spec keycloak_client_id :: String.t()
  defp keycloak_client_id,
    do: Application.get_env(:ueberauth_oidcc, :providers)[:keycloak][:client_id]

  @spec keycloak_client_secret :: String.t()
  defp keycloak_client_secret,
    do: Application.get_env(:ueberauth_oidcc, :providers)[:keycloak][:client_secret]
end
