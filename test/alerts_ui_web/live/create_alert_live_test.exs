defmodule AlertsUIWeb.CreateAlertLiveTest do
  use ExUnit.Case
  use AlertsUIWeb.ConnCase
  import Phoenix.LiveViewTest

  describe "create alerts page" do
    test "connected mount displays a list of alerts when logged in", %{conn: conn} do
      conn = log_in_user(conn)

      {:ok, _view, html} = live(conn, "/alerts/new")
      assert html =~ ~r/Create an Alert/
    end

    test "redirects the user when not logged in", %{conn: conn} do
      assert live(conn, "/alerts/new") ==
               {:error, {:redirect, %{to: "/auth/keycloak", flash: %{}}}}
    end

    test "form can submit", %{conn: conn} do
      conn = log_in_user(conn)
      {:ok, view, _html} = live(conn, "/alerts/new")

      view
      |> element("#details_form")
      |> render_submit(%{
        "description_text" => "hello",
        "header_text" => "hi"
      }) =~ "Error"
    end
  end
end
