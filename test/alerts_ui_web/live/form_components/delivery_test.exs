defmodule AlertsUIWeb.FormComponents.DeliveryTest do
  @moduledoc false
  use AlertsUIWeb.ConnCase

  import LiveIsolatedComponent
  import Mock
  import AlertsUI.Support.Factory
  import Phoenix.LiveViewTest
  import Test.Support.Helpers

  alias AlertsUI.Alerts
  alias AlertsUIWeb.FormComponents.{Delivery, RouteTypeAndEffect}
  alias AlertsUIWeb.Step
  alias MBTAV3API.RoutePatterns.Repo, as: RoutePatternsRepo
  alias MBTAV3API.Routes.Repo, as: RoutesRepo
  alias MBTAV3API.Routes.Route

  @assigns %{
    id: "delivery",
    progress: %Step{
      name: "details",
      previous: "route_type_and_effect",
      next: "success",
      label: "Alert Details"
    },
    route_type: 1,
    alert_data: %{}
  }

  @route %Route{
    direction_names: %{0 => "Westbound", 1 => "Eastbound"},
    sort_order: 3,
    id: "Red",
    type: 1,
    name: "Red Line"
  }

  describe "component" do
    test "renders" do
      assert render_component(Delivery, @assigns) =~ ~s(id="delivery_form")
    end

    test "banner text is hidden if checkbox is not checked" do
      {:ok, view, _html} = live_isolated_component(Delivery, @assigns)

      refute view
             |> element("div#banner_div")
             |> render() =~ ~s(id=\"banner-container\")

      view
      |> element("form")
      |> render_change(%{
        "delivery" => %{
          "view_banner" => "true"
        }
      })

      assert view
             |> element("div#banner_div")
             |> render() =~ ~s(id=\"banner-container\">)
    end

    test "banner text syncs with header text" do
      {:ok, view, _html} =
        live_isolated_component(
          Delivery,
          @assigns
          |> Map.put(:alert_data, %{header_text: "example_header_text", view_banner: true})
        )

      assert view
             |> element("div#banner_div")
             |> render() =~ ~s(example_header_text)
    end
  end

  @tag :logged_in_user
  test "banner text does not secretly get filled in when unselecting email box", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/alerts/new")

    send(
      view.pid,
      {:step_completed, %RouteTypeAndEffect{route_type: 3, effect_name: "Detour"}}
    )

    view
    |> element("#details_form")
    |> render_change(%{
      "alert_details" => %{
        "header_text" => "header text"
      }
    })

    view
    |> element("#notification-toggle")
    |> render_change(%{
      "delivery" => %{
        "notification_toggle" => "false"
      }
    })

    view
    |> element("button#review", "Review and submit")
    |> render_click()

    refute view
           |> render() =~ ~s(Check box to show you understand)
  end

  test "renders correctly while editing" do
    alert_data = %{
      banner_text: "my banner text"
    }

    assigns = @assigns |> Map.merge(%{alert_data: alert_data, form_type: :editing})

    {:ok, view, _html} = live_isolated_component(Delivery, assigns)

    assert view
           |> element("div#banner_div")
           |> render() =~ ~s(id=\"banner-container\">)

    assert view
           |> element("div#banner_div")
           |> render() =~ ~s(my banner text)
  end

  describe "end-to-end" do
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
         ]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/new")

        get_to_submission_page(view, "Subway", "Extra service")
        render_async(view)

        # Mock selecting Red line
        view
        |> element("#service_form")
        |> render_change(%{
          affected_service: %{route_ids: ["Red"]}
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
         ]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/new")

        get_to_submission_page(view, "Subway", "Extra service")
        render_async(view)

        # Mock selecting Red line
        view
        |> element("#service_form")
        |> render_change(%{
          affected_service: %{route_ids: ["Red"]}
        })

        # unselect notification toggle
        view
        |> element("#notification-toggle")
        |> render_change(%{
          "delivery" => %{
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

        {:ok, view, _html} = live(conn, "/alerts/edit?alert_id=123")
        render_async(view)

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

        {:ok, view, _html} = live(conn, "/alerts/edit?alert_id=123")
        render_async(view)

        view
        |> element("#notification-toggle")
        |> render_change(%{
          "delivery" => %{
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

        {:ok, view, _html} = live(conn, "/alerts/edit?alert_id=123")
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
