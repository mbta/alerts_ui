defmodule AlertsUIWeb.UserAuth do
  @moduledoc """
  Context for user authentication operations.
  """

  use AlertsUIWeb, :verified_routes

  import Plug.Conn
  import Phoenix.Controller

  alias AlertsUIWeb.User
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
  @spec log_in_user(Conn.t(), User.t(), String.t()) :: Conn.t()
  def log_in_user(conn, user, logout_uri) do
    user_return_to = get_session(conn, :user_return_to)

    conn
    |> renew_session()
    |> put_current_user_in_session(user)
    |> put_session(:logout_uri, logout_uri)
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
    |> put_flash(:info, "You have been signed out.")
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
    socket = mount_current_user(socket, session)

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

  @doc """
  Plug used for routes that require the user to not be authenticated.
  """
  def redirect_if_user_is_authenticated(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
      |> redirect(to: signed_in_path(conn))
      |> halt()
    else
      conn
    end
  end

  @doc """
  Plug used for routes that require the user to be authenticated.

  If you want to enforce the user email is confirmed before
  they use the application at all, here would be a good place.
  """
  def require_authenticated_user(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> maybe_store_return_to()
      |> redirect(to: ~p"/auth/keycloak")
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

  defp mount_current_user(socket, session) do
    Phoenix.Component.assign_new(socket, :current_user, fn ->
      session["user"]
    end)
  end

  defp put_current_user_in_session(conn, user) do
    conn
    |> put_session(:user, user)
    |> put_session(:live_socket_id, "users_sessions:#{User.id(user)}")
  end

  defp maybe_store_return_to(%{method: "GET"} = conn) do
    put_session(conn, :user_return_to, current_path(conn))
  end

  defp maybe_store_return_to(conn), do: conn

  defp signed_in_path(_conn), do: ~p"/"
end
