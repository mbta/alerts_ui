defmodule AlertsUIWeb.ViewAlertsLiveTest do
  use ExUnit.Case
  use AlertsUIWeb.ConnCase

  import AlertsUI.Support.Factory
  import Mock
  import Phoenix.LiveViewTest
  import Test.Support.Helpers
  import ExUnit.CaptureLog

  alias AlertsUI.Alerts
  alias AlertsUI.Models.ActivePeriod
  alias AlertsUI.Models.Alert
  alias AlertsUI.Repo
  alias MBTAV3API.RoutePatterns.Repo, as: RoutePatternsRepo
  alias MBTAV3API.Routes.Repo, as: RoutesRepo
  alias MBTAV3API.Routes.Route
  alias MBTAV3API.Schedules.Repo, as: SchedulesRepo
  alias MBTAV3API.Stops.Repo, as: StopsRepo
  alias MBTAV3API.Stops.Stop

  @now DateTime.utc_now()
  @one_day_ago DateTime.add(@now, -1, :day)
  @two_days_ago DateTime.add(@now, -2, :day)
  @three_days_ago DateTime.add(@now, -3, :day)
  @six_hours_ago DateTime.add(@now, -6, :hour)
  @two_hours_ago DateTime.add(@now, -2, :hour)
  @one_hour_from_now DateTime.add(@now, 1, :hour)
  @two_hours_from_now DateTime.add(@now, 2, :hour)
  @end_of_service_utc ActivePeriod.end_of_service_datetime_utc(@now)
  @one_day_from_now DateTime.add(@now, 1, :day)
  @two_days_from_now DateTime.add(@now, 2, :day)

  @alert_1 %{
    alert_id: "123",
    active_period: [
      build(:active_period, %{start: ~U[2023-10-12 00:01:00Z]}),
      build(:active_period, %{start: ~U[2023-10-13 00:01:00Z]})
    ],
    active_period_start: ~U[2023-10-12 00:01:00Z],
    header_text: "this is the first alert",
    effect_detail: "DETOUR",
    original_route_selections: ["1", "2"],
    duration_certainty: :UNKNOWN,
    severity: 4,
    last_push_notification_timestamp: @one_day_ago
  }

  describe "alerts list page" do
    setup do
      insert(:alert, @alert_1)

      insert(:alert, %{
        alert_id: "234",
        active_period: [
          build(:active_period, %{start: ~U[2023-11-12 00:01:00Z]}),
          build(:active_period, %{start: ~U[2023-11-13 00:01:00Z]})
        ],
        active_period_start: ~U[2023-11-12 00:01:00Z],
        header_text: "this is the second alert",
        effect_detail: "SUMMARY",
        original_route_selections: [],
        duration_certainty: :UNKNOWN
      })

      :ok
    end

    @tag :logged_in_user
    test "connected mount displays a list of alerts when logged in", %{conn: conn} do
      with_mock(RoutesRepo, [],
        all: fn -> [] end,
        get: fn route_id -> %{name: route_id} end
      ) do
        {:ok, _view, html} = live(conn, "/alerts")
        assert html =~ ~r/Alerts/
      end
    end

    test "redirects the user when not logged in", %{conn: conn} do
      assert live(conn, "/alerts") == {:error, {:redirect, %{to: "/auth/keycloak", flash: %{}}}}
    end

    @tag :logged_in_user
    test "sorting click event", %{conn: conn} do
      with_mock(RoutesRepo, [],
        all: fn -> [] end,
        get: fn route_id -> %{name: route_id} end
      ) do
        {:ok, view, _html} = live(conn, "/alerts")
        assert view |> render_click("sort-alerts", %{"order" => "active_period_start"}) =~ "123"
      end
    end

    @tag :logged_in_user
    test "create button exists for authors", %{conn: conn} do
      with_mock(RoutesRepo, [],
        all: fn -> [] end,
        get: fn route_id -> %{name: route_id} end
      ) do
        {:ok, view, _html} = live(conn, "/alerts")
        assert view |> has_element?("span", "Create new alert")
      end
    end

    @tag :logged_in_viewer
    test "create button doesn't exists for non-authors", %{conn: conn} do
      with_mock(RoutesRepo, [],
        all: fn -> [] end,
        get: fn route_id -> %{name: route_id} end
      ) do
        {:ok, view, _html} = live(conn, "/alerts")
        refute view |> has_element?("span", "Create new alert")
      end
    end

    @tag :logged_in_user
    test "can render even with bad data", %{conn: conn} do
      with_mock(RoutesRepo, [],
        all: fn -> [] end,
        get: fn route_id -> %{name: route_id} end
      ) do
        insert(:alert, %{
          alert_id: "345",
          active_period: [
            build(:active_period, %{
              start: ~U[2023-10-12 00:01:00Z],
              end: nil
            })
          ],
          active_period_start: ~U[2023-10-12 00:01:00Z],
          header_text: "this is a malformed alert",
          effect_detail: "SUMMARY",
          original_route_selections: [],
          duration_certainty: :KNOWN
        })

        log =
          capture_log(fn ->
            {:ok, _view, html} = live(conn, "/alerts")
            assert html =~ ~r/Alerts/
          end)

        assert log =~ "Error formatting end time"
      end
    end

    @tag :logged_in_user
    test "a valid alert_id param shows the details modal with route type and effect name",
         %{conn: conn} do
      alert =
        insert(:alert, %{
          alert_id: "999",
          header_text: "modal rendering test alert",
          active_period_start: ~U[2023-10-12 00:01:00Z],
          closed_timestamp: ~U[2024-10-12 00:01:00Z],
          severity: 4
        })

      {:ok, view, _html} = live(conn, "/alerts?alert_id=#{alert.alert_id}")

      html = render_async(view)
      assert html =~ "Subway"
      assert html =~ "Station Closure"
    end

    @tag :logged_in_user
    test "an alert_id param for a nonexistent alert goes back to view alerts page",
         %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts?alert_id=999")

      html = render_async(view)
      assert html =~ ~r/Alerts/
    end

    @tag :logged_in_user
    test "all clear notification checkbox initializes properly", %{conn: conn} do
      with_mock(RoutesRepo, [],
        all: fn -> [] end,
        get: fn route_id -> %{name: route_id} end
      ) do
        {:ok, view, _html} = live(conn, "/alerts")

        assert has_element?(view, "#all-clear-checkbox-close-alert-modal-123[checked]")
        assert has_element?(view, "#all-clear-checkbox-close-alert-modal-234")
        refute has_element?(view, "#all-clear-checkbox-close-alert-modal-234[checked]")
      end
    end

    @tag :logged_in_user
    test "can turn on 'all clear notification' checkbox", %{conn: conn} do
      with_mock(RoutesRepo, [],
        all: fn -> [] end,
        get: fn route_id -> %{name: route_id} end
      ) do
        {:ok, view, _html} = live(conn, "/alerts")
        original_alert = Alerts.get_by_alert_id("234")
        assert is_nil(original_alert.last_push_notification_timestamp)
        assert has_element?(view, "td", "this is the second alert")
        all_clear = element(view, "#all-clear-checkbox-close-alert-modal-234")

        render_click(all_clear)

        element(view, "#close-alert-modal-234-container button", "Close now") |> render_click()
        refute has_element?(view, "td", "this is the second alert")

        alert = Alerts.get_by_alert_id("234")
        assert not is_nil(alert.last_push_notification_timestamp)
      end
    end

    @tag :logged_in_user
    test "can turn off 'all clear notification' checkbox", %{conn: conn} do
      with_mock(RoutesRepo, [],
        all: fn -> [] end,
        get: fn route_id -> %{name: route_id} end
      ) do
        {:ok, view, _html} = live(conn, "/alerts")
        original_alert = Alerts.get_by_alert_id("123")
        last_push = original_alert.last_push_notification_timestamp
        all_clear = element(view, "#all-clear-checkbox-close-alert-modal-123")

        render_click(all_clear, %{value: false})

        element(view, "#close-alert-modal-123-container button", "Close now") |> render_click()
        refute has_element?(view, "td", "this is the first alert")

        alert = Alerts.get_by_alert_id("123")
        new_last_push = alert.last_push_notification_timestamp
        assert last_push == new_last_push
      end
    end
  end

  describe "filtering" do
    @tag :logged_in_user
    test "multi-column filter change with alert id", %{conn: conn} do
      insert(:alert, %{
        alert_id: "899",
        original_route_selections: ["Orange"]
      })

      insert(:alert, %{
        alert_id: "999",
        original_route_selections: ["Orange"]
      })

      {:ok, _view, html} = live(conn, "/alerts?filter[timeline]=all")
      assert html =~ "899"
      assert html =~ "999"

      {:ok, _view, html} =
        live(
          conn,
          "/alerts?filter[timeline]=all&filter[multi_column_search]=899"
        )

      assert html =~ "899"
      refute html =~ "999"

      {:ok, _view, html} =
        live(
          conn,
          "/alerts?filter[timeline]all&filter[multi_column_search]=999"
        )

      refute html =~ "899"
      assert html =~ "999"
    end

    @tag :logged_in_user
    test "multi-column filter change with header text", %{conn: conn} do
      insert(:alert, %{
        alert_id: "899",
        original_route_selections: ["Orange"],
        header_text: "problem with Framingham/Worcester line today"
      })

      insert(:alert, %{
        alert_id: "999",
        original_route_selections: ["Orange"],
        header_text: "problem with Franklin/Foxboro line today"
      })

      {:ok, _view, html} = live(conn, "/alerts?filter[timeline]=all")
      assert html =~ "899"
      assert html =~ "999"

      {:ok, _view, html} =
        live(
          conn,
          "/alerts?filter[timeline]=all&filter[multi_column_search]=framingham line"
        )

      assert html =~ "899"
      refute html =~ "999"

      {:ok, _view, html} =
        live(
          conn,
          "/alerts?filter[timeline]=all&filter[multi_column_search]=foxboro line"
        )

      refute html =~ "899"
      assert html =~ "999"
    end

    @tag :logged_in_user
    test "route filter gets optiopns from the API, sorted  (+ 'Green Line')", %{conn: conn} do
      with_mock(RoutesRepo,
        all: fn ->
          [
            build(:route, %{type: 1, name: "Red Line", id: "Red"}),
            build(:route, %{type: 3, name: "62", id: "62"}),
            build(:route, %{type: 3, name: "67", id: "67"}),
            build(:route, %{type: 3, name: "76", id: "76"}),
            build(:route, %{type: 2, name: "Fitchburg Line", id: "CR-Fitchburg"}),
            build(:route, %{type: 0, name: "Green Line-C", id: "Green-C"}),
            build(:route, %{type: 3, name: "350", id: "350"}),
            build(:route, %{type: 3, name: "CT3", id: "708"})
          ]
        end
      ) do
        {:ok, _view, html} = live(conn, "/alerts")

        {:ok, document} = Floki.parse_document(html)

        {_, _, children_nodes} = Floki.get_by_id(document, "view_alerts_live_routes")

        assert [
                 {"option", [{"value", "default"}, {"selected", ""}], ["\n      All\n    "]},
                 {"option", [{"id", "route-filter-Green"}, {"value", "Green"}], ["Green Line"]},
                 {"option", [{"id", "route-filter-Green-C"}, {"value", "Green-C"}],
                  ["Green Line-C"]},
                 {"option", [{"id", "route-filter-Red"}, {"value", "Red"}], ["Red Line"]},
                 {"option", [{"id", "route-filter-CR-Fitchburg"}, {"value", "CR-Fitchburg"}],
                  ["Fitchburg Line"]},
                 {"option", [{"id", "route-filter-708"}, {"value", "708"}], ["CT3"]},
                 {"option", [{"id", "route-filter-62"}, {"value", "62"}], ["62"]},
                 {"option", [{"id", "route-filter-67"}, {"value", "67"}], ["67"]},
                 {"option", [{"id", "route-filter-76"}, {"value", "76"}], ["76"]},
                 {"option", [{"id", "route-filter-350"}, {"value", "350"}], ["350"]}
               ] = children_nodes
      end
    end

    @tag :logged_in_user
    test "filtering by route uses OR", %{conn: conn} do
      # Alert with the new route format
      insert(:alert, %{
        alert_id: "899999",
        original_route_selections: [
          "Red Line|Red",
          "62|62",
          "67|67",
          "76|76",
          "350|350",
          "CT3|708"
        ],
        informed_entity: [
          build(:informed_entity, %{route_id: "Red", route_type: 1}),
          build(:informed_entity, %{route_id: "62", route_type: 3}),
          build(:informed_entity, %{route_id: "67", route_type: 3}),
          build(:informed_entity, %{route_id: "76", route_type: 3}),
          build(:informed_entity, %{route_id: "350", route_type: 3}),
          build(:informed_entity, %{route_id: "708", route_type: 3})
        ]
      })

      # Alert in the old format
      insert(:alert, %{
        alert_id: "999999",
        original_route_selections: ["CR-Fitchburg"],
        informed_entity: [
          build(:informed_entity, %{route_id: "CR-Fitchburg", route_type: 2})
        ]
      })

      {:ok, _view, html} = live(conn, "/alerts?filter[routes][]=708")
      assert html =~ "899999"
      refute html =~ "999999"

      {:ok, _view, html} = live(conn, "/alerts?filter[routes][]=CR-Fitchburg")
      refute html =~ "899999"
      assert html =~ "999999"

      {:ok, _view, html} =
        live(conn, "/alerts?filter[routes][]=Red&filter[routes][]=CR-Fitchburg")

      assert html =~ "899999"
      assert html =~ "999999"

      # No substring matching on bus routes!
      {:ok, _view, html} = live(conn, "/alerts?filter[routes][]=6")
      refute html =~ "899999"
      refute html =~ "999999"
    end

    @tag :logged_in_user
    test "filtering by route handles Green Line", %{conn: conn} do
      insert(:alert, %{
        alert_id: "799999",
        original_route_selections: [
          "Green Line|Green",
          "Red Line|Red"
        ],
        informed_entity: [
          build(:informed_entity, %{route_id: "Red", route_type: 1}),
          build(:informed_entity, %{route_id: "Green", route_type: 1}),
          # Toss in Green-B just to prove that this field is not getting queried
          build(:informed_entity, %{route_id: "Green-B", route_type: 1})
        ]
      })

      insert(:alert, %{
        alert_id: "899999",
        original_route_selections: [
          "Green Line|Green"
        ],
        informed_entity: [
          build(:informed_entity, %{route_id: "Green", route_type: 1})
        ]
      })

      insert(:alert, %{
        alert_id: "999999",
        original_route_selections: [
          "Green Line B|Green-B"
        ],
        informed_entity: [
          build(:informed_entity, %{route_id: "Green-B", route_type: 1})
        ]
      })

      {:ok, _view, html} = live(conn, "/alerts?filter[routes][]=Green")
      assert html =~ "799999"
      assert html =~ "899999"
      assert html =~ "999999"

      {:ok, _view, html} = live(conn, "/alerts?filter[routes][]=Green-B")
      refute html =~ "799999"
      refute html =~ "899999"
      assert html =~ "999999"

      {:ok, _view, html} = live(conn, "/alerts?filter[routes][]=Green-C")
      refute html =~ "799999"
      refute html =~ "899999"
      refute html =~ "999999"
    end

    @tag :logged_in_user
    test "filter by effect works", %{conn: conn} do
      insert(:alert, %{
        alert_id: "799999",
        effect_name: "Multi-Route Detour"
      })

      insert(:alert, %{
        alert_id: "899999",
        effect_name: "Detour"
      })

      {:ok, _view, html} = live(conn, "/alerts?filter[effects][]=Multi-Route+Detour")
      assert html =~ "799999"
      refute html =~ "899999"

      {:ok, _view, html} = live(conn, "/alerts?filter[effects][]=Detour")
      refute html =~ "799999"
      assert html =~ "899999"
    end

    @tag :logged_in_user
    test "text search and the modal filters have oneoff resets", %{conn: conn} do
      insert(:alert, %{
        alert_id: "899",
        original_route_selections: ["Orange"]
      })

      insert(:alert, %{
        alert_id: "999",
        original_route_selections: ["Orange"]
      })

      {:ok, _view, html} = live(conn, "/alerts?filter[timeline]=all")
      assert html =~ "899"
      assert html =~ "999"

      {:ok, _view, html} =
        live(
          conn,
          "/alerts?filter[timeline]=all&filter[multi_column_search]=899"
        )

      assert html =~ "899"
      refute html =~ "999"

      {:ok, _view, html} =
        live(
          conn,
          "/alerts?filter[timeline]all&filter[multi_column_search]=999"
        )

      refute html =~ "899"
      assert html =~ "999"
    end

    @tag :logged_in_user
    test "text filtering shows a reset button that affects no other filters", %{conn: conn} do
      {:ok, view, _html} =
        live(
          conn,
          "/alerts?filter[routes][]=abcd&filter[timeline]=past&filter[multi_column_search]=foobarbaz"
        )

      {:ok, _document} =
        render_click(view, "reset_text_filter", %{
          "name" => "view_alerts_live[multi_column_search]"
        })
        |> Floki.parse_document()

      assert_patch view, ~p"/alerts?filter[routes][]=abcd&filter[timeline]=past"
    end

    @tag :logged_in_user
    test "selecing route shows a reset button that affects no other filters", %{conn: conn} do
      {:ok, view, _html} =
        live(
          conn,
          "/alerts?filter[routes][]=abcd&filter[timeline]=past&filter[multi_column_search]=foobarbaz"
        )

      reset_modal_filters =
        element(view, "#filter-modal-Filters span:has(span.hero-x-circle-solid)")

      assert reset_modal_filters

      reset_modal_filters |> render_click()
      assert_patch view, ~p"/alerts?filter[multi_column_search]=foobarbaz&filter[timeline]=past"
    end

    @tag :logged_in_user
    test "can clear search bars in the filter modal independently", %{conn: conn} do
      {:ok, view, _html} =
        live(conn, "/alerts")

      view
      |> render_async()
      |> Floki.parse_document()

      # Service type
      assert has_element?(view, "option", "Bus")
      # Route
      assert has_element?(view, "option", "Green Line")
      # Effect
      assert has_element?(view, "option", "Access Issue")

      view
      |> element("form")
      |> render_change(%{
        "view_alerts_live" => %{
          "service_type_search_term" => "q",
          "routes_search_term" => "q",
          "effects_search_term" => "q"
        }
      })

      refute has_element?(view, "option", "Bus")
      refute has_element?(view, "option", "Green Line")
      refute has_element?(view, "option", "Access Issue")

      {:ok, document} =
        render_click(view, "reset_search_filter", %{
          "name" => "view_alerts_live[service_type_search_term]"
        })
        |> Floki.parse_document()

      # Confirm the trip search input cleared
      assert document_has_element?(
               document,
               "input#view_alerts_live_service_type_search_term[value=\"\"]"
             )

      # And that the 'Bus' option is back
      assert has_element?(view, "option", "Bus")

      # But Route and Effect should be unaffected
      refute has_element?(view, "option", "Green Line")
      refute has_element?(view, "option", "Access Issue")

      # Now clear Route
      {:ok, document} =
        render_click(view, "reset_search_filter", %{
          "name" => "view_alerts_live[routes_search_term]"
        })
        |> Floki.parse_document()

      assert document_has_element?(
               document,
               "input#view_alerts_live_routes_search_term[value=\"\"]"
             )

      # Bus and Route should be reset, Effect should still be filtered
      assert has_element?(view, "option", "Bus")
      assert has_element?(view, "option", "Green Line")
      refute has_element?(view, "option", "Access Issue")

      # Finally, clear Effects, and everything should be reset
      {:ok, document} =
        render_click(view, "reset_search_filter", %{
          "name" => "view_alerts_live[effects_search_term]"
        })
        |> Floki.parse_document()

      assert document_has_element?(
               document,
               "input#view_alerts_live_effects_search_term[value=\"\"]"
             )

      assert has_element?(view, "option", "Bus")
      assert has_element?(view, "option", "Green Line")
      assert has_element?(view, "option", "Access Issue")
    end
  end

  describe "alerts list timeline filtering and sorting" do
    setup do
      insert(:alert, %{
        alert_id: "10000",
        active_period_start: @six_hours_ago,
        notification_period_start: @six_hours_ago,
        active_period_end: nil,
        notification_period_end: nil,
        duration_certainty: :UNKNOWN,
        informed_entity: []
      })

      insert(:alert, %{
        alert_id: "10100",
        active_period_start: @one_day_ago,
        notification_period_start: @one_day_ago,
        active_period_end: nil,
        notification_period_end: nil,
        duration_certainty: :UNKNOWN,
        original_route_selections: [
          "Red Line|Red",
          "62|62",
          "67|67",
          "76|76",
          "350|350",
          "CT3|708"
        ],
        header_text: "Problems on the red line and some buses",
        primary_service_type: "3"
      })

      insert(:alert, %{
        alert_id: "10200",
        active_period_start: @one_hour_from_now,
        notification_period_start: @one_hour_from_now,
        active_period_end: @two_hours_from_now,
        notification_period_end: @two_hours_from_now,
        duration_certainty: :ESTIMATED
      })

      insert(:alert, %{
        alert_id: "10300",
        active_period_start: @six_hours_ago,
        notification_period_start: @six_hours_ago,
        active_period_end: @one_hour_from_now,
        notification_period_end: @one_hour_from_now,
        duration_certainty: :KNOWN,
        original_route_selections: ["Red Line|Red"],
        header_text: "Problems on the red line"
      })

      insert(:alert, %{
        alert_id: "10400",
        active_period_start: @one_hour_from_now,
        notification_period_start: @one_hour_from_now,
        active_period_end: @two_hours_from_now,
        notification_period_end: @two_hours_from_now,
        duration_certainty: :KNOWN
      })

      insert(:alert, %{
        alert_id: "10500",
        active_period_start: @two_hours_ago,
        notification_period_start: @two_hours_ago,
        active_period_end: @two_hours_from_now,
        notification_period_end: @two_hours_from_now,
        duration_certainty: :ESTIMATED,
        original_route_selections: ["Blue Line|Blue"]
      })

      insert(:alert, %{
        alert_id: "10600",
        active_period_start: @one_day_ago,
        notification_period_start: @one_day_ago,
        active_period_end: @end_of_service_utc,
        notification_period_end: @end_of_service_utc,
        duration_certainty: :KNOWN,
        original_route_selections: ["10"],
        primary_service_type: "3"
      })

      insert(:alert, %{
        alert_id: "10700",
        active_period_start: @one_day_ago,
        notification_period_start: @one_day_ago,
        active_period_end: @six_hours_ago,
        notification_period_end: @six_hours_ago,
        duration_certainty: :KNOWN
      })

      insert(:alert, %{
        alert_id: "10800",
        active_period_start: @one_day_from_now,
        notification_period_start: @one_day_from_now,
        active_period_end: @two_days_from_now,
        notification_period_end: @two_days_from_now,
        duration_certainty: :KNOWN
      })

      insert(:alert, %{
        alert_id: "10900",
        active_period_start: @six_hours_ago,
        notification_period_start: @six_hours_ago,
        active_period_end: @two_days_from_now,
        notification_period_end: @two_days_from_now,
        duration_certainty: :KNOWN,
        original_route_selections: ["1|1"],
        primary_service_type: "3"
      })

      insert(:alert, %{
        alert_id: "11000",
        active_period_start: @one_hour_from_now,
        notification_period_start: @one_hour_from_now,
        active_period_end: @end_of_service_utc,
        notification_period_end: @end_of_service_utc,
        duration_certainty: :KNOWN
      })

      insert(:alert, %{
        alert_id: "11100",
        active_period_start: @one_hour_from_now,
        notification_period_start: @one_hour_from_now,
        active_period_end: nil,
        notification_period_end: nil,
        duration_certainty: :UNKNOWN
      })

      insert(:alert, %{
        alert_id: "11200",
        active_period_start: @three_days_ago,
        notification_period_start: @three_days_ago,
        active_period_end: @one_day_ago,
        notification_period_end: @one_day_ago,
        duration_certainty: :KNOWN
      })

      insert(:alert, %{
        alert_id: "11300",
        active_period_start: @two_days_ago,
        notification_period_start: @two_days_ago,
        active_period_end: @one_day_ago,
        notification_period_end: @one_day_ago,
        duration_certainty: :KNOWN
      })

      insert(:alert, %{
        alert_id: "11400",
        active_period_start: @two_hours_from_now,
        notification_period_start: @two_hours_from_now,
        active_period_end: @end_of_service_utc,
        notification_period_end: @end_of_service_utc,
        duration_certainty: :KNOWN
      })

      # current closed
      insert(:alert, %{
        alert_id: "11500",
        active_period_start: @six_hours_ago,
        notification_period_start: @six_hours_ago,
        active_period_end: @one_hour_from_now,
        notification_period_end: @one_hour_from_now,
        duration_certainty: :KNOWN,
        closed_timestamp: @two_hours_ago
      })

      # future closed
      insert(:alert, %{
        alert_id: "11600",
        active_period_start: @two_hours_from_now,
        notification_period_start: @two_hours_from_now,
        active_period_end: @end_of_service_utc,
        notification_period_end: @end_of_service_utc,
        duration_certainty: :KNOWN,
        closed_timestamp: @two_hours_ago
      })

      # past closed
      insert(:alert, %{
        alert_id: "11700",
        active_period_start: @two_days_ago,
        notification_period_start: @two_days_ago,
        active_period_end: @one_day_ago,
        notification_period_end: @one_day_ago,
        duration_certainty: :KNOWN,
        closed_timestamp: @two_hours_ago
      })

      # current draft
      insert(:alert, %{
        alert_id: "11800",
        active_period_start: @six_hours_ago,
        notification_period_start: @six_hours_ago,
        active_period_end: @one_hour_from_now,
        notification_period_end: @one_hour_from_now,
        duration_certainty: :KNOWN,
        draft: true
      })

      # future draft
      insert(:alert, %{
        alert_id: "11900",
        active_period_start: @two_hours_from_now,
        notification_period_start: @two_hours_from_now,
        active_period_end: @end_of_service_utc,
        notification_period_end: @end_of_service_utc,
        duration_certainty: :KNOWN,
        draft: true
      })

      # past draft
      insert(:alert, %{
        alert_id: "12000",
        active_period_start: @two_days_ago,
        notification_period_start: @two_days_ago,
        active_period_end: @one_day_ago,
        notification_period_end: @one_day_ago,
        duration_certainty: :KNOWN,
        draft: true
      })

      :ok
    end

    @tag :logged_in_user
    test "default timeline filter is current, with end date asc", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/alerts")

      assert get_alert_id_order(html) == ["10300", "10500", "10600", "10900", "10100", "10000"]
    end

    @tag :logged_in_user
    test "future timeline filter renders end date asc", %{conn: conn} do
      {:ok, _view, html} =
        live(conn, "/alerts?filter[timeline]=future")

      assert get_alert_id_order(html) == ["10400", "10200", "11000", "11400", "10800", "11100"]
    end

    @tag :logged_in_user
    test "past timeline filter renders end date desc, and reversing sort works", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts?filter[timeline]=past")

      assert element(view, "th[aria-sort='descending'] span.order-direction") |> render_async() =~
               "hero-arrow-down"

      assert get_alert_id_order(render_async(view)) == [
               "11600",
               "11500",
               "10700",
               "11300",
               "11700",
               "11200"
             ]

      view
      |> element("th[aria-sort='descending'] a", "End")
      |> render_click()

      assert element(view, "th[aria-sort='ascending'] span.order-direction") |> render_async() =~
               "hero-arrow-up"

      assert get_alert_id_order(render_async(view)) == [
               "11200",
               "11700",
               "11300",
               "10700",
               "11500",
               "11600"
             ]
    end

    @tag :logged_in_user
    test "all timeline filter renders end date desc", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/alerts?filter[timeline]=all")

      assert get_alert_id_order(html) == [
               "11100",
               "10000",
               "10100",
               "10800",
               "10900",
               "11400",
               "11600",
               "11000",
               "10600",
               "10200",
               "10500",
               "10400",
               "10300",
               "11500",
               "10700",
               "11300",
               "11700",
               "11200"
             ]
    end

    @tag :logged_in_user
    test "reversing the sort for end time maintains proper order", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts")

      assert element(view, "th[aria-sort='ascending'] span.order-direction") |> render_async() =~
               "hero-arrow-up"

      view
      |> element("a", "End")
      |> render_click()

      assert element(view, "th[aria-sort='descending'] span.order-direction") |> render_async() =~
               "hero-arrow-down"

      assert get_alert_id_order(render_async(view)) == [
               "10000",
               "10100",
               "10900",
               "10600",
               "10500",
               "10300"
             ]

      view
      |> element("a", "End")
      |> render_click()

      assert element(view, "th[aria-sort='ascending'] span.order-direction") |> render_async() =~
               "hero-arrow-up"

      assert get_alert_id_order(render_async(view)) == [
               "10300",
               "10500",
               "10600",
               "10900",
               "10100",
               "10000"
             ]
    end

    @tag :logged_in_user
    test "sorting by other fields and then sorting by end time maintains proper order", %{
      conn: conn
    } do
      {:ok, view, _html} = live(conn, "/alerts")

      view
      |> element("a", "ID")
      |> render_click()

      refute get_alert_id_order(render_async(view)) == [
               "10300",
               "10500",
               "10600",
               "10900",
               "10100",
               "10000"
             ]

      view
      |> element("a", "End")
      |> render_click()

      assert element(view, "th[aria-sort='ascending'] span.order-direction") |> render_async() =~
               "hero-arrow-up"

      assert get_alert_id_order(render_async(view)) == [
               "10300",
               "10500",
               "10600",
               "10900",
               "10100",
               "10000"
             ]

      view
      |> element("a", "End")
      |> render_click()

      assert element(view, "th[aria-sort='descending'] span.order-direction") |> render_async() =~
               "hero-arrow-down"

      assert get_alert_id_order(render_async(view)) == [
               "10000",
               "10100",
               "10900",
               "10600",
               "10500",
               "10300"
             ]
    end

    @tag :logged_in_user
    test "sorting by service type orders as expected", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts")

      view
      |> element("a", "Service")
      |> render_click()

      assert element(view, "th[aria-sort='ascending'] span.order-direction") |> render_async() =~
               "hero-arrow-up"

      assert get_alert_id_order(render_async(view)) == [
               "10900",
               "10600",
               "10500",
               "10300",
               "10100",
               "10000"
             ]

      view
      |> element("a", "Service")
      |> render_click()

      assert element(view, "th[aria-sort='descending'] span.order-direction") |> render_async() =~
               "hero-arrow-down"

      assert get_alert_id_order(render_async(view)) == [
               "10000",
               "10300",
               "10100",
               "10500",
               "10600",
               "10900"
             ]
    end

    @tag :logged_in_user
    test "can sort, then search while retaining sort order", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts")

      # sort descending by clicking twice
      view
      |> element("a", "ID")
      |> render_click()

      view
      |> element("a", "ID")
      |> render_click()

      assert_patch(
        view,
        ~p"/alerts?filter[timeline]=current&order_by=integer_alert_id&order_direction=desc"
      )

      assert element(view, "th[aria-sort='descending'] span.order-direction") |> render_async() =~
               "hero-arrow-down"

      assert get_alert_id_order(render_async(view)) == [
               "10900",
               "10600",
               "10500",
               "10300",
               "10100",
               "10000"
             ]

      # search in the search bar and make sure we are still in sort desc order
      view
      |> element("input[name='view_alerts_live[multi_column_search]']")
      |> render_change(%{
        "view_alerts_live" => %{
          "multi_column_search" => "red line"
        }
      })

      assert get_alert_id_order(render_async(view)) == ["10300", "10100"]

      assert_patch(
        view,
        ~p"/alerts?filter[multi_column_search]=red+line&filter[timeline]=current&order_by=integer_alert_id&order_direction=desc"
      )

      assert element(view, "th[aria-sort='descending'] span.order-direction") |> render_async() =~
               "hero-arrow-down"
    end

    @tag :logged_in_user
    test "can sort, then filter in the modal while retaining sort order", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts")

      # sort descending by clicking twice
      view
      |> element("a", "ID")
      |> render_click()

      view
      |> element("a", "ID")
      |> render_click()

      assert_patch(
        view,
        ~p"/alerts?filter[timeline]=current&order_by=integer_alert_id&order_direction=desc"
      )

      assert element(view, "th[aria-sort='descending'] span.order-direction") |> render_async() =~
               "hero-arrow-down"

      assert get_alert_id_order(render_async(view)) == [
               "10900",
               "10600",
               "10500",
               "10300",
               "10100",
               "10000"
             ]

      # filter in the modal for just buses (3)
      view
      |> element("#alert-filter-form")
      |> render_submit(%{
        "view_alerts_live" => %{
          # bus
          "service_type" => ["3"]
        }
      })

      assert get_alert_id_order(render_async(view)) == ["10900", "10600", "10100"]

      assert_patch(
        view,
        ~p"/alerts?filter[service_type][]=3&filter[timeline]=current&order_by=integer_alert_id&order_direction=desc"
      )

      assert element(view, "th[aria-sort='descending'] span.order-direction") |> render() =~
               "hero-arrow-down"
    end
  end

  describe "alerts list pagination" do
    setup do
      # past
      Enum.each(1..90, fn i ->
        insert(:alert, %{
          alert_id: "#{i}",
          active_period_start: ~U[2023-01-01 00:01:00Z],
          active_period_end: ~U[2023-01-01 01:01:00Z],
          primary_service_type: "3"
        })
      end)

      # current
      Enum.each(1..110, fn i ->
        insert(:alert, %{
          alert_id: "#{90 + i}",
          active_period_start: ~U[2023-01-01 00:01:00Z],
          active_period: [build(:active_period, %{start: ~U[2023-01-01 00:01:00Z]})]
        })
      end)
    end

    @tag :logged_in_user
    test "it paginates records", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/alerts?filter[timeline]=past")
      assert Repo.aggregate(Alert, :count) == 200
      assert get_alert_id_order(html) == Enum.map(1..50, fn i -> "#{i}" end)
    end

    @tag :logged_in_user
    test "it paginates Current records", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/alerts?filter[timeline]=current")
      assert get_alert_id_order(html) == Enum.map(91..140, fn i -> "#{i}" end)
    end

    @tag :logged_in_user
    test "pagination is navigable", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts?filter[timeline]=past")

      view
      |> element("button[aria-label='Go to page 2']", "2")
      |> render_click()

      assert get_alert_id_order(render_async(view)) == Enum.map(51..90, fn i -> "#{i}" end)
    end

    @tag :logged_in_user
    test "timeline navigation from paginated results returns to page 1", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts?filter[timeline]=past")

      view
      |> element("button[aria-label='Go to page 2']", "2")
      |> render_click()

      view
      |> element("label:has(input[aria-label='Current'])")
      |> render_click()

      view
      |> element("label:has(input[aria-label='Past'])")
      |> render_click()

      assert get_alert_id_order(render_async(view)) == Enum.map(1..50, fn i -> "#{i}" end)
    end

    @tag :logged_in_user
    test "it removes page param when filtering", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts?filter[timeline]=past&page=2")

      view
      |> element("#alert-filter-form")
      |> render_submit(%{
        "view_alerts_live" => %{
          # bus
          "service_type" => ["3"]
        }
      })

      assert_patch(
        view,
        ~p"/alerts?filter[service_type][]=3&filter[timeline]=past"
      )

      # Assert we are back on page 1
      html =
        view
        |> element("nav button", "1")
        |> render()

      assert html =~ "aria-current=\"page\""
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
        active_period_start: ~U[2023-11-12 00:01:00Z],
        duration_certainty: :UNKNOWN,
        header_text: "here's a subway delay alert",
        effect_detail: "DELAY",
        original_route_selections: ["Orange"]
      })

      {:ok, _view, html} = live(conn, "/alerts")

      assert html =~ "Orange Line"
    end

    @tag :logged_in_user
    test "up to four bus routes can be displayed without collapsing the number", %{conn: conn} do
      with_mock(RoutesRepo, [], all: fn -> [] end) do
        insert(:alert, %{
          alert_id: "123",
          active_period: [
            build(:active_period, %{start: ~U[2023-11-12 00:01:00Z]}),
            build(:active_period, %{start: ~U[2023-11-13 00:01:00Z]})
          ],
          active_period_start: ~U[2023-11-12 00:01:00Z],
          duration_certainty: :UNKNOWN,
          header_text: "here's a bus delay alert",
          effect_detail: "DELAY",
          original_route_selections: ["aa|111", "bb|222", "cc|333", "dd|444"]
        })

        {:ok, _view, html} = live(conn, "/alerts")

        assert html =~ ~r/<div title="aa".+?>.*aa.*<\/div>/s
        assert html =~ ~r/<div title="bb".+?>.*bb.*<\/div>/s
        assert html =~ ~r/<div title="cc".+?>.*cc.*<\/div>/s
        assert html =~ ~r/<div title="dd".+?>.*dd.*<\/div>/s
        refute html =~ ~r/<div .+?>.*\+.*<\/div>/s
      end
    end

    @tag :logged_in_user
    test "five or more routes will be collapsed", %{conn: conn} do
      with_mock(RoutesRepo, [], all: fn -> [] end) do
        insert(:alert, %{
          alert_id: "123",
          active_period: [
            build(:active_period, %{start: ~U[2023-11-12 00:01:00Z]}),
            build(:active_period, %{start: ~U[2023-11-13 00:01:00Z]})
          ],
          active_period_start: ~U[2023-11-12 00:01:00Z],
          duration_certainty: :UNKNOWN,
          header_text: "here's a bus delay alert",
          effect_detail: "DELAY",
          original_route_selections: ["aa|111", "bb|222", "cc|333", "dd|444", "ee|555"]
        })

        {:ok, _view, html} = live(conn, "/alerts")

        assert html =~ ~r/<div title="aa".+?>.*aa.*<\/div>/s
        assert html =~ ~r/<div title="bb".+?>.*bb.*<\/div>/s
        assert html =~ ~r/<div title="cc".+?>.*cc.*<\/div>/s
        assert html =~ ~r/<div title="dd".+?>.*dd.*<\/div>/s
        refute html =~ ~r/<div title="ee".+?>.*ee.*<\/div>/s
        assert html =~ ~r/<div title="\+1".+?>.*\+1.*<\/div>/s
      end
    end

    @tag :logged_in_user
    test "SLW is represented by 1 SL route pill instead of by bus number or multiple pills", %{
      conn: conn
    } do
      with_mock(RoutesRepo, [], all: fn -> [] end) do
        insert(:alert, %{
          alert_id: "123",
          active_period: [
            build(:active_period, %{start: ~U[2023-11-12 00:01:00Z]}),
            build(:active_period, %{start: ~U[2023-11-13 00:01:00Z]})
          ],
          active_period_start: ~U[2023-11-12 00:01:00Z],
          duration_certainty: :UNKNOWN,
          header_text: "here's a SL delay alert",
          effect_detail: "DELAY",
          original_route_selections: ["SLW|746"]
        })

        {:ok, _view, html} = live(conn, "/alerts")

        assert html =~ "SLW"
        refute html =~ "SL1"
      end
    end

    @tag :logged_in_user
    test "CT2 is represented by proper route pill", %{
      conn: conn
    } do
      with_mock(RoutesRepo, [], all: fn -> [] end) do
        insert(:alert, %{
          alert_id: "123",
          active_period: [
            build(:active_period, %{start: ~U[2023-11-12 00:01:00Z]}),
            build(:active_period, %{start: ~U[2023-11-13 00:01:00Z]})
          ],
          active_period_start: ~U[2023-11-12 00:01:00Z],
          duration_certainty: :UNKNOWN,
          header_text: "here's a CT3 delay alert",
          effect_detail: "DELAY",
          original_route_selections: ["CT3|708"]
        })

        {:ok, _view, html} = live(conn, "/alerts")

        assert html =~ "CT3"
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
        active_period_start: ~U[2023-11-12 00:01:00Z],
        duration_certainty: :UNKNOWN,
        header_text: "here's a bike issue alert",
        effect_name: "Bike Issue",
        original_route_selections: []
      })

      {:ok, _view, html} = live(conn, "/alerts")

      assert html =~ ~r/title="Facility"/s
    end

    @tag :logged_in_user
    test "systemwide alert shows the systemwide pill", %{conn: conn} do
      insert(:alert, %{
        alert_id: "123",
        active_period: [
          build(:active_period, %{start: ~U[2023-11-12 00:01:00Z]}),
          build(:active_period, %{start: ~U[2023-11-13 00:01:00Z]})
        ],
        active_period_start: ~U[2023-11-12 00:01:00Z],
        duration_certainty: :UNKNOWN,
        header_text: "here's a delay alert for all ferries",
        effect_detail: "DELAY",
        original_route_selections: []
      })

      {:ok, _view, html} = live(conn, "/alerts")

      assert html =~ "Systemwide"
    end

    @tag :logged_in_user
    test "commuter rail pill shows proper full name without CR appended", %{conn: conn} do
      with_mock(RoutesRepo, [], all: fn -> [] end) do
        insert(:alert, %{
          alert_id: "123",
          active_period: [
            build(:active_period, %{start: ~U[2023-11-12 00:01:00Z]}),
            build(:active_period, %{start: ~U[2023-11-13 00:01:00Z]})
          ],
          active_period_start: ~U[2023-11-12 00:01:00Z],
          duration_certainty: :UNKNOWN,
          header_text: "here's a CR delay alert",
          effect_detail: "DELAY",
          original_route_selections: ["Fall River/New Bedford Line|CR-NewBedford"]
        })

        {:ok, _view, html} = live(conn, "/alerts")

        assert html =~ "Fall River/New Bedford"
      end
    end

    @tag :logged_in_user
    test "ferry pill shows proper full name", %{conn: conn} do
      with_mock(RoutesRepo, [], all: fn -> [] end) do
        insert(:alert, %{
          alert_id: "123",
          active_period: [
            build(:active_period, %{start: ~U[2023-11-12 00:01:00Z]}),
            build(:active_period, %{start: ~U[2023-11-13 00:01:00Z]})
          ],
          active_period_start: ~U[2023-11-12 00:01:00Z],
          duration_certainty: :UNKNOWN,
          header_text: "here's a ferry delay alert",
          effect_detail: "DELAY",
          original_route_selections: ["East Boston Ferry|Boat-EastBoston"]
        })

        {:ok, _view, html} = live(conn, "/alerts")

        assert html =~ "East Boston"
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
        active_period_start: ~U[2023-10-12 00:01:00Z],
        duration_certainty: :UNKNOWN,
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
        active_period_start: ~U[2023-10-12 00:01:00Z],
        duration_certainty: :UNKNOWN,
        header_text: "this is the second alert",
        effect_detail: "SUMMARY",
        original_route_selections: [],
        closed_timestamp: ~U[2024-10-12 00:01:00Z]
      })

      :ok
    end

    @tag :logged_in_user
    test "effect display", %{conn: conn} do
      with_mock(RoutesRepo, [],
        all: fn -> [] end,
        get: fn route_id -> %{name: route_id} end
      ) do
        {:ok, _view, html} = live(conn, "/alerts")
        assert html =~ "Detour"
        assert html =~ "Summary"
      end
    end

    @tag :logged_in_user
    test "actions display for closed alerts", %{conn: conn} do
      with_mock(RoutesRepo, [],
        all: fn -> [] end,
        get: fn route_id -> %{name: route_id} end
      ) do
        {:ok, view, html} =
          live(conn, "/alerts?filter[timeline]=past")

        refute html =~ ~s(<span class="hero-pencil-solid w-4 h-4"></span>)
        refute html =~ ~s(<span class="hero-x-mark-solid w-4 h-4"></span>)

        assert html =~
                 ~s(<span class="hero-ellipsis-vertical w-4 h-4" style="mask-position: center"></span>)

        assert view |> has_element?("#copy-link-button-123")
        assert view |> has_element?("#duplicate-button-123")
        assert view |> has_element?("#download-history-button-123")
      end
    end

    @tag :logged_in_user
    test "actions display for open alerts", %{conn: conn} do
      with_mock(RoutesRepo, [],
        all: fn -> [] end,
        get: fn route_id -> %{name: route_id} end
      ) do
        insert(:alert, %{
          alert_id: "345",
          active_period: [
            build(:active_period, %{start: ~U[2023-10-12 00:01:00Z]}),
            build(:active_period, %{start: ~U[2023-10-13 00:01:00Z]})
          ],
          active_period_start: ~U[2023-10-12 00:01:00Z],
          duration_certainty: :UNKNOWN,
          header_text: "this is the third alert",
          effect_detail: "DETOUR",
          original_route_selections: ["1", "2"]
        })

        {:ok, view, html} = live(conn, "/alerts")

        assert html =~
                 ~s(<span class="hero-pencil-solid w-4 h-4" style="mask-position: center"></span>)

        assert html =~
                 ~s(<span class="hero-x-mark-solid w-4 h-4" style="mask-position: center"></span>)

        assert view |> has_element?("#copy-link-button-345")
        assert view |> has_element?("#duplicate-button-345")
        assert view |> has_element?("#download-history-button-345")
      end
    end

    @tag :logged_in_viewer
    test "view-only actions display for closed alerts", %{conn: conn} do
      with_mock(RoutesRepo, [],
        all: fn -> [] end,
        get: fn route_id -> %{name: route_id} end
      ) do
        {:ok, view, html} =
          live(conn, "/alerts?filter[timeline]=past")

        refute html =~
                 ~s(<span class="hero-pencil-solid w-4 h-4" style="mask-position: center"></span>)

        refute html =~
                 ~s(<span class="hero-x-mark-solid w-4 h-4" style="mask-position: center"></span>)

        assert html =~
                 ~s(<span class="hero-ellipsis-vertical w-4 h-4" style="mask-position: center"></span>)

        refute view |> has_element?("#duplicate-button-123")
        assert view |> has_element?("#copy-link-button-123")
        assert view |> has_element?("#download-history-button-123")
      end
    end

    @tag :logged_in_viewer
    test "view-only actions display for open alerts", %{conn: conn} do
      with_mock(RoutesRepo, [],
        all: fn -> [] end,
        get: fn route_id -> %{name: route_id} end
      ) do
        insert(:alert, %{
          alert_id: "345",
          active_period: [
            build(:active_period, %{start: ~U[2023-10-12 00:01:00Z]}),
            build(:active_period, %{start: ~U[2023-10-13 00:01:00Z]})
          ],
          active_period_start: ~U[2023-10-12 00:01:00Z],
          duration_certainty: :UNKNOWN,
          header_text: "this is the third alert",
          effect_detail: "DETOUR",
          original_route_selections: ["1", "2"]
        })

        {:ok, view, html} = live(conn, "/alerts")

        refute html =~ ~s(<span class="hero-pencil-solid w-4 h-4"></span>)
        refute html =~ ~s(<span class="hero-x-mark-solid w-4 h-4"></span>)
        refute view |> has_element?("#duplicate-button-345")
        assert view |> has_element?("#copy-link-button-345")
        assert view |> has_element?("#download-history-button-345")
      end
    end

    @tag :logged_in_user
    test "clicking close alert closes the alert", %{conn: conn} do
      with_mock(RoutesRepo, [],
        all: fn -> [] end,
        get: fn route_id -> %{name: route_id} end
      ) do
        insert(:alert, %{
          alert_id: "345",
          active_period: [
            build(:active_period, %{start: ~U[2023-10-12 00:01:00Z]})
          ],
          active_period_start: ~U[2023-10-12 00:01:00Z],
          duration_certainty: :UNKNOWN,
          header_text: "this is the third alert",
          effect_detail: "DETOUR",
          original_route_selections: ["1", "2"],
          last_push_notification_timestamp: nil,
          severity: 4
        })

        {:ok, view, _html} = live(conn, "/alerts")

        view |> element("td[phx-click]", "345") |> render_click()

        render_async(view)

        view
        |> element("#all-clear-checkbox-close-alert-nested-modal-345")
        |> render_click()

        view
        |> element("#close-alert-modal-345 button", "Close now")
        |> render_click()

        :timer.sleep(5)
        result = Alerts.get_by_alert_id("345")
        assert result.closed_timestamp !== nil
        assert result.last_push_notification_timestamp !== nil

        html = render(view)
        assert html =~ "No alerts found"
      end
    end

    @tag :logged_in_user
    test "clicking edit alert opens editing workflow", %{conn: conn} do
      with_mock(RoutesRepo, [],
        all: fn -> [] end,
        get: fn route_id -> %{name: route_id} end
      ) do
        insert(:alert, %{
          alert_id: "345",
          active_period: [
            build(:active_period, %{start: ~U[2023-10-12 00:01:00Z]}),
            build(:active_period, %{start: ~U[2023-10-13 00:01:00Z]})
          ],
          active_period_start: ~U[2023-10-12 00:01:00Z],
          duration_certainty: :UNKNOWN,
          header_text: "this is the third alert",
          effect_detail: "DETOUR",
          original_route_selections: ["1", "2"]
        })

        {:ok, view, _html} = live(conn, "/alerts")

        view
        |> element("#edit-button-345")
        |> render_click()

        assert_redirect(view, "/alerts/edit/345")
      end
    end

    @tag :logged_in_user
    test "clicking duplicate alert opens duplicating workflow", %{conn: conn} do
      with_mock(RoutesRepo, [],
        all: fn -> [] end,
        get: fn route_id -> %{name: route_id} end
      ) do
        insert(:alert, %{
          alert_id: "345",
          active_period: [
            build(:active_period, %{start: ~U[2023-10-12 00:01:00Z]}),
            build(:active_period, %{start: ~U[2023-10-13 00:01:00Z]})
          ],
          active_period_start: ~U[2023-10-12 00:01:00Z],
          duration_certainty: :UNKNOWN,
          header_text: "this is the third alert",
          effect_detail: "DETOUR",
          original_route_selections: ["1", "2"]
        })

        {:ok, view, _html} = live(conn, "/alerts")

        view
        |> element("#duplicate-button-345")
        |> render_click()

        assert_redirect(view, "/alerts/duplicate/345")
      end
    end

    @tag :logged_in_user
    test "clicking an alert row opens the details modal with route type and effect name",
         %{conn: conn} do
      alert =
        insert(:alert, %{
          alert_id: "999",
          header_text: "modal rendering test alert",
          active_period_start: ~U[2023-10-12 00:01:00Z],
          closed_timestamp: ~U[2024-10-12 00:01:00Z],
          severity: 4
        })

      {:ok, view, _html} = live(conn, "/alerts?filter[timeline]=past")

      view |> element("td[phx-click]", alert.alert_id) |> render_click()

      html = render(view)
      assert html =~ "Subway"
      assert html =~ "Station Closure"
    end
  end

  describe "start and end times" do
    test "no end time" do
      alert =
        build(:alert, %{
          alert_id: "123",
          active_period: [
            build(:active_period, %{start: ~U[2023-10-12 00:01:00Z]})
          ],
          duration_certainty: :UNKNOWN
        })

      expected = "further notice"

      actual =
        AlertsUIWeb.ViewAlertsLive.safe_format_end_time(
          alert.active_period_end,
          alert.duration_certainty
        )

      assert expected == actual

      expected_timestamp = nil

      actual_timestamp = AlertsUIWeb.ViewAlertsLive.safe_format_timestamp(alert.active_period_end)

      assert expected_timestamp == actual_timestamp
    end

    test "when work will be completed externally" do
      alert =
        build(:alert, %{
          alert_id: "123",
          duration_certainty: :UNKNOWN,
          can_close_automatically: true,
          primary_service_type: "access",
          effect_name: "Elevator Closure"
        })

      expected = "from Trapeze"

      actual =
        AlertsUIWeb.ViewAlertsLive.safe_format_end_time(
          alert.active_period_end,
          alert.duration_certainty,
          %{
            can_close_automatically: alert.can_close_automatically,
            primary_service_type: alert.primary_service_type,
            effect_name: alert.effect_name
          }
        )

      assert expected == actual

      expected_timestamp = "When work order is closed in Trapeze"

      actual_timestamp =
        AlertsUIWeb.ViewAlertsLive.safe_format_timestamp(
          alert.active_period_end,
          alert.duration_certainty,
          %{
            can_close_automatically: alert.can_close_automatically,
            primary_service_type: alert.primary_service_type,
            effect_name: alert.effect_name
          }
        )

      assert expected_timestamp == actual_timestamp
    end

    test "when work has been completed externally" do
      alert =
        build(:alert, %{
          alert_id: "123",
          active_period_end: ~U[2023-10-12 00:02:00Z],
          closed_timestamp: ~U[2023-10-12 00:02:00Z],
          duration_certainty: :KNOWN,
          can_close_automatically: true,
          primary_service_type: "access",
          effect_name: "Elevator Closure"
        })

      expected = "Oct 11, 2023"

      actual =
        AlertsUIWeb.ViewAlertsLive.safe_format_end_time(
          alert.active_period_end,
          alert.duration_certainty,
          %{
            can_close_automatically: alert.can_close_automatically,
            primary_service_type: alert.primary_service_type,
            effect_name: alert.effect_name
          }
        )

      assert expected == actual

      expected_timestamp = "Oct 11, 2023, 8:02 PM"

      actual_timestamp = AlertsUIWeb.ViewAlertsLive.safe_format_timestamp(alert.active_period_end)

      assert expected_timestamp == actual_timestamp
    end

    test "end of later today" do
      alert =
        build(:alert, %{
          alert_id: "123",
          active_period: [
            build(:active_period, %{
              start: ~U[2023-10-12 00:01:00Z],
              end: ~U[2023-10-13 00:01:00Z]
            })
          ],
          active_period_end: ~U[2023-10-13 00:01:00Z],
          duration_certainty: :ESTIMATED
        })

      expected = "later today"

      actual =
        AlertsUIWeb.ViewAlertsLive.safe_format_end_time(
          alert.active_period_end,
          alert.duration_certainty
        )

      assert expected == actual

      expected_timestamp = "Oct 12, 2023, 8:01 PM"

      actual_timestamp = AlertsUIWeb.ViewAlertsLive.safe_format_timestamp(alert.active_period_end)

      assert expected_timestamp == actual_timestamp
    end

    test "known end where end is end-of-service today" do
      with_mocks([
        {DateTime, [:passthrough], [utc_now: fn -> ~U[2025-06-30 17:50:14.844524Z] end]}
      ]) do
        end_of_service_utc =
          DateTime.new!(~D[2025-07-01], ActivePeriod.end_of_service_time(), "America/New_York")
          |> DateTime.shift_zone!("Etc/UTC")

        alert =
          build(:alert, %{
            alert_id: "123",
            active_period: [
              build(:active_period, %{start: ~U[2023-10-12 00:01:00Z], end: end_of_service_utc})
            ],
            active_period_end: end_of_service_utc,
            duration_certainty: :KNOWN
          })

        expected = "end of service"

        actual =
          AlertsUIWeb.ViewAlertsLive.safe_format_end_time(
            alert.active_period_end,
            alert.duration_certainty
          )

        assert expected == actual

        expected_timestamp = "Jul 1, 2025, 3:00 AM"

        actual_timestamp =
          AlertsUIWeb.ViewAlertsLive.safe_format_timestamp(alert.active_period_end)

        assert expected_timestamp == actual_timestamp
      end
    end

    test "known end where end is not end of service" do
      eastern_now = DateTime.new!(~D[2025-05-29], ~T[02:00:00], "America/New_York")
      utc_now = DateTime.new!(~D[2025-05-29], ~T[06:00:00], "Etc/UTC")

      with_mocks([
        {DateTime, [:passthrough], [now!: fn _ -> eastern_now end, utc_now: fn -> utc_now end]}
      ]) do
        end_time_utc =
          DateTime.new!(
            ~D[2025-06-30],
            ~T[02:00:00],
            "America/New_York"
          )
          |> DateTime.shift_zone!("Etc/UTC")

        alert =
          build(:alert, %{
            alert_id: "123",
            active_period: [
              build(:active_period, %{start: ~U[2023-10-12 00:01:00Z], end: end_time_utc})
            ],
            active_period_end: end_time_utc,
            duration_certainty: :KNOWN
          })

        expected = "Jun 29"

        actual =
          AlertsUIWeb.ViewAlertsLive.safe_format_end_time(
            alert.active_period_end,
            alert.duration_certainty
          )

        assert expected == actual

        expected_timestamp = "Jun 30, 2025, 2:00 AM"

        actual_timestamp =
          AlertsUIWeb.ViewAlertsLive.safe_format_timestamp(alert.active_period_end)

        assert expected_timestamp == actual_timestamp
      end
    end
  end

  test "start is most recent end of service" do
    with_mocks([
      {DateTime, [:passthrough],
       [
         now!: fn _time_zone -> ~U[2025-06-30 17:50:14.844524Z] end
       ]}
    ]) do
      start_of_service_utc =
        DateTime.new!(~D[2025-06-30], ActivePeriod.start_of_service_time(), "America/New_York")
        |> DateTime.shift_zone!("Etc/UTC")

      alert =
        build(:alert, %{
          alert_id: "123",
          active_period: [
            build(:active_period, %{start: start_of_service_utc})
          ],
          active_period_start: start_of_service_utc,
          duration_certainty: :KNOWN
        })

      expected = "start of service"

      actual =
        AlertsUIWeb.ViewAlertsLive.safe_format_start_time(alert.active_period_start)

      assert expected == actual

      expected_timestamp = "Jun 30, 2025, 3:00 AM"

      actual_timestamp =
        AlertsUIWeb.ViewAlertsLive.safe_format_timestamp(alert.active_period_start)

      assert expected_timestamp == actual_timestamp
    end
  end

  test "start is not most recent end of service" do
    with_mocks([
      {DateTime, [:passthrough],
       [
         now!: fn _time_zone -> ~U[2025-06-30 17:50:14.844524Z] end
       ]}
    ]) do
      start_utc =
        DateTime.new!(~D[2025-06-29], ActivePeriod.start_of_service_time(), "America/New_York")
        |> DateTime.shift_zone!("Etc/UTC")

      alert =
        build(:alert, %{
          alert_id: "123",
          active_period: [
            build(:active_period, %{start: start_utc})
          ],
          active_period_start: start_utc,
          duration_certainty: :KNOWN
        })

      expected = "Jun 29"

      actual =
        AlertsUIWeb.ViewAlertsLive.safe_format_start_time(alert.active_period_start)

      assert expected == actual

      expected_timestamp = "Jun 29, 2025, 3:00 AM"

      actual_timestamp =
        AlertsUIWeb.ViewAlertsLive.safe_format_timestamp(alert.active_period_start)

      assert expected_timestamp == actual_timestamp
    end
  end

  @tag :logged_in_user
  test "shows a loading state on the dead render, then alerts once connected", %{conn: conn} do
    with_mock(RoutesRepo, [], all: fn -> [] end, get: fn route_id -> %{name: route_id} end) do
      insert(:alert, %{
        alert_id: "999",
        original_route_selections: ["Orange"],
        header_text: "Out of juice"
      })

      conn = get(conn, "/alerts")
      assert html_response(conn, 200) =~ "Loading"

      {:ok, _view, html} = live(conn)
      refute html =~ "Loading"
      assert html =~ "Out of juice"
    end
  end

  describe "multi-user" do
    @tag :logged_in_user
    test "closing an alert on one page also closes it on another page", %{conn: conn} do
      insert(:alert, %{@alert_1 | alert_id: "345"})
      {:ok, view, _html} = live(conn, "/alerts")
      {:ok, view2, _html} = live(conn, "/alerts")

      view |> element("td[phx-click]", "345") |> render_click()

      render_async(view)

      view
      |> element("#all-clear-checkbox-close-alert-nested-modal-345")
      |> render_click()

      view
      |> element("#close-alert-modal-345 button", "Close now")
      |> render_click()

      html1 = render_async(view)
      html2 = render_async(view2)

      assert html1 =~ "No alerts found"
      assert html2 =~ "No alerts found"
    end

    @tag :logged_in_user
    test "editing an alert on one page also edits it on another page", %{conn: conn} do
      bus_route = %Route{
        direction_names: %{1 => "Inbound", 0 => "Outbound"},
        sort_order: 3,
        id: "746",
        type: 3,
        name: "SLW"
      }

      stop = %Stop{id: "place-sstat", name: "South Station"}

      alert_params =
        build(:alert_map, %{
          alert_id: "345",
          effect: :OTHER_EFFECT,
          effect_detail: "DELAY",
          primary_service_type: "3",
          informed_entity: [
            %{route_type: 3, route_id: bus_route.id, stop_id: stop.id, direction_id: 0}
          ],
          original_route_selections: ["SLW|746"],
          original_stop_selections: ["South Station (outbound)|place-sstat"]
        })

      {:ok, _} = Alerts.create_or_update_alert(alert_params, build(:user))

      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _ -> [bus_route] end,
           get: fn _, _ -> bus_route end,
           all: fn -> [bus_route] end
         ]},
        {StopsRepo, [],
         [
           by_route: fn _, _, _ -> [stop] end,
           get_parent: fn _ -> nil end,
           all: fn _, _ -> [stop] end
         ]},
        {SchedulesRepo, [], [by_route_ids: fn _, _ -> [] end]},
        {RoutePatternsRepo, [],
         [
           by_route_id: fn _, _ -> [] end
         ]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/edit/345")
        {:ok, view2, html2} = live(conn, "/alerts")

        updated_header = "updated this alert which should sync right away on another screen"
        refute html2 =~ updated_header

        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "header_text"],
          "alert_data" => %{"header_text" => updated_header}
        })

        open_review_modal(view)
        submit_alert(view)

        html2 = render_async(view2)
        assert html2 =~ updated_header
      end
    end

    @tag :logged_in_user
    test "creating an alert on one page also makes it appear on another page", %{conn: conn} do
      bus_route = %Route{
        direction_names: %{1 => "Inbound", 0 => "Outbound"},
        sort_order: 3,
        id: "746",
        type: 3,
        name: "SLW"
      }

      stop = %Stop{id: "place-sstat", name: "South Station"}

      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _ -> [bus_route] end,
           get: fn _, _ -> bus_route end,
           all: fn -> [bus_route] end
         ]},
        {StopsRepo, [],
         [
           by_route: fn _, _, _ -> [stop] end,
           get_parent: fn _ -> nil end,
           all: fn _, _ -> [stop] end
         ]},
        {SchedulesRepo, [], [by_route_ids: fn _, _ -> [] end]},
        {RoutePatternsRepo, [],
         [
           by_route_id: fn _, _ -> [] end
         ]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/new")
        {:ok, view2, html2} = live(conn, "/alerts")

        updated_header = "I am a totally new alert!"
        assert html2 =~ "No alerts found"

        view = get_to_submission_page_refactor(conn, view, "Bus", "Delay")

        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "route_ids"],
          "alert_data" => %{"route_ids" => [bus_route.id]}
        })

        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "header_text"],
          "alert_data" => %{"header_text" => updated_header}
        })

        open_review_modal(view)
        submit_alert(view)

        html2 = render_async(view2)
        assert html2 =~ updated_header
      end
    end
  end

  # Takes html of alert list page, parses the html, returns order of alert ids
  defp get_alert_id_order(html) do
    {:ok, document} = Floki.parse_document(html)

    Floki.find(document, "td.alert-id-cell")
    |> Enum.map(fn {_tag_name, _attributes, children_nodes} ->
      children_nodes
      |> hd
      |> String.replace("\n", "")
      |> String.trim()
    end)
  end
end
