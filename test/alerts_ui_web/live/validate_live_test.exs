defmodule AlertsUIWeb.ValidateLiveTest do
  @moduledoc false
  use AlertsUIWeb.ConnCase
  import Phoenix.LiveViewTest
  import Test.Support.Helpers

  describe "ValidateLive" do
    setup do
      reassign_env(:alerts_ui, :get_http_fn, fn _ ->
        %{status: 200, body: Jason.encode!(%{"entity" => []})}
      end)

      reassign_env(:alerts_ui, :get_obj_fn, fn _, _ ->
        %{status_code: 200, body: Jason.encode!(%{"entity" => []})}
      end)

      reassign_env(:alerts_ui, :make_request_fn, fn _ ->
        %{status_code: 200, body: Jason.encode!(%{"entity" => []})}
      end)
    end

    @tag :logged_in_developer
    test "connected mount displays a list of alerts when logged in", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/validate")
      assert html =~ ~r/Validate Alert Feeds/
    end

    @tag :logged_in_developer
    test "handles a search for an IBI alert ID", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/validate")

      assert view |> element("#ibi-json") |> has_element?()
      refute view |> element("#ibi-data") |> has_element?()

      assert render_change(view, "search", %{"ibi_alert_id" => "1"})
    end

    @tag :logged_in_developer
    test "handles a search for a dev-orange alert ID", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/validate")

      assert view |> element("#dev-orange-json") |> has_element?()
      refute view |> element("#dev-orange-data") |> has_element?()

      assert render_change(view, "search", %{"dev_orange_alert_id" => "1"})
    end
  end
end
