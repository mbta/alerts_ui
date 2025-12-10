defmodule AlertsUIWeb.FormComponents.SubmitTest do
  @moduledoc false
  use AlertsUIWeb.ConnCase

  import Mock
  import Phoenix.LiveViewTest
  import Test.Support.Helpers

  alias MBTAV3API.RoutePatterns.Repo, as: RoutePatternsRepo
  alias MBTAV3API.Routes.Repo, as: RoutesRepo
  alias MBTAV3API.Routes.Route
  alias MBTAV3API.Stops.Repo, as: StopsRepo
  alias MBTAV3API.Stops.Stop

  @route_one %Route{sort_order: 1, id: "Blue", name: "route_number_1"}
  @route_two %Route{sort_order: 2, id: "Bluer", name: "route_number_2"}
  @routes [@route_one, @route_two]
  @stop %Stop{id: "place-aqucl", name: "Aquarium"}

  describe "save flow" do
    # The save view involves communicating with the LiveView so all tests
    # will need to be e2e
    @tag :logged_in_user
    test "clicking review before filling out form doesn't show modal", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/new")

      get_to_submission_page(view, "Bus", "Delay")
      open_review_modal(view)

      assert view |> element("#error-flash") |> render() =~ "Select stop(s)"
    end

    # These tests also don't show JS, so I can't check that the modal is actually unhidden
    # only that it is rendered when it wasn't before
    @tag :logged_in_user
    test "clicking review after filling out form opens the review modal", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _types -> @routes end,
           get: fn _id -> @route_one end
         ]},
        {StopsRepo, [],
         [
           by_route: fn _route, _direction -> [@stop] end,
           get: fn _id -> @stop end
         ]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/new")

        get_to_submission_page(view, "Bus", "Delay")

        view
        |> element("#service_form")
        |> render_change(%{
          affected_service: %{
            route_ids: ["Blue"],
            stop_ids: ["place-aqucl"]
          }
        })

        view
        |> element("#details_form")
        |> render_change(%{
          alert_details: %{
            header_text: "hello world"
          }
        })

        refute view |> has_element?("#review-modal-container")

        open_review_modal(view)

        assert view |> has_element?("#review-modal-container")
      end
    end

    @tag :logged_in_user
    test "clicking cancel on review modal just closes the modal", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _types -> @routes end,
           get: fn _id -> @route_one end
         ]},
        {StopsRepo, [],
         [
           by_route: fn _route, _direction -> [@stop] end,
           get: fn _id -> @stop end
         ]}
      ]) do
        # --- Same as before ---
        {:ok, view, _html} = live(conn, "/alerts/new")

        get_to_submission_page(view, "Bus", "Delay")

        view
        |> element("#service_form")
        |> render_change(%{
          affected_service: %{
            route_ids: ["Blue"],
            stop_ids: ["place-aqucl"]
          }
        })

        view
        |> element("#details_form")
        |> render_change(%{
          alert_details: %{
            header_text: "hello world"
          }
        })

        open_review_modal(view)

        # --- New stuff ---
        view
        |> element("button", "Keep editing")
        |> render_click()

        refute view |> has_element?("#review-modal-container")
      end
    end

    # This seems unnecessary, but I was having issues with it, so let's just be sure it works
    @tag :logged_in_user
    test "clicking ESC on preview and opening it again works fine", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _types -> @routes end,
           get: fn
             "Blue" -> @route_one
             "Bluer" -> @route_two
           end
         ]},
        {StopsRepo, [],
         [
           by_route: fn _route, _direction -> [@stop] end,
           get: fn _id -> @stop end
         ]}
      ]) do
        # --- Same as before ---
        {:ok, view, _html} = live(conn, "/alerts/new")

        get_to_submission_page(view, "Bus", "Delay")

        view
        |> element("#service_form")
        |> render_change(%{
          affected_service: %{
            route_ids: ["Blue"],
            stop_ids: ["place-aqucl"]
          }
        })

        view
        |> element("#details_form")
        |> render_change(%{
          alert_details: %{
            header_text: "hello world"
          }
        })

        open_review_modal(view)

        # --- New stuff ---
        view
        |> element("#review-modal-container")
        |> render_keydown()

        refute view |> has_element?("#review-modal-container")

        view
        |> element("button#review", "Review and submit")
        |> render_click()

        assert view |> has_element?("#review-modal-container")
      end
    end

    @tag :logged_in_user
    test "clicking submit on review modal redirects to list page and adds alert to db", %{
      conn: conn
    } do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _types -> @routes end,
           get: fn _ -> @route_one end,
           get: fn _, _ -> @route_one end
         ]},
        {StopsRepo, [],
         [
           by_route: fn _route, _direction -> [@stop] end,
           get: fn _id -> @stop end
         ]},
        {RoutePatternsRepo, [],
         [
           included_stops_by_route_id: fn _route_id, _direction -> [] end,
           by_route_id: fn _route_id, _opts -> [] end
         ]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/new")

        get_to_submission_page(view, "Bus", "Delay")

        view
        |> element("#service_form")
        |> render_change(%{
          affected_service: %{
            route_ids: ["Blue"],
            stop_names_and_ids: ["Aquarium|place-aqucl"]
          }
        })

        view
        |> element("#details_form")
        |> render_change(%{
          alert_details: %{
            header_text: "hello world"
          }
        })

        open_review_modal(view)

        view
        |> element("#review-modal-container button", "Submit")
        |> render_click()

        # query the db
        flash = assert_redirect(view, "/")
        assert flash["info"] =~ ~r/New alert #[0-9]+ created/

        alert_id =
          flash["info"]
          |> String.replace("New alert #", "")
          |> String.replace(" created", "")

        assert %AlertsUI.Models.Alert{
                 id: _,
                 alert_id: ^alert_id,
                 effect: :SIGNIFICANT_DELAYS,
                 effect_detail: "DELAY",
                 effect_name: "Delay",
                 banner_text: nil,
                 cause: :UNKNOWN_CAUSE,
                 cause_detail: nil,
                 header_text: "route_number_1 is experiencing delays of about 15 minutes",
                 description_text: nil,
                 severity_level: :WARNING,
                 url: nil,
                 service_effect_text: "route_number_1 delay",
                 short_header_text: nil,
                 severity: 4,
                 created_timestamp: _,
                 last_modified_timestamp: nil,
                 last_push_notification_timestamp: _,
                 closed_timestamp: nil,
                 timeframe_text: nil,
                 recurrence_text: nil,
                 alert_lifecycle: nil,
                 duration_certainty: :ESTIMATED,
                 reminder_times: [],
                 active_period: [
                   %AlertsUI.Models.ActivePeriod{
                     id: _,
                     alert_id: _,
                     alert: _,
                     start: _,
                     end: _,
                     created_at: _,
                     updated_at: _
                   }
                 ],
                 active_period_start: _,
                 active_period_end: _,
                 image_url: nil,
                 image_alternative_text: nil,
                 tts_header_text: nil,
                 tts_description_text: nil,
                 informed_entity: [
                   %AlertsUI.Models.InformedEntity{
                     id: _,
                     alert_id: _,
                     alert: _,
                     agency_id: "1",
                     route_id: "Blue",
                     facility_id: nil,
                     route_type: 3,
                     direction_id: nil,
                     stop_id: "place-aqucl",
                     activities: [:BOARD, :EXIT, :RIDE],
                     trip: nil,
                     created_at: _,
                     updated_at: _
                   }
                 ],
                 draft: false,
                 notification_period_start: _,
                 recurrence_days: [],
                 original_route_selections: ["route_number_1|Blue"],
                 created_at: _,
                 updated_at: _
               } = AlertsUI.Alerts.get_by_alert_id(alert_id)
      end
    end
  end

  describe "other navigation events" do
    @tag :logged_in_user
    test "back button returns to previous step", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/new")

      get_to_submission_page(view, "Bus", "Delay")

      view
      |> element("button#back")
      |> render_click()

      assert has_element?(view, "#route_types_form", "Service Type")
    end

    @tag :logged_in_user
    test "cancel button returns to alerts list page", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/new")

      get_to_submission_page(view, "Bus", "Delay")

      {:ok, new_view, _} =
        view
        |> element("button#cancel")
        |> render_click()
        |> follow_redirect(conn)

      assert has_element?(new_view, "#alert-filter-form")
    end
  end
end
