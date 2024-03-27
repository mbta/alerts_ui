defmodule AlertsUIWeb.ValidateLiveTest do
  use AlertsUIWeb.ConnCase
  import Phoenix.LiveViewTest

  describe "ValidateLive" do
    @tag :logged_in_user
    test "connected mount displays a list of alerts when logged in", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/validate")
      assert html =~ ~r/Validate Alert Feeds/
    end

    @tag :logged_in_user
    test "handles a search for an IBI alert ID", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/validate")

      assert view |> element("#ibi-json") |> has_element?()
      refute view |> element("#ibi-data") |> has_element?()

      assert render_change(view, "search", %{"ibi_alert_id" => "1"})
    end

    @tag :logged_in_user
    test "handles a search for a dev-orange alert ID", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/validate")

      assert view |> element("#dev-orange-json") |> has_element?()
      refute view |> element("#dev-orange-data") |> has_element?()

      assert render_change(view, "search", %{"dev_orange_alert_id" => "1"})
    end
  end
end
