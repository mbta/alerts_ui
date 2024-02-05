defmodule AlertsUIWeb.AlertsLiveTest do
  use ExUnit.Case
  use AlertsUIWeb.ConnCase
  import Phoenix.LiveViewTest
  import AlertsUI.Support.Factory

  describe "alerts list page" do
    setup do
      insert(:alert, %{
        alert_id: "123",
        active_period: [
          build(:active_period, %{start: ~U[2023-10-12 00:01:00Z]}),
          build(:active_period, %{start: ~U[2023-10-13 00:01:00Z]})
        ],
        header_text: "this is the first alert",
        effect_detail: "DETOUR"
      })

      insert(:alert, %{
        alert_id: "234",
        active_period: [
          build(:active_period, %{start: ~U[2023-11-12 00:01:00Z]}),
          build(:active_period, %{start: ~U[2023-11-13 00:01:00Z]})
        ],
        header_text: "this is the second alert",
        effect_detail: "SUMMARY"
      })

      :ok
    end

    @tag :logged_in_user
    test "connected mount displays a list of alerts when logged in", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/alerts")
      assert html =~ ~r/Alerts/
    end

    test "redirects the user when not logged in", %{conn: conn} do
      assert live(conn, "/alerts") == {:error, {:redirect, %{to: "/auth/keycloak", flash: %{}}}}
    end

    @tag :logged_in_user
    test "sorting click event", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts")
      assert view |> render_click("sort-alerts", %{"order" => "active_period_start"}) =~ "123"
    end

    @tag :logged_in_user
    test "alert_id filter change", %{conn: conn} do
      {:ok, view, html} = live(conn, "/alerts")

      assert html =~ "123"
      assert render_change(view, "update-filter", alert_id_filter_params("")) =~ "123"
      assert render_change(view, "update-filter", alert_id_filter_params("123")) =~ "123"
      refute render_change(view, "update-filter", alert_id_filter_params("124")) =~ "123"
    end

    @tag :logged_in_user
    test "effect filter change", %{conn: conn} do
      {:ok, view, html} = live(conn, "/alerts")

      assert html =~ "123"
      assert render_change(view, "update-filter", effect_filter_params("")) =~ "123"
      assert render_change(view, "update-filter", effect_filter_params("")) =~ "234"
      refute render_change(view, "update-filter", effect_filter_params("SUMMARY")) =~ "123"
      assert render_change(view, "update-filter", effect_filter_params("SUMMARY")) =~ "234"
      refute render_change(view, "update-filter", effect_filter_params("DETOUR")) =~ "234"
      assert render_change(view, "update-filter", effect_filter_params("DETOUR")) =~ "123"
    end

    @tag :logged_in_user
    test "filter reset", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts")

      assert render_change(view, "update-filter", alert_id_filter_params("")) =~ "123"
      refute render_change(view, "update-filter", alert_id_filter_params("124")) =~ "123"

      assert render_change(view, "update-filter", %{
               "filters" => %{
                 "0" => %{"field" => "alert_id", "op" => "ilike_and", "value" => "124"},
                 "1" => %{"field" => "effect_detail", "value" => ""}
               },
               "reset" => ""
             }) =~ "123"
    end
  end

  defp alert_id_filter_params(search_string) do
    %{
      "_target" => ["filters", "0", "value"],
      "filters" => %{
        "0" => %{"field" => "alert_id", "op" => "ilike_and", "value" => search_string}
      }
    }
  end

  defp effect_filter_params(search_string) do
    %{
      "_target" => ["filters", "0", "value"],
      "filters" => %{
        "0" => %{"field" => "alert_id", "op" => "ilike_and", "value" => ""},
        "1" => %{"field" => "effect_detail", "value" => search_string}
      }
    }
  end
end
