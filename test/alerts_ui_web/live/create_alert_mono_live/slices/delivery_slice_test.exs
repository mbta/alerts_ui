defmodule AlertsUIWeb.CreateAlertLive.Slices.DeliverySliceTest do
  use ExUnit.Case, async: false
  use AlertsUIWeb.ConnCase
  import AlertsUI.Support.Factory
  import Phoenix.LiveViewTest
  import Mock
  import Test.Support.Helpers
  alias AlertsUI.Alerts
  alias MBTAV3API.RoutePatterns.Repo, as: RoutePatternsRepo
  alias MBTAV3API.Routes.Repo, as: RoutesRepo
  alias MBTAV3API.Routes.Route
  alias MBTAV3API.Schedules.Repo, as: SchedulesRepo
  alias MBTAV3API.Stops.Repo, as: StopsRepo
  alias MBTAV3API.Stops.Stop

  @stop %Stop{id: "place-sstat", name: "South Station"}
  @route %Route{
    direction_names: %{0 => "Westbound", 1 => "Eastbound"},
    sort_order: 3,
    id: "Red",
    type: 1,
    name: "Red Line"
  }

  @todays_date DateTime.utc_now()
               |> DateTime.shift_zone!("America/New_York")
               |> DateTime.to_date()

  describe "component" do
    @tag :logged_in_user
    test "renders", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/new")
      view = get_to_submission_page(conn, view, "Subway", "Delay")
      assert render(view) =~ ~s(id="delivery_view")
    end

    @tag :logged_in_user
    test "banner text is hidden if checkbox is not checked", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/new")
      view = get_to_submission_page(conn, view, "Subway", "Delay")

      refute view
             |> element("div#banner_div")
             |> render() =~ ~s(id=\"banner-container\")

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "view_banner" => "true"
        }
      })

      assert view
             |> element("div#banner_div")
             |> render() =~ ~s(id=\"banner-container\">)
    end

    @tag :logged_in_user
    test "unchecking banner checkbox hides banner even when banner text is present", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/new")
      view = get_to_submission_page(conn, view, "Subway", "Delay")

      # set header text so the sync will populate banner_text
      view
      |> element("form")
      |> render_change(%{"alert_data" => %{"header_text" => "Some header text"}})

      # check the banner checkbox — banner_text syncs to header_text
      view
      |> element("form")
      |> render_change(%{"alert_data" => %{"view_banner" => "true"}})

      assert view
             |> element("div#banner_div")
             |> render() =~ ~s(id="banner-container")

      # uncheck the banner checkbox — banner should be hidden even though banner_text is non-empty
      view
      |> element("form")
      |> render_change(%{"alert_data" => %{"view_banner" => "false"}})

      refute view
             |> element("div#banner_div")
             |> render() =~ ~s(id="banner-container")
    end

    @tag :logged_in_user
    test "unchecking banner checkbox deletes banner text", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [], [by_type: fn _ -> [@route] end, get: fn _, _ -> @route end]},
        {StopsRepo, [],
         [
           by_route: fn _, _, _ -> [@stop] end
         ]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Subway", "Delay")

        view
        |> element("form")
        |> render_change(%{
          "alert_data" => %{"route_ids" => [@route.id], "view_banner" => "true"}
        })

        view
        |> element("form")
        |> render_change(%{"alert_data" => %{"view_banner" => "false"}})

        view
        |> element("button#review", "Review and submit")
        |> render_click()

        refute view |> element("#review-modal-container") |> render_async(1000) =~
                 ~s(Web Banner Text)
      end
    end

    @tag :logged_in_user
    test "banner text syncs with header text", %{conn: conn} do
      with_mocks([
        {SchedulesRepo, [], [by_route_ids: fn _route_ids, _opts -> [] end]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Subway", "Delay")

        render_async(view, 1000)

        view
        |> element("form")
        |> render_change(%{
          _target: [:foo, :bar],
          alert_data: %{banner_sync_toggle: true, view_banner: true}
        })

        assert view
               |> element("#alert_data_banner_text")
               |> render_async(1000) =~ ~s(delays)
      end
    end

    @tag :logged_in_user
    test "cannot submit banner text without accept banner checkbox", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [], [by_type: fn _ -> [@route] end]},
        {StopsRepo, [],
         [
           by_route: fn _, _, _ -> [@stop] end,
           get_parent: fn _ -> %{id: @stop.id} end
         ]},
        {SchedulesRepo, [], [by_route_ids: fn _route_ids, _opts -> [] end]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Subway", "Delay")

        render_async(view, 1000)

        view
        |> element("form")
        |> render_change(%{
          alert_data: %{banner_sync_toggle: true, view_banner: true}
        })

        view
        |> element("button#review", "Review and submit")
        |> render_click()

        assert view |> render_async() =~ ~s(Check box to show you understand)

        view
        |> element("form")
        |> render_change(%{
          alert_data: %{accept_banner: true}
        })

        view
        |> element("button#review", "Review and submit")
        |> render_click()

        refute view |> render_async() =~ ~s(Check box to show you understand)
      end
    end

    @tag :logged_in_user
    test "banner text does not secretly get filled in when unselecting email box", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/new")
      view = get_to_submission_page(conn, view, "Bus", "Detour")

      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "header_text" => "header text",
          "notification_toggle" => "false",
          "effect_name" => "detour"
        }
      })

      render_async(view, 1000)

      view
      |> element("button#review", "Review and submit")
      |> render_click()

      refute view
             |> render() =~ ~s(Check box to show you understand)
    end

    @tag :logged_in_user
    test "renders correctly while editing", %{conn: conn} do
      alert_params =
        build(
          :alert_map,
          %{
            alert_id: "123",
            header_text: "example header text",
            effect: :OTHER_EFFECT,
            effect_detail: "STOP_CLOSURE",
            severity: 7,
            cause_detail: "unknown",
            banner_text: "my banner text"
          }
        )

      {:ok, _} = Alerts.create_or_update_alert(alert_params, build(:user))
      {:ok, view, _html} = live(conn, "/alerts/edit/123")

      assert view
             |> element("div#banner_div")
             |> render() =~ ~s(id=\"banner-container\">)

      assert view
             |> element("div#banner_div")
             |> render() =~ ~s(my banner text)
    end

    @tag :logged_in_user
    test "last push notification timestamp gets filled in by default upon alert creation",
         %{
           conn: conn
         } do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _types -> [@route] end,
           get: fn _, _ -> @route end
         ]},
        {RoutePatternsRepo, [],
         [
           by_route_id: fn _route_id, _opts -> [] end
         ]},
        {StopsRepo, [],
         [all: fn ["filter[id]": ""], _ -> [] end, by_route: fn _, _, _ -> [@stop] end]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/new")

        view = get_to_submission_page(conn, view, "Subway", "Extra service")
        render_async(view)

        # Mock selecting Red line
        view
        |> element("form")
        |> render_change(%{
          _target: [:foo, :bar],
          alert_data: %{route_ids: ["Red"]}
        })

        view
        |> element("button#review", "Review and submit")
        |> render_click()

        view
        |> element("#review-modal-container button", "Submit")
        |> render_click()

        # wait a smidge for the alert to get persisted to the database
        :timer.sleep(50)

        alert = AlertsUI.Alerts.list_all() |> hd
        assert %DateTime{} = alert.last_push_notification_timestamp

        assert DateTime.compare(
                 alert.last_push_notification_timestamp,
                 alert.last_modified_timestamp
               ) == :eq
      end
    end

    @tag :logged_in_user
    test "Unselecting notification toggle results last push notification timestamp of nil upon alert creation",
         %{
           conn: conn
         } do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _types -> [@route] end,
           get: fn _, _ -> @route end
         ]},
        {RoutePatternsRepo, [],
         [
           by_route_id: fn _route_id, _opts -> [] end
         ]},
        {StopsRepo, [],
         [all: fn ["filter[id]": ""], _ -> [] end, by_route: fn _, _, _ -> [@stop] end]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/new")

        view = get_to_submission_page(conn, view, "Subway", "Extra service")
        render_async(view)

        # unselect notification toggle
        view
        |> element("form")
        |> render_change(%{
          "_target" => [:foo, :bar],
          "alert_data" => %{
            "route_ids" => ["Red"],
            "notification_toggle" => "false"
          }
        })

        view
        |> element("button#review", "Review and submit")
        |> render_click()

        view
        |> element("#review-modal-container button", "Submit")
        |> render_click()

        # wait a smidge for the alert to get persisted to the database
        :timer.sleep(50)
        alert = AlertsUI.Alerts.list_all() |> hd
        assert alert.last_push_notification_timestamp == nil
      end
    end

    @tag :logged_in_user
    test "last push notification timestamp does not UPDATE when editing when box is unchecked by default",
         %{
           conn: conn
         } do
      with_mocks([
        {StopsRepo, [],
         [
           by_route: fn _, _, _ -> [@stop] end,
           get_parent: fn _ -> %{id: @stop.id} end,
           all: fn ["filter[id]": ""], _ -> [] end
         ]},
        {RoutesRepo, [],
         [
           by_type: fn _types -> [@route] end,
           get: fn _, _ -> @route end,
           all: fn _ -> [@route] end
         ]},
        {RoutePatternsRepo, [],
         [
           by_route_id: fn _route_id, _opts -> [] end
         ]},
        {SchedulesRepo, [],
         [
           by_route_ids: fn _route_ids, _opts -> [] end,
           end_of_rating: fn -> Date.add(@todays_date, 7) end
         ]}
      ]) do
        alert_params =
          build(:alert_map, %{
            alert_id: "123",
            effect: :ADDITIONAL_SERVICE,
            effect_detail: "EXTRA_SERVICE",
            header_text: "cool header text",
            last_push_notification_timestamp:
              DateTime.new!(~D[2025-01-01], ~T[02:00:00], "America/New_York"),
            informed_entity: [
              %{route_type: 1, route_id: "Red", direction_id: 0}
            ],
            original_route_selections: [
              "Red Line|Red"
            ]
          })

        {:ok, original_alert} = Alerts.create_or_update_alert(alert_params, build(:user))

        original_lpnt = original_alert.last_push_notification_timestamp

        {:ok, view, _html} = live(conn, "/alerts/edit/123")

        view
        |> element("button#review", "Review and submit")
        |> render_click()

        view
        |> element("#review-modal-container button", "Submit")
        |> render_click()

        # # wait a smidge for the alert to get persisted to the database
        :timer.sleep(50)

        assert AlertsUI.Alerts.list_all()
               |> hd
               |> Map.get(:last_push_notification_timestamp) == original_lpnt
      end
    end

    @tag :logged_in_user
    test "last push notification timestamp does NOT update when editing when box is unchecked by user",
         %{
           conn: conn
         } do
      with_mocks([
        {StopsRepo, [],
         [
           by_route: fn _, _, _ -> [@stop] end,
           get_parent: fn _ -> %{id: @stop.id} end,
           all: fn ["filter[id]": ""], _ -> [] end
         ]},
        {SchedulesRepo, [],
         [
           by_route_ids: fn _route_ids, _opts -> [] end,
           end_of_rating: fn -> Date.add(@todays_date, 7) end
         ]},
        {RoutesRepo, [],
         [
           by_type: fn _types -> [@route] end,
           get: fn _, _ -> @route end,
           all: fn _ -> [@route] end
         ]},
        {RoutePatternsRepo, [],
         [
           by_route_id: fn _route_id, _opts -> [] end
         ]}
      ]) do
        alert_params =
          build(:alert_map, %{
            alert_id: "123",
            effect: :ADDITIONAL_SERVICE,
            effect_detail: "EXTRA_SERVICE",
            header_text: "cool header text",
            primary_service_type: "2",
            last_push_notification_timestamp:
              DateTime.new!(~D[2025-01-01], ~T[02:00:00], "America/New_York"),
            informed_entity: [
              %{route_type: 2, route_id: "Red", direction_id: 0}
            ],
            original_route_selections: [
              "Red Line|Red"
            ]
          })

        {:ok, original_alert} = Alerts.create_or_update_alert(alert_params, build(:user))

        original_lpnt = original_alert.last_push_notification_timestamp

        {:ok, view, _html} = live(conn, "/alerts/edit/123")
        render_async(view)

        view
        |> element("form")
        |> render_change(%{
          "alert_data" => %{
            "notification_toggle" => "false"
          }
        })

        view
        |> element("button#review", "Review and submit")
        |> render_click()

        view
        |> element("#review-modal-container button", "Submit")
        |> render_click()

        # # wait a smidge for the alert to get persisted to the database
        :timer.sleep(50)

        assert AlertsUI.Alerts.list_all()
               |> hd
               |> Map.get(:last_push_notification_timestamp) == original_lpnt
      end
    end

    @tag :logged_in_user
    test "last push notification timestamp does update when editing when box is checked by default",
         %{
           conn: conn
         } do
      with_mocks([
        {StopsRepo, [],
         [
           by_route: fn _, _, _ -> [@stop] end,
           get_parent: fn _ -> %{id: @stop.id} end,
           all: fn _, _ -> [@stop] end
         ]},
        {SchedulesRepo, [],
         [
           by_route_ids: fn _route_ids, _opts -> [] end,
           end_of_rating: fn -> Date.add(@todays_date, 7) end
         ]},
        {RoutesRepo, [],
         [
           by_type: fn _types -> [@route] end,
           get: fn _, _ -> @route end,
           all: fn _ -> [@route] end
         ]},
        {RoutePatternsRepo, [],
         [
           by_route_id: fn _route_id, _opts -> [] end
         ]}
      ]) do
        alert_params =
          build(:alert_map, %{
            alert_id: "123",
            effect: :ADDITIONAL_SERVICE,
            effect_detail: "EXTRA_SERVICE",
            header_text: "cool header text",
            primary_service_type: "2",
            last_push_notification_timestamp:
              DateTime.new!(~D[2025-01-01], ~T[02:00:00], "America/New_York"),
            informed_entity: [
              %{route_type: 2, route_id: "Red", direction_id: 0}
            ],
            original_route_selections: [
              "Red Line|Red"
            ]
          })

        {:ok, original_alert} = Alerts.create_or_update_alert(alert_params, build(:user))

        original_lpnt = original_alert.last_push_notification_timestamp

        {:ok, view, _html} = live(conn, "/alerts/edit/123")
        render_async(view)

        view
        |> element("button#review", "Review and submit")
        |> render_click()

        view
        |> element("#review-modal-container button", "Submit")
        |> render_click()

        # # wait a smidge for the alert to get persisted to the database
        :timer.sleep(50)

        alert = hd(AlertsUI.Alerts.list_all())
        assert Map.get(alert, :last_push_notification_timestamp) != original_lpnt

        assert DateTime.compare(
                 alert.last_push_notification_timestamp,
                 alert.last_modified_timestamp
               ) == :eq
      end
    end
  end
end
