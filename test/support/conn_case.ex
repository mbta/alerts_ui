defmodule AlertsUIWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use AlertsUIWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # The default endpoint for testing
      @endpoint AlertsUIWeb.Endpoint

      use AlertsUIWeb, :verified_routes
      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import AlertsUIWeb.ConnCase
    end
  end

  setup tags do
    AlertsUI.DataCase.setup_sandbox(tags)

    conn = Phoenix.ConnTest.build_conn()

    conn =
      if tags[:logged_in_user] do
        log_in_user(conn)
      else
        conn
      end

    {:ok, conn: conn}
  end

  @doc """
  Logs the given `user` into the `conn`.

  If no user is provided, use the fixture data.

  It returns an updated `conn`.
  """
  def log_in_user(conn) do
    user = AlertsUI.AccountsFixtures.user_fixture()
    log_in_user(conn, user)
  end

  def log_in_user(conn, user) do
    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:user, user)
    |> Plug.Conn.put_session(:logout_uri, logout_uri())
  end

  def logout_uri, do: "http://oidc.example/end_session_uri"
end
