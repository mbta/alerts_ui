defmodule AlertsUIWeb.ViewAlertsLiveTest do
  use ExUnit.Case
  use AlertsUIWeb.ConnCase

  import AlertsUI.Support.Factory
  import Mock
  import Phoenix.LiveViewTest

  alias AlertsUI.Alerts
  alias AlertsUI.Models.ActivePeriod
  alias AlertsUI.Models.Alert
  alias AlertsUI.Repo
  alias MBTAV3API.Routes.Repo, as: RoutesRepo

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

  describe "alerts list page" do
    setup do
      insert(:alert, %{
        alert_id: "123",
        active_period: [
          build(:active_period, %{start: ~U[2023-10-12 00:01:00Z]}),
          build(:active_period, %{start: ~U[2023-10-13 00:01:00Z]})
        ],
        active_period_start: ~U[2023-10-12 00:01:00Z],
        header_text: "this is the first alert",
        effect_detail: "DETOUR",
        original_route_selections: ["1", "2"],
        duration_certainty: :UNKNOWN
      })

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
      with_mock(RoutesRepo, get: fn route_id -> %{name: route_id} end) do
        {:ok, _view, html} = live(conn, "/alerts")
        assert html =~ ~r/Alerts/
      end
    end

    test "redirects the user when not logged in", %{conn: conn} do
      assert live(conn, "/alerts") == {:error, {:redirect, %{to: "/auth/keycloak", flash: %{}}}}
    end

    @tag :logged_in_user
    test "sorting click event", %{conn: conn} do
      with_mock(RoutesRepo, get: fn route_id -> %{name: route_id} end) do
        {:ok, view, _html} = live(conn, "/alerts")
        assert view |> render_click("sort-alerts", %{"order" => "active_period_start"}) =~ "123"
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
    test "route filter contains options directly from the db, sorted", %{conn: conn} do
      # Alert with the new route format
      insert(:alert, %{
        alert_id: "899",
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
        alert_id: "999",
        original_route_selections: ["CR-Fitchburg"],
        informed_entity: [
          build(:informed_entity, %{route_id: "CR-Fitchburg", route_type: 2})
        ]
      })

      {:ok, _view, html} = live(conn, "/alerts")

      {:ok, document} = Floki.parse_document(html)

      {_, _, children_nodes} = Floki.get_by_id(document, "view_alerts_live_routes")

      assert [
               {"option", [{"value", "default"}, {"selected", "selected"}],
                ["\n      All\n    "]},
               {"option", [{"value", "708"}], ["CT3"]},
               {"option", [{"value", "62"}], ["62"]},
               {"option", [{"value", "67"}], ["67"]},
               {"option", [{"value", "76"}], ["76"]},
               {"option", [{"value", "350"}], ["350"]},
               {"option", [{"value", "Red"}], ["Red Line"]},
               {"option", [{"value", "CR-Fitchburg"}], ["CR-Fitchburg"]}
             ] = children_nodes
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
  end

  describe "alerts list timeline filtering and sorting" do
    setup do
      insert(:alert, %{
        alert_id: "10000",
        active_period_start: @six_hours_ago,
        notification_period_start: @six_hours_ago,
        active_period_end: nil,
        notification_period_end: nil,
        duration_certainty: :UNKNOWN
      })

      insert(:alert, %{
        alert_id: "10100",
        active_period_start: @one_day_ago,
        notification_period_start: @one_day_ago,
        active_period_end: nil,
        notification_period_end: nil,
        duration_certainty: :UNKNOWN
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
        duration_certainty: :KNOWN
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
        duration_certainty: :ESTIMATED
      })

      insert(:alert, %{
        alert_id: "10600",
        active_period_start: @one_day_ago,
        notification_period_start: @one_day_ago,
        active_period_end: @end_of_service_utc,
        notification_period_end: @end_of_service_utc,
        duration_certainty: :KNOWN
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
        duration_certainty: :KNOWN
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
      {:ok, view, html} = live(conn, "/alerts?filter[timeline]=past")

      assert element(view, "th[aria-sort='descending'] span.order-direction") |> render() =~
               "hero-arrow-down"

      assert get_alert_id_order(html) == ["11600", "11500", "10700", "11300", "11700", "11200"]

      html =
        view
        |> element("a", "End")
        |> render_click()

      assert element(view, "th[aria-sort='ascending'] span.order-direction") |> render() =~
               "hero-arrow-up"

      assert get_alert_id_order(html) == ["11200", "11700", "11300", "10700", "11500", "11600"]
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

      assert element(view, "th[aria-sort='ascending'] span.order-direction") |> render() =~
               "hero-arrow-up"

      html =
        view
        |> element("a", "End")
        |> render_click()

      assert element(view, "th[aria-sort='descending'] span.order-direction") |> render() =~
               "hero-arrow-down"

      assert get_alert_id_order(html) == ["10000", "10100", "10900", "10600", "10500", "10300"]

      html =
        view
        |> element("a", "End")
        |> render_click()

      assert element(view, "th[aria-sort='ascending'] span.order-direction") |> render() =~
               "hero-arrow-up"

      assert get_alert_id_order(html) == ["10300", "10500", "10600", "10900", "10100", "10000"]
    end

    @tag :logged_in_user
    test "sorting by other fields and then sorting by end time maintains proper order", %{
      conn: conn
    } do
      {:ok, view, _html} = live(conn, "/alerts")

      html =
        view
        |> element("a", "ID")
        |> render_click()

      refute get_alert_id_order(html) == ["10300", "10500", "10600", "10900", "10100", "10000"]

      html =
        view
        |> element("a", "End")
        |> render_click()

      assert element(view, "th[aria-sort='ascending'] span.order-direction") |> render() =~
               "hero-arrow-up"

      assert get_alert_id_order(html) == ["10300", "10500", "10600", "10900", "10100", "10000"]

      html =
        view
        |> element("a", "End")
        |> render_click()

      assert element(view, "th[aria-sort='descending'] span.order-direction") |> render() =~
               "hero-arrow-down"

      assert get_alert_id_order(html) == ["10000", "10100", "10900", "10600", "10500", "10300"]
    end
  end

  describe "alerts list pagination" do
    setup do
      # past
      Enum.each(1..90, fn i ->
        insert(:alert, %{
          alert_id: "#{i}",
          active_period_start: ~U[2023-01-01 00:01:00Z],
          active_period_end: ~U[2023-01-01 01:01:00Z]
        })
      end)

      # current
      Enum.each(1..10, fn i ->
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
      assert Repo.aggregate(Alert, :count) == 100
      assert get_alert_id_order(html) == Enum.map(1..50, fn i -> "#{i}" end)
    end

    @tag :logged_in_user
    test "pagination is navigable", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts?filter[timeline]=past")

      html =
        view
        |> element("button[aria-label='Go to page 2']", "2")
        |> render_click()

      assert get_alert_id_order(html) == Enum.map(51..90, fn i -> "#{i}" end)
    end

    @tag :logged_in_user
    test "timeline navigation from paginated results returns to page 1", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts?filter[timeline]=past")

      view
      |> element("button[aria-label='Go to page 2']", "2")
      |> render_click()

      html =
        view
        |> element("input[aria-label='Current']")
        |> render_click()

      assert get_alert_id_order(html) == Enum.map(91..100, fn i -> "#{i}" end)
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
      with_mock(RoutesRepo, get: fn route_id -> %{name: route_id} end) do
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
          original_route_selections: ["111", "222", "333", "444"]
        })

        {:ok, _view, html} = live(conn, "/alerts")

        assert html =~ ~r/<div title="111".+?>.*111.*<\/div>/s
        assert html =~ ~r/<div title="222".+?>.*222.*<\/div>/s
        assert html =~ ~r/<div title="333".+?>.*333.*<\/div>/s
        assert html =~ ~r/<div title="444".+?>.*444.*<\/div>/s
        refute html =~ ~r/<div .+?>.*\+.*<\/div>/s
      end
    end

    @tag :logged_in_user
    test "five or more routes will be collapsed", %{conn: conn} do
      with_mock(RoutesRepo, get: fn route_id -> %{name: route_id} end) do
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
          original_route_selections: ["111", "222", "333", "444", "555"]
        })

        {:ok, _view, html} = live(conn, "/alerts")

        assert html =~ ~r/<div title="111".+?>.*111.*<\/div>/s
        assert html =~ ~r/<div title="222".+?>.*222.*<\/div>/s
        assert html =~ ~r/<div title="333".+?>.*333.*<\/div>/s
        assert html =~ ~r/<div title="444".+?>.*444.*<\/div>/s
        refute html =~ ~r/<div title="555".+?>.*555.*<\/div>/s
        assert html =~ ~r/<div .+?>.*\+1.*<\/div>/s
      end
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
          active_period_start: ~U[2023-11-12 00:01:00Z],
          duration_certainty: :UNKNOWN,
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
    test "CT2 is represented by proper route pill", %{
      conn: conn
    } do
      with_mock(RoutesRepo,
        get: fn
          "708" -> %{name: "CT3"}
        end
      ) do
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
          original_route_selections: ["708"]
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
      with_mock(RoutesRepo,
        get: fn
          "CR-NewBedford" -> %{long_name: "Fall River/New Bedford Line"}
        end
      ) do
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
          original_route_selections: ["CR-NewBedford"]
        })

        {:ok, _view, html} = live(conn, "/alerts")

        assert html =~ "Fall River/New Bedford"
      end
    end

    @tag :logged_in_user
    test "ferry pill shows proper full name", %{conn: conn} do
      with_mock(RoutesRepo,
        get: fn
          "Boat-EastBoston" -> %{long_name: "East Boston Ferry"}
        end
      ) do
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
          original_route_selections: ["Boat-EastBoston"]
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
      with_mock(RoutesRepo, get: fn route_id -> %{name: route_id} end) do
        {:ok, _view, html} = live(conn, "/alerts")
        assert html =~ "Detour"
        assert html =~ "Summary"
      end
    end

    @tag :logged_in_user
    test "actions display for closed alerts", %{conn: conn} do
      with_mock(RoutesRepo, get: fn route_id -> %{name: route_id} end) do
        {:ok, _view, html} =
          live(conn, "/alerts?filter[timeline]=past")

        refute html =~ ~s(<span class="hero-pencil-solid w-4 h-4"></span>)
        refute html =~ ~s(<span class="hero-x-mark-solid w-4 h-4"></span>)
        assert html =~ ~s(<span class="hero-ellipsis-vertical w-4 h-4"></span>)
      end
    end

    @tag :logged_in_user
    test "actions display for open alerts", %{conn: conn} do
      with_mock(RoutesRepo, get: fn route_id -> %{name: route_id} end) do
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

        {:ok, _view, html} = live(conn, "/alerts")

        assert html =~ ~s(<span class="hero-pencil-solid w-4 h-4"></span>)
        assert html =~ ~s(<span class="hero-x-mark-solid w-4 h-4"></span>)
      end
    end

    @tag :logged_in_user
    test "clicking close alert closes the alert", %{conn: conn} do
      with_mock(RoutesRepo, get: fn route_id -> %{name: route_id} end) do
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
          original_route_selections: ["1", "2"],
          last_push_notification_timestamp: nil
        })

        {:ok, view, _html} = live(conn, "/alerts")

        view
        |> element("#all-clear-checkbox-close-alert-modal-345")
        |> render_click()

        view
        |> element("#close-alert-modal-345 button", "Close now")
        |> render_click()

        :timer.sleep(5)
        result = Alerts.get_by_alert_id("345")
        assert result.closed_timestamp !== nil
        assert result.last_push_notification_timestamp !== nil
      end
    end

    @tag :logged_in_user
    test "clicking edit alert opens editing workflow", %{conn: conn} do
      with_mock(RoutesRepo, get: fn route_id -> %{name: route_id} end) do
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

        assert_redirect(view, "/alerts/edit?alert_id=345")
      end
    end

    @tag :logged_in_user
    test "clicking duplicate alert opens duplicating workflow", %{conn: conn} do
      with_mock(RoutesRepo, get: fn route_id -> %{name: route_id} end) do
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

        assert_redirect(view, "/alerts/duplicate?alert_id=345")
      end
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
        AlertsUIWeb.ViewAlertsLive.format_end_time(
          alert.active_period_end,
          alert.duration_certainty
        )

      assert expected == actual

      expected_timestamp = nil

      actual_timestamp = AlertsUIWeb.ViewAlertsLive.format_timestamp(alert.active_period_end)

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
        AlertsUIWeb.ViewAlertsLive.format_end_time(
          alert.active_period_end,
          alert.duration_certainty
        )

      assert expected == actual

      expected_timestamp = "Oct 12, 2023, 8:01 PM"

      actual_timestamp = AlertsUIWeb.ViewAlertsLive.format_timestamp(alert.active_period_end)

      assert expected_timestamp == actual_timestamp
    end

    test "known end where end is end-of-service today" do
      with_mock(DateTime, [:passthrough], utc_now: fn -> ~U[2025-06-30 17:50:14.844524Z] end) do
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
          AlertsUIWeb.ViewAlertsLive.format_end_time(
            alert.active_period_end,
            alert.duration_certainty
          )

        assert expected == actual

        expected_timestamp = "Jul 1, 2025, 3:00 AM"

        actual_timestamp = AlertsUIWeb.ViewAlertsLive.format_timestamp(alert.active_period_end)

        assert expected_timestamp == actual_timestamp
      end
    end

    test "known end where end is not end of service" do
      with_mock(DateTime, [:passthrough], utc_now: fn -> ~U[2025-06-29 17:50:14.844524Z] end) do
        end_time_utc =
          DateTime.new!(~D[2025-06-30], ~T[02:00:00], "America/New_York")
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
          AlertsUIWeb.ViewAlertsLive.format_end_time(
            alert.active_period_end,
            alert.duration_certainty
          )

        assert expected == actual

        expected_timestamp = "Jun 30, 2025, 2:00 AM"

        actual_timestamp = AlertsUIWeb.ViewAlertsLive.format_timestamp(alert.active_period_end)

        assert expected_timestamp == actual_timestamp
      end
    end
  end

  test "start is most recent end of service" do
    with_mock(DateTime, [:passthrough],
      now!: fn _time_zone -> ~U[2025-06-30 17:50:14.844524Z] end
    ) do
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
        AlertsUIWeb.ViewAlertsLive.format_start_time(alert.active_period_start)

      assert expected == actual

      expected_timestamp = "Jun 30, 2025, 3:00 AM"

      actual_timestamp = AlertsUIWeb.ViewAlertsLive.format_timestamp(alert.active_period_start)

      assert expected_timestamp == actual_timestamp
    end
  end

  test "start is not most recent end of service" do
    with_mock(DateTime, [:passthrough],
      now!: fn _time_zone -> ~U[2025-06-30 17:50:14.844524Z] end
    ) do
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
        AlertsUIWeb.ViewAlertsLive.format_start_time(alert.active_period_start)

      assert expected == actual

      expected_timestamp = "Jun 29, 2025, 3:00 AM"

      actual_timestamp = AlertsUIWeb.ViewAlertsLive.format_timestamp(alert.active_period_start)

      assert expected_timestamp == actual_timestamp
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
