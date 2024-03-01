defmodule AlertsUIWeb.PutFlagsInAssignsHookTest do
  use AlertsUIWeb.ConnCase
  alias AlertsUIWeb.PutFlagsInAssignsHook
  alias Phoenix.LiveView

  describe "on_mount/4" do
    test "flag is false if it has not been set", %{conn: conn} do
      session =
        conn
        |> Plug.Test.init_test_session(%{})
        |> fetch_session()
        |> bypass_through(AlertsUIWeb.Router, :get_flags)
        |> get("/")
        |> get_session

      {:cont, updated_socket} =
        PutFlagsInAssignsHook.on_mount(:default, %{}, session, %LiveView.Socket{})

      assert updated_socket.assigns.test_flag == false
    end

    test "flag is true if it has been set", %{conn: conn} do
      session =
        conn
        |> put_resp_cookie("test_flag", "true")
        |> Plug.Test.init_test_session(%{})
        |> fetch_session()
        |> bypass_through(AlertsUIWeb.Router, :get_flags)
        |> get("/")
        |> get_session

      {:cont, updated_socket} =
        PutFlagsInAssignsHook.on_mount(:default, %{}, session, %LiveView.Socket{})

      assert updated_socket.assigns.test_flag == true
    end
  end
end
