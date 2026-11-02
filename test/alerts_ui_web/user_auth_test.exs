defmodule AlertsUIWeb.UserAuthTest do
  @moduledoc false
  use AlertsUIWeb.ConnCase, async: true

  import AlertsUI.UsersFixtures
  import Mock
  import Test.Support.Helpers
  import Phoenix.LiveViewTest
  import AlertsUI.Support.Factory

  alias AlertsUIWeb.UserAuth
  alias Oidcc.{ClientContext, Token}
  alias Phoenix.LiveView
  alias Plug.Conn

  @now System.system_time(:second)

  setup %{conn: conn} do
    conn =
      conn
      |> Map.replace!(:secret_key_base, AlertsUIWeb.Endpoint.config(:secret_key_base))
      |> init_test_session(%{})

    %{user: user_fixture(), conn: conn}
  end

  describe "log_in_user/4" do
    test "stores the user in the session", %{conn: conn, user: user} do
      conn = UserAuth.log_in_user(conn, user, logout_uri(), @now)

      assert session_user = get_session(conn, :user)
      assert session_user == user

      assert get_session(conn, :live_socket_id) == "users_sessions:#{user.keycloak_id}"

      assert redirected_to(conn) == ~p"/"
    end

    test "stores the logout URI in a path-scoped cookie, not the session", %{
      conn: conn,
      user: user
    } do
      conn = UserAuth.log_in_user(conn, user, logout_uri(), @now)

      assert %{value: value, path: "/auth/keycloak/logout"} =
               conn.resp_cookies["_alerts_ui_logout"]

      assert is_binary(value)
      refute get_session(conn, :logout_uri)
    end

    test "stores a fresh, per-session salt for the logout cookie", %{conn: conn, user: user} do
      conn1 = UserAuth.log_in_user(conn, user, logout_uri(), @now)
      conn2 = UserAuth.log_in_user(conn, user, logout_uri(), @now)

      salt1 = get_session(conn1, :logout_cookie_salt)
      salt2 = get_session(conn2, :logout_cookie_salt)

      assert is_binary(salt1)
      assert is_binary(salt2)
      # each session derives its own salt, so the value rotates per login
      refute salt1 == salt2
    end

    test "stores the auth time in the session", %{conn: conn, user: user} do
      last_auth_time = @now
      conn = UserAuth.log_in_user(conn, user, logout_uri(), last_auth_time)

      assert ^last_auth_time = get_session(conn, :last_auth_time)
    end

    test "clears everything previously stored in the session", %{conn: conn, user: user} do
      conn =
        conn
        |> put_session(:to_be_removed, "value")
        |> UserAuth.log_in_user(user, logout_uri(), @now)

      refute get_session(conn, :to_be_removed)
    end

    test "redirects to the configured path", %{conn: conn, user: user} do
      conn =
        conn
        |> put_session(:user_return_to, "/hello")
        |> UserAuth.log_in_user(user, logout_uri(), @now)

      assert redirected_to(conn) == "/hello"
      refute get_session(conn, :user_return_to)
    end
  end

  describe "logout_user/1" do
    test "erases the session", %{conn: conn, user: user} do
      conn =
        conn
        |> put_session(:user, user)
        |> fetch_flash()
        |> UserAuth.log_out_user()

      refute get_session(conn, :user)
      assert redirected_to(conn) == ~p"/"
    end

    test "broadcasts to the given live_socket_id", %{conn: conn, user: user} do
      live_socket_id = "users_sessions:#{user.keycloak_id}"
      AlertsUIWeb.Endpoint.subscribe(live_socket_id)

      conn
      |> put_session(:live_socket_id, live_socket_id)
      |> fetch_flash()
      |> UserAuth.log_out_user()

      assert_receive %Phoenix.Socket.Broadcast{event: "disconnect", topic: ^live_socket_id}
    end

    test "works even if user is already logged out", %{conn: conn} do
      conn =
        conn
        |> fetch_flash()
        |> UserAuth.log_out_user()

      refute get_session(conn, :user_token)
      assert redirected_to(conn) == ~p"/"
    end

    test "redirects to the logout URI carried by the logout cookie", %{conn: conn, user: user} do
      login_conn = UserAuth.log_in_user(conn, user, logout_uri(), @now)

      conn =
        conn
        |> Plug.Test.recycle_cookies(login_conn)
        # the real session cookie carries the per-session salt across requests;
        # init_test_session keeps the session out of band, so replay it here
        |> init_test_session(get_session(login_conn))
        |> fetch_flash()
        |> UserAuth.log_out_user()

      assert redirected_to(conn) == logout_uri()
      # the logout cookie is cleared on the way out
      assert conn.resp_cookies["_alerts_ui_logout"].max_age == 0
    end
  end

  describe "fetch_current_user/2" do
    test "authenticates user from session", %{conn: conn, user: user} do
      conn = put_session(conn, :user, user)

      conn = UserAuth.fetch_current_user(conn, [])

      assert conn.assigns.current_user == user
    end

    test "does not authenticate if data is missing", %{conn: conn} do
      conn = UserAuth.fetch_current_user(conn, [])

      refute get_session(conn, :user)
      refute conn.assigns.current_user
    end
  end

  describe "on_mount: mount_current_user" do
    test "assigns current_user based on a valid session user", %{conn: conn, user: user} do
      session = conn |> put_session(:user, user) |> get_session()

      {:cont, updated_socket} =
        UserAuth.on_mount(:mount_current_user, %{}, session, %LiveView.Socket{})

      assert updated_socket.assigns.current_user == user
    end

    test "assigns nil to current_user assign if there isn't a session user", %{conn: conn} do
      session = get_session(conn)

      {:cont, updated_socket} =
        UserAuth.on_mount(:mount_current_user, %{}, session, %LiveView.Socket{})

      assert updated_socket.assigns.current_user == nil
    end
  end

  describe "on_mount: ensure_authenticated" do
    test "authenticates current_user based on a valid session user", %{conn: conn, user: user} do
      session = conn |> put_session(:user, user) |> get_session()

      {:cont, updated_socket} =
        UserAuth.on_mount(:ensure_authenticated, %{}, session, %LiveView.Socket{})

      assert updated_socket.assigns.current_user == user
    end

    test "redirects to login page if there isn't a session session user", %{conn: conn} do
      session = get_session(conn)

      socket = %LiveView.Socket{
        endpoint: AlertsUIWeb.Endpoint,
        assigns: %{__changed__: %{}, flash: %{}}
      }

      {:halt, updated_socket} = UserAuth.on_mount(:ensure_authenticated, %{}, session, socket)
      assert updated_socket.assigns.current_user == nil
    end
  end

  describe "on_mount: :redirect_if_user_is_authenticated" do
    test "redirects if there is an authenticated, unexpired user ", %{conn: conn, user: user} do
      session = conn |> put_session(:user, user) |> get_session()

      assert {:halt, _updated_socket} =
               UserAuth.on_mount(
                 :redirect_if_user_is_authenticated,
                 %{},
                 session,
                 %LiveView.Socket{}
               )
    end

    test "doesn't redirect if there is no authenticated user", %{conn: conn} do
      session = get_session(conn)

      assert {:cont, _updated_socket} =
               UserAuth.on_mount(
                 :redirect_if_user_is_authenticated,
                 %{},
                 session,
                 %LiveView.Socket{}
               )
    end
  end

  describe "redirect_if_user_is_authenticated/2" do
    test "redirects if user is authenticated and unexpired", %{conn: conn, user: user} do
      conn =
        conn
        |> assign(:current_user, user)
        |> put_session(:last_auth_time, @now)
        |> put_session(:last_active, @now)
        |> UserAuth.redirect_if_user_is_authenticated([])

      assert conn.halted
      assert redirected_to(conn) == ~p"/"
    end

    test "does not redirect if user is not authenticated", %{conn: conn} do
      conn =
        conn
        |> put_session(:last_auth_time, @now)
        |> put_session(:last_active, @now)
        |> UserAuth.redirect_if_user_is_authenticated([])

      refute conn.halted
      refute conn.status
    end

    test "does not redirect if user's auth is expired", %{conn: conn, user: user} do
      conn =
        conn
        |> assign(:current_user, user)
        |> put_session(:last_auth_time, UserAuth.max_session_time() - 1)
        |> put_session(:last_active, @now)
        |> UserAuth.redirect_if_user_is_authenticated([])

      refute conn.halted
      refute conn.status
    end

    test "does not redirect if user has been idle", %{conn: conn, user: user} do
      conn =
        conn
        |> assign(:current_user, user)
        |> put_session(:last_auth_time, @now)
        |> put_session(:last_active, UserAuth.idle_time() - 1)
        |> UserAuth.redirect_if_user_is_authenticated([])

      refute conn.halted
      refute conn.status
    end
  end

  describe "require_authenticated_user/2" do
    test "redirects if user is not authenticated", %{conn: conn} do
      conn = conn |> fetch_flash() |> UserAuth.require_authenticated_user([])
      assert conn.halted

      assert redirected_to(conn) == ~p"/auth/keycloak"
    end

    test "stores the path to redirect to on GET", %{conn: conn} do
      halted_conn =
        %{conn | path_info: ["foo"], query_string: ""}
        |> fetch_flash()
        |> UserAuth.require_authenticated_user([])

      assert halted_conn.halted
      assert get_session(halted_conn, :user_return_to) == "/foo"

      halted_conn =
        %{conn | path_info: ["foo"], query_string: "bar=baz"}
        |> fetch_flash()
        |> UserAuth.require_authenticated_user([])

      assert halted_conn.halted
      assert get_session(halted_conn, :user_return_to) == "/foo?bar=baz"

      halted_conn =
        %{conn | path_info: ["foo"], query_string: "bar", method: "POST"}
        |> fetch_flash()
        |> UserAuth.require_authenticated_user([])

      assert halted_conn.halted
      refute get_session(halted_conn, :user_return_to)
    end

    test "does not redirect if user is authenticated and unexpired", %{conn: conn, user: user} do
      conn =
        conn
        |> assign(:current_user, user)
        |> put_session(:last_auth_time, @now)
        |> UserAuth.require_authenticated_user([])

      refute conn.halted
      refute conn.status
    end

    test "redirects if user auth is expired", %{conn: conn, user: user} do
      conn =
        conn
        |> assign(:current_user, user)
        |> put_session(:last_auth_time, UserAuth.max_session_time() - 1)
        |> UserAuth.require_authenticated_user([])

      assert conn.halted

      assert redirected_to(conn) == ~p"/auth/keycloak?prompt=login&login_hint=#{user.email}"
    end

    test "redirects if user has been idle", %{conn: conn, user: user} do
      conn =
        conn
        |> assign(:current_user, user)
        |> put_session(:last_active, UserAuth.idle_time() - 1)
        |> UserAuth.require_authenticated_user([])

      assert conn.halted

      assert redirected_to(conn) == ~p"/auth/keycloak?prompt=login&login_hint=#{user.email}"
    end
  end

  describe "require_authenticated_api_user/2" do
    setup do
      reassign_env(:ueberauth_oidcc, :providers, %{
        keycloak: %{
          client_id: "FAKE_KEYCLOAK_CLIENT_ID",
          client_secret: "FAKE_KEYCLOAK_CLIENT_SECRET"
        }
      })
    end

    test "responds with 401 unauthenticated if API user is not authenticated", %{conn: conn} do
      conn = UserAuth.require_authenticated_api_user(conn, [])

      assert %{"error" => "unauthenticated"} = json_response(conn, 401)
      assert conn.halted
    end

    test "responds with 403 unauthorized if API user is not authorized", %{conn: conn} do
      with_mocks([
        {ClientContext, [],
         from_configuration_worker: fn _provider, _client_id, _client_secret -> {:ok, %{}} end},
        {Token, [],
         validate_jwt: fn _token, _client_context, _opts ->
           {:ok, %{"resource_access" => %{}}}
         end}
      ]) do
        conn =
          conn
          |> Conn.put_req_header("authorization", "Bearer FAKE_TOKEN")
          |> UserAuth.require_authenticated_api_user([])

        assert %{"error" => "unauthorized"} = json_response(conn, 403)
        assert conn.halted
      end
    end

    test "does not send an 403 response if the API user is authenticated and authorized",
         %{conn: conn} do
      with_mocks([
        {ClientContext, [],
         from_configuration_worker: fn _provider, _client_id, _client_secret -> {:ok, %{}} end},
        {Token, [],
         validate_jwt: fn _token, _client_context, _opts ->
           {:ok,
            %{
              "resource_access" => %{
                "alerts-ui" => %{"roles" => ["api-writer"]}
              }
            }}
         end}
      ]) do
        conn =
          conn
          |> Conn.put_req_header("authorization", "Bearer FAKE_TOKEN")
          |> UserAuth.require_authenticated_api_user([])

        refute conn.status
      end
    end
  end

  describe "routes that require :author role" do
    @tag :logged_in_user
    test "author users can access the alert creation flow", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/alerts/new")
      assert html =~ "Creating New Alert"
    end

    @tag :logged_in_viewer
    test "non-author users cannot access alert creation flow", %{conn: conn} do
      {:error,
       {:redirect,
        %{to: "/", flash: %{"error" => "You don't have permission to access that page"}}}} =
        live(conn, "/alerts/new")
    end

    @tag :logged_in_user
    test "author users can access alert editing flow", %{conn: conn} do
      insert(:alert, alert_id: "1")
      {:ok, _view, html} = live(conn, "/alerts/edit/1")
      assert html =~ "Editing Alert"
    end

    @tag :logged_in_viewer
    test "non-author users cannot access alert editing flow", %{conn: conn} do
      {:error,
       {:redirect,
        %{to: "/", flash: %{"error" => "You don't have permission to access that page"}}}} =
        live(conn, "/alerts/edit/1")
    end
  end

  describe "routes that require :developer role" do
    @tag :logged_in_developer
    test "developer users can see the database view", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/db")
      # a button that only exists on the db view
      assert html =~ "Show informed entity"
    end

    @tag :logged_in_viewer
    test "non-developer users cannot see the database view", %{conn: conn} do
      {:error,
       {:redirect,
        %{to: "/", flash: %{"error" => "You don't have permission to access that page"}}}} =
        live(conn, "/db")
    end
  end

  describe "cannot visit any part of the app without :viewer role" do
    @tag :logged_in_user_no_roles
    test "user with no roles cannot access the app", %{conn: conn} do
      {:error, {:redirect, %{to: "/unauthorized"}}} = live(conn, "/")
    end
  end
end
