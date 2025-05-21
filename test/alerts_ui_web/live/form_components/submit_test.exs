defmodule AlertsUIWeb.FormComponents.SubmitTest do
  @moduledoc false
  use AlertsUIWeb.ConnCase

  import Mock
  import Phoenix.LiveViewTest
  alias MBTAV3API.RoutePatterns.Repo, as: RoutePatternsRepo

  alias MBTAV3API.Routes.Repo, as: RoutesRepo
  alias MBTAV3API.Routes.Route
  alias MBTAV3API.Stops.Repo, as: StopsRepo
  alias MBTAV3API.Stops.Stop

  @route_one %Route{sort_order: 1, id: "Blue", name: "route_number_1"}
  @route_two %Route{sort_order: 2, id: "Bluer", name: "route_number_2"}
  @routes [@route_one, @route_two]
  @stop %Stop{id: "place-aqucl", name: "Aquarium"}

  def get_to_submission_page(view) do
    # Use any combo to proceed to next page
    view
    |> element("#route_types_form button", "Bus")
    |> render_click()

    view
    |> element("#route_types_form button", "Delay")
    |> render_click()

    view
    |> element("#route_types_form")
    |> render_submit()
  end

  describe "save flow" do
    # The save view involves communicating with the LiveView so all tests
    # will need to be e2e
    @tag :logged_in_user
    test "clicking review before filling out form doesn't show modal", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/new")

      get_to_submission_page(view)

      view
      |> element("button#review")
      |> render_click()

      assert view |> element("#error-flash") |> render() =~ "Select stop(s)"
    end

    # These tests also don't show JS, so I can't check that the modal is actually unhidden
    # only that it is rendered when it wasn't before
    @tag :logged_in_user
    test "clicking review after filling out form opens the review modal", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [], [by_type: fn _types -> @routes end]},
        {StopsRepo, [], [by_route: fn _route, _direction -> [@stop] end]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/new")

        get_to_submission_page(view)

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

        view
        |> element("button#review", "Review and submit")
        |> render_click()

        assert view |> has_element?("#review-modal-container")
      end
    end

    @tag :logged_in_user
    test "clicking cancel on review modal just closes the modal", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [], [by_type: fn _types -> @routes end]},
        {StopsRepo, [], [by_route: fn _route, _direction -> [@stop] end]}
      ]) do
        # --- Same as before ---
        {:ok, view, _html} = live(conn, "/alerts/new")

        get_to_submission_page(view)

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

        view
        |> element("button#review", "Review and submit")
        |> render_click()

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
        {RoutesRepo, [], [by_type: fn _types -> @routes end]},
        {StopsRepo, [], [by_route: fn _route, _direction -> [@stop] end]}
      ]) do
        # --- Same as before ---
        {:ok, view, _html} = live(conn, "/alerts/new")

        get_to_submission_page(view)

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

        view
        |> element("button#review", "Review and submit")
        |> render_click()

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
    test "clicking submit on review modal sends a :create_alert event", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _types -> @routes end,
           get: fn _, _ -> @route_one end
         ]},
        {StopsRepo, [], [by_route: fn _route, _direction -> [@stop] end]},
        {RoutePatternsRepo, [],
         [
           included_stops_by_route_id: fn _route_id, _direction -> [] end,
           by_route_id: fn _route_id, _opts -> [] end
         ]}
      ]) do
        # --- Same as before ---
        {:ok, view, _html} = live(conn, "/alerts/new")

        get_to_submission_page(view)

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

        view
        |> element("button#review", "Review and submit")
        |> render_click()

        # --- New stuff ---
        view
        |> element("button", "Submit")
        |> render_click()

        assert render_async(view) =~ "created successfully"
      end
    end
  end

  describe "other navigation events" do
    @tag :logged_in_user
    test "back button returns to previous step", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/new")

      get_to_submission_page(view)

      view
      |> element("button#back")
      |> render_click()

      assert has_element?(view, "#route_types_form", "Service Type")
    end

    @tag :logged_in_user
    test "cancel button returns to alerts list page", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/new")

      get_to_submission_page(view)

      {:ok, new_view, _} =
        view
        |> element("button#cancel")
        |> render_click()
        |> follow_redirect(conn)

      assert has_element?(new_view, "article #alert-filter-form")
    end
  end
end
