defmodule AlertsUIWeb.AlertsLiveTest do
  use ExUnit.Case
  use AlertsUIWeb.ConnCase
  import Mock
  import Phoenix.LiveViewTest
  import AlertsUI.Support.Factory

  alias MBTAV3API.Routes.Repo, as: RoutesRepo

  describe "alerts list page" do
    setup do
      insert(:alert, %{
        alert_id: "123",
        active_period: [
          build(:active_period, %{start: ~U[2023-10-12 00:01:00Z]}),
          build(:active_period, %{start: ~U[2023-10-13 00:01:00Z]})
        ],
        header_text: "this is the first alert",
        effect_detail: "DETOUR",
        original_route_selections: ["1", "2"]
      })

      insert(:alert, %{
        alert_id: "234",
        active_period: [
          build(:active_period, %{start: ~U[2023-11-12 00:01:00Z]}),
          build(:active_period, %{start: ~U[2023-11-13 00:01:00Z]})
        ],
        header_text: "this is the second alert",
        effect_detail: "SUMMARY",
        original_route_selections: []
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

  describe "route pills" do
    @tag :logged_in_user
    test "a subway alert shows the correct route pill", %{conn: conn} do
      insert(:alert, %{
        alert_id: "123",
        active_period: [
          build(:active_period, %{start: ~U[2023-11-12 00:01:00Z]}),
          build(:active_period, %{start: ~U[2023-11-13 00:01:00Z]})
        ],
        header_text: "here's a subway delay alert",
        effect_detail: "DELAY",
        original_route_selections: ["Orange"]
      })

      {:ok, _view, html} = live(conn, "/alerts")

      assert html =~ "Orange Line"
    end

    @tag :logged_in_user
    test "up to four bus routes can be displayed without collapsing the number", %{conn: conn} do
      insert(:alert, %{
        alert_id: "123",
        active_period: [
          build(:active_period, %{start: ~U[2023-11-12 00:01:00Z]}),
          build(:active_period, %{start: ~U[2023-11-13 00:01:00Z]})
        ],
        header_text: "here's a bus delay alert",
        effect_detail: "DELAY",
        original_route_selections: ["111", "222", "333", "444"]
      })

      {:ok, _view, html} = live(conn, "/alerts")

      assert html =~ "111"
      assert html =~ "222"
      assert html =~ "333"
      assert html =~ "444"
      refute html =~ "+"
    end

    @tag :logged_in_user
    test "five or more routes will be collapsed", %{conn: conn} do
      insert(:alert, %{
        alert_id: "123",
        active_period: [
          build(:active_period, %{start: ~U[2023-11-12 00:01:00Z]}),
          build(:active_period, %{start: ~U[2023-11-13 00:01:00Z]})
        ],
        header_text: "here's a bus delay alert",
        effect_detail: "DELAY",
        original_route_selections: ["111", "222", "333", "444", "555"]
      })

      {:ok, _view, html} = live(conn, "/alerts")

      assert html =~ "111"
      assert html =~ "222"
      assert html =~ "333"
      assert html =~ "444"
      refute html =~ "555"
      assert html =~ "+1"
    end

    @tag :logged_in_user
    test "SLW is represented by 1 SL route pill instead of by bus number or multiple pills", %{
      conn: conn
    } do
      with_mock(RoutesRepo,
        get: fn
          "746" -> %{name: "SLW"}
        end
      ) do
        insert(:alert, %{
          alert_id: "123",
          active_period: [
            build(:active_period, %{start: ~U[2023-11-12 00:01:00Z]}),
            build(:active_period, %{start: ~U[2023-11-13 00:01:00Z]})
          ],
          header_text: "here's a SL delay alert",
          effect_detail: "DELAY",
          original_route_selections: ["746"]
        })

        {:ok, _view, html} = live(conn, "/alerts")

        assert html =~ "SLW"
        refute html =~ "SL1"
      end
    end

    @tag :logged_in_user
    test "elevator, bike, and other facility issues receive the facility pill", %{conn: conn} do
      insert(:alert, %{
        alert_id: "123",
        active_period: [
          build(:active_period, %{start: ~U[2023-11-12 00:01:00Z]}),
          build(:active_period, %{start: ~U[2023-11-13 00:01:00Z]})
        ],
        header_text: "here's a bike issue alert",
        effect_detail: "BIKE_ISSUE",
        original_route_selections: []
      })

      {:ok, _view, html} = live(conn, "/alerts")

      assert html =~ "Facility"
    end

    @tag :logged_in_user
    test "systemwide alert shows the systemwide pill", %{conn: conn} do
      insert(:alert, %{
        alert_id: "123",
        active_period: [
          build(:active_period, %{start: ~U[2023-11-12 00:01:00Z]}),
          build(:active_period, %{start: ~U[2023-11-13 00:01:00Z]})
        ],
        header_text: "here's a delay alert for all ferries",
        effect_detail: "DELAY",
        original_route_selections: []
      })

      {:ok, _view, html} = live(conn, "/alerts")

      assert html =~ "Systemwide"
    end

    @tag :logged_in_user
    test "commuter rail pill shows proper full name without CR appended", %{conn: conn} do
      with_mock(RoutesRepo,
        get: fn
          "CR-Framingham" -> %{long_name: "Framingham/Worcester"}
        end
      ) do
        insert(:alert, %{
          alert_id: "123",
          active_period: [
            build(:active_period, %{start: ~U[2023-11-12 00:01:00Z]}),
            build(:active_period, %{start: ~U[2023-11-13 00:01:00Z]})
          ],
          header_text: "here's a CR delay alert",
          effect_detail: "DELAY",
          original_route_selections: ["CR-Framingham"]
        })

        {:ok, _view, html} = live(conn, "/alerts")

        assert html =~ "Framingham/Worcester"
      end
    end

    @tag :logged_in_user
    test "ferry pill shows proper full name", %{conn: conn} do
      with_mock(RoutesRepo,
        get: fn
          "Boat-F4" -> %{long_name: "Charlestown"}
        end
      ) do
        insert(:alert, %{
          alert_id: "123",
          active_period: [
            build(:active_period, %{start: ~U[2023-11-12 00:01:00Z]}),
            build(:active_period, %{start: ~U[2023-11-13 00:01:00Z]})
          ],
          header_text: "here's a CR delay alert",
          effect_detail: "DELAY",
          original_route_selections: ["Boat-F4"]
        })

        {:ok, _view, html} = live(conn, "/alerts")

        assert html =~ "Charlestown"
      end
    end
  end

  describe "view alerts page columns" do
    setup do
      insert(:alert, %{
        alert_id: "123",
        active_period: [
          build(:active_period, %{start: ~U[2023-10-12 00:01:00Z]}),
          build(:active_period, %{start: ~U[2023-10-13 00:01:00Z]})
        ],
        header_text: "this is the first alert",
        effect_detail: "DETOUR",
        original_route_selections: ["1", "2"],
        closed_timestamp: ~U[2024-10-12 00:01:00Z]
      })

      insert(:alert, %{
        alert_id: "234",
        active_period: [
          build(:active_period, %{start: ~U[2023-11-12 00:01:00Z]}),
          build(:active_period, %{start: ~U[2023-11-13 00:01:00Z]})
        ],
        header_text: "this is the second alert",
        effect_detail: "SUMMARY",
        original_route_selections: [],
        closed_timestamp: ~U[2024-10-12 00:01:00Z]
      })

      :ok
    end

    @tag :logged_in_user
    test "effect display", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/alerts")
      assert html =~ "Detour"
      assert html =~ "Summary"
    end

    @tag :logged_in_user
    test "actions display for closed alerts", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/alerts")

      refute html =~ ~s(<span class="hero-pencil-solid w-4 h-4"></span>)
      refute html =~ ~s(<span class="hero-x-mark-solid w-4 h-4"></span>)
      assert html =~ ~s(<span class="hero-ellipsis-vertical w-4 h-4"></span>)
    end

    @tag :logged_in_user
    test "actions display for open alerts", %{conn: conn} do
      insert(:alert, %{
        alert_id: "345",
        active_period: [
          build(:active_period, %{start: ~U[2023-10-12 00:01:00Z]}),
          build(:active_period, %{start: ~U[2023-10-13 00:01:00Z]})
        ],
        header_text: "this is the third alert",
        effect_detail: "DETOUR",
        original_route_selections: ["1", "2"]
      })

      {:ok, _view, html} = live(conn, "/alerts")

      assert html =~ ~s(<span class="hero-pencil-solid w-4 h-4"></span>)
      assert html =~ ~s(<span class="hero-x-mark-solid w-4 h-4"></span>)
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
