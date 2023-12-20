defmodule AlertsUIWeb.AlertsLiveTest do
  use ExUnit.Case
  use AlertsUIWeb.ConnCase
  import Phoenix.LiveViewTest
  import AlertsUI.Support.Factory

  describe "alerts list page" do
    setup do
      insert(:alert, %{alert_id: "123"})
      :ok
    end

    test "connected mount", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/alerts")
      assert html =~ ~r/Alerts/
      assert html =~ ~r/123/
    end
  end
end
