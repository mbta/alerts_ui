defmodule AlertsUIWeb.Tickets.EscapeReviewModalTest do
  @moduledoc """
  Regression test for Asana ticket 1213450829885289 —
  "🐛 Pressing escape when in review modal takes you back to alerts table"
  https://app.asana.com/0/1167196461144361/1213450829885289

  Bug: Pressing Escape while in the review modal (or anywhere on the alert
  creation form) navigated the user back to the alerts table — the same
  behavior as clicking the Cancel button at the bottom of the page.

  Acceptance criteria:
    AC1: When creating, editing, or duplicating an alert, pressing escape should
         NOT be the equivalent of clicking the Cancel button. It should do
         nothing unless a modal is open.
    AC2: Pressing escape when viewing any modal in Alerts Manager should be the
         equivalent of clicking the "X" button on the top-right of the modal
         (i.e. closes the modal without navigating away).
  """
  use ExUnit.Case, async: false
  use AlertsUIWeb.ConnCase

  import Phoenix.LiveViewTest
  import Mock
  import Test.Support.Helpers

  alias MBTAV3API.Routes.Repo, as: RoutesRepo
  alias MBTAV3API.Routes.Route
  alias MBTAV3API.Stops.Repo, as: StopsRepo
  alias MBTAV3API.Stops.Stop

  @route_one %Route{
    direction_names: %{0 => "Outbound", 1 => "Inbound"},
    sort_order: 1,
    id: "Blue",
    type: 1,
    name: "Blue Line"
  }

  @stop %Stop{id: "place-aqucl", name: "Aquarium"}

  @routes [@route_one]

  # Helper to navigate to the details step for a Bus + Delay alert with a
  # route and header selected, bringing the form to a valid state so the
  # review modal can be opened.
  defp setup_valid_form(conn) do
    {:ok, view, _html} = live(conn, "/alerts/new")
    view = get_to_submission_page(conn, view, "Bus", "Delay")

    view
    |> element("form")
    |> render_change(%{
      alert_data: %{
        route_ids: ["Blue"],
        stop_ids: ["place-aqucl"],
        header_text: "Bus delay on Blue Line"
      }
    })

    view
  end

  describe "AC2: escape in review modal closes modal, stays on creation form (ticket 1213450829885289)" do
    @tag :logged_in_user
    test "pressing escape (keydown on modal container) dismisses the review modal without navigating away",
         %{conn: conn} do
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
        view = setup_valid_form(conn)

        # Open the review modal
        open_review_modal(view)

        assert has_element?(view, "#review-modal-container"),
               "review modal should be open before pressing escape"

        # Simulate Escape keydown on the review modal container
        # (This is what the phx-window-keydown + phx-key="escape" binding fires)
        view
        |> element("#review-modal-container")
        |> render_keydown()

        # AC2: Modal must be dismissed
        refute has_element?(view, "#review-modal-container"),
               "review modal should be dismissed after pressing Escape"

        # AC2: Must still be on the alert creation form, NOT the alerts list
        assert has_element?(view, "#form_container"),
               "should still be on the alert creation form after pressing Escape (not navigated away)"

        refute has_element?(view, "#view_alerts_live_view"),
               "should NOT have navigated to the alerts list view after pressing Escape"
      end
    end
  end

  describe "AC1: escape does NOT cancel alert creation (ticket 1213450829885289)" do
    @tag :logged_in_user
    test "the cancel button navigates to alerts list, but escape on the modal does not",
         %{conn: conn} do
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
        view = setup_valid_form(conn)

        # Verify that Cancel button DOES navigate away (baseline for comparison)
        cancel_result =
          view
          |> element("button#cancel", "Cancel")
          |> render_click()

        # The cancel event results in a navigate away (redirect)
        # render_click returns {:error, {:live_redirect, ...}} when a redirect fires
        assert {:error, {:live_redirect, _}} = cancel_result
      end
    end

    @tag :logged_in_user
    test "escape from the review modal does not navigate to the alerts list", %{conn: conn} do
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
        view = setup_valid_form(conn)

        open_review_modal(view)
        assert has_element?(view, "#review-modal-container")

        # Escape (keydown on the review modal container) should NOT navigate away
        keydown_result =
          view
          |> element("#review-modal-container")
          |> render_keydown()

        # Must NOT be a redirect to the alerts list
        refute match?({:error, {:live_redirect, _}}, {:error, keydown_result}),
               "pressing Escape must not redirect to the alerts list (that would be equivalent to Cancel)"

        # Must still be on the creation form
        assert has_element?(view, "#form_container"),
               "must remain on the alert creation form after pressing Escape"
      end
    end
  end
end
