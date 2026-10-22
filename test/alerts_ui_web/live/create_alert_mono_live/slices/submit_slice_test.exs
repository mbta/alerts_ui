defmodule AlertsUIWeb.CreateAlertMonoLive.SubmitSliceTest do
  use ExUnit.Case, async: false
  use AlertsUIWeb.ConnCase

  import Mock
  import Phoenix.LiveViewTest
  import Test.Support.Helpers

  alias MBTAV3API.RoutePatterns.Repo, as: RoutePatternsRepo
  alias MBTAV3API.Routes.Repo, as: RoutesRepo
  alias MBTAV3API.Routes.Route
  alias MBTAV3API.Schedules.Repo, as: SchedulesRepo
  alias MBTAV3API.Stops.Repo, as: StopsRepo
  alias MBTAV3API.Stops.Stop

  @route_one %Route{sort_order: 1, id: "Blue", name: "route_number_1", type: 3}
  @route_two %Route{sort_order: 2, id: "Bluer", name: "route_number_2", type: 3}
  @routes [@route_one, @route_two]
  @stop %Stop{id: "place-aqucl", name: "Aquarium"}

  describe "Cancel button" do
    @tag :logged_in_user
    test "navigates away from the mono flow when clicked", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/new/bus/delay")

      assert has_element?(view, "#cancel")

      view |> element("#cancel") |> render_click()

      assert_redirect(view, "/alerts?")
    end
  end

  describe "save flow" do
    # The save view involves communicating with the LiveView so all tests
    # will need to be e2e

    @tag :logged_in_user
    test "clicking review before filling out form doesn't show modal", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/new/")

      view = get_to_submission_page(conn, view, "Bus", "Delay")
      render_async(view, 1000)
      open_review_modal(view)
      assert view |> element("#flash") |> render() =~ "Please fix the following errors"
    end

    # These tests also don't show JS, so I can't check that the modal is actually unhidden
    # only that it is rendered when it wasn't before
    @tag :logged_in_user
    test "clicking review after filling out form opens the review modal", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _types -> @routes end,
           get: fn _id -> @route_one end,
           get: fn _id, _opts -> @route_one end
         ]},
        {StopsRepo, [],
         [
           by_route: fn _route, _direction, _opts -> [@stop] end,
           get: fn _id -> @stop end
         ]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/new")

        view = get_to_submission_page(conn, view, "Bus", "Delay")

        view
        |> element("form")
        |> render_change(%{
          alert_data: %{
            route_ids: ["Blue"],
            stop_ids: ["place-aqucl"],
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
           get: fn _id -> @route_one end,
           get: fn _id, _opts -> @route_one end
         ]},
        {StopsRepo, [],
         [
           by_route: fn _route, _direction, _opts -> [@stop] end,
           get: fn _id -> @stop end
         ]}
      ]) do
        # --- Same as before ---
        {:ok, view, _html} = live(conn, "/alerts/new")

        view = get_to_submission_page(conn, view, "Bus", "Delay")

        view
        |> element("form")
        |> render_change(%{
          alert_data: %{
            route_ids: ["Blue"],
            stop_ids: ["place-aqucl"],
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
           end,
           get: fn
             "Blue", _ -> @route_one
             "Bluer", _ -> @route_two
           end
         ]},
        {StopsRepo, [],
         [
           by_route: fn _route, _direction, _opts -> [@stop] end,
           get: fn _id -> @stop end
         ]}
      ]) do
        # --- Same as before ---
        {:ok, view, _html} = live(conn, "/alerts/new")

        view = get_to_submission_page(conn, view, "Bus", "Delay")

        view
        |> element("form")
        |> render_change(%{
          alert_data: %{
            route_ids: ["Blue"],
            stop_ids: ["place-aqucl"],
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
        {SchedulesRepo, [], [by_route_ids: fn _route_ids, _opts -> [] end]},
        {RoutesRepo, [],
         [
           by_type: fn _types -> @routes end,
           get: fn _ -> @route_one end,
           get: fn _, _ -> @route_one end
         ]},
        {StopsRepo, [],
         [
           all: fn _, _ -> [@stop] end,
           by_route: fn _route, _direction, _opts -> [@stop] end,
           get: fn _id -> @stop end
         ]},
        {RoutePatternsRepo, [],
         [
           included_stops_by_route_id: fn _route_id, _direction -> [] end,
           by_route_id: fn _route_id, _opts -> [] end
         ]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/new")

        view = get_to_submission_page(conn, view, "Bus", "Delay")

        view
        |> element("form")
        |> render_change(%{
          _target: [:foo, :bar],
          alert_data: %{
            route_ids: ["Blue"]
          }
        })

        todays_date =
          DateTime.utc_now()
          |> DateTime.shift_zone!("America/New_York")
          |> DateTime.to_date()

        tomorrows_date = Date.add(todays_date, 1)

        active_period_start = NaiveDateTime.new!(tomorrows_date, ~T[03:00:00])

        active_period_end =
          tomorrows_date
          |> Date.add(1)
          |> NaiveDateTime.new!(~T[03:00:00])

        view
        |> element("form")
        |> render_change(%{
          _target: [:foo, :bar],
          alert_data: %{
            stop_names_and_ids: ["Aquarium (outbound)|place-aqucl"],
            active_period_start_specifier: :start_of_service,
            active_period_end_specifier: :end_of_service,
            active_period_start_date: tomorrows_date |> Date.to_iso8601(),
            active_period_end_date: tomorrows_date |> Date.to_iso8601()
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

        expected_start =
          active_period_start
          |> DateTime.from_naive!("America/New_York")
          |> DateTime.shift_zone!("Etc/UTC")

        expected_end =
          active_period_end
          |> DateTime.from_naive!("America/New_York")
          |> DateTime.shift_zone!("Etc/UTC")

        assert %AlertsUI.Models.Alert{
                 id: _,
                 alert_id: ^alert_id,
                 effect: :OTHER_EFFECT,
                 effect_detail: "DELAY",
                 effect_name: "Delay",
                 banner_text: nil,
                 cause: :UNKNOWN_CAUSE,
                 cause_detail: nil,
                 header_text: "route_number_1 will be experiencing delays of about 15 minutes.",
                 description_text: "Affected outbound stops:\nAquarium",
                 severity_level: :WARNING,
                 url: nil,
                 service_effect_text: "route_number_1 delay",
                 short_header_text: nil,
                 severity: 4,
                 created_timestamp: _,
                 last_modified_timestamp: _,
                 last_push_notification_timestamp: _,
                 closed_timestamp: nil,
                 timeframe_text: nil,
                 recurrence_text: nil,
                 alert_lifecycle: nil,
                 duration_certainty: :KNOWN,
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
                 active_period_start: ^expected_start,
                 active_period_end: ^expected_end,
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
    test "'select alert type' button returns to previous step", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/new")

      view = get_to_submission_page(conn, view, "Bus", "Delay")

      view
      |> element("button#select-alert-type")
      |> render_click()

      assert render(view) =~ ~s(Service Type)
    end

    @tag :logged_in_user
    test "cancel button returns to alerts list page", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/new")

      view = get_to_submission_page(conn, view, "Bus", "Delay")

      {:ok, new_view, _} =
        view
        |> element("button#cancel")
        |> render_click()
        |> follow_redirect(conn)

      assert has_element?(new_view, "#view_alerts_live_view")
    end
  end
end
