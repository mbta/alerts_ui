defmodule AlertsUIWeb.CreateAlertMonoLive.SubmitSliceTest do
  use ExUnit.Case, async: false
  use AlertsUIWeb.ConnCase

  import Mock
  import Phoenix.LiveViewTest
  import Test.Support.Helpers

  alias AlertsUI.Alerts
  alias MBTAV3API.RoutePatterns.Repo, as: RoutePatternsRepo
  alias MBTAV3API.Routes.Repo, as: RoutesRepo
  alias MBTAV3API.Routes.Route
  alias MBTAV3API.Schedules.Repo, as: SchedulesRepo
  alias MBTAV3API.Stops.Repo, as: StopsRepo
  alias MBTAV3API.Stops.Stop

  @route %Route{sort_order: 1, id: "Blue", name: "Blue Route", type: 3}
  @stop %Stop{id: "place-aqucl", name: "Aquarium"}

  defp base_mocks do
    [
      {RoutesRepo, [],
       [
         by_type: fn _ -> [@route] end,
         get: fn _ -> @route end,
         get: fn _, _ -> @route end
       ]},
      {StopsRepo, [],
       [
         by_route: fn _, _, _ -> [@stop] end,
         get: fn _ -> @stop end
       ]},
      {SchedulesRepo, [], [by_route_ids: fn _, _ -> [] end]},
      {RoutePatternsRepo, [],
       [
         by_route_id: fn _, _ -> [] end,
         included_stops_by_route_id: fn _, _ -> [] end
       ]}
    ]
  end

  describe "Cancel button" do
    @tag :logged_in_user
    test "navigates away from the mono flow when clicked", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/mono/new/bus/delay")

      assert has_element?(view, "#cancel")

      view |> element("#cancel") |> render_click()

      assert_redirect(view, "/alerts?")
    end
  end

  describe "review modal" do
    @tag :logged_in_user
    test "clicking review before filling out form doesn't show modal", %{conn: conn} do
      with_mocks(base_mocks()) do
        {:ok, view, _html} = live(conn, "/alerts/mono/new")
        get_to_submission_page_refactor(view, "Bus", "Delay")
        render_async(view)

        open_review_modal(view)

        refute has_element?(view, "#review-modal-container")
        assert render(view) =~ "Please fix the following errors"
      end
    end

    @tag :logged_in_user
    test "clicking review after filling out form opens the review modal", %{conn: conn} do
      with_mocks(base_mocks()) do
        {:ok, view, _html} = live(conn, "/alerts/mono/new")
        get_to_submission_page_refactor(view, "Bus", "Delay")
        render_async(view)

        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "route_ids"],
          "alert_data" => %{"route_ids" => ["Blue"]}
        })

        render_async(view)

        refute has_element?(view, "#review-modal-container")
        open_review_modal(view)
        assert has_element?(view, "#review-modal-container")
      end
    end

    @tag :logged_in_user
    test "clicking cancel on review modal closes the modal", %{conn: conn} do
      with_mocks(base_mocks()) do
        {:ok, view, _html} = live(conn, "/alerts/mono/new")
        get_to_submission_page_refactor(view, "Bus", "Delay")
        render_async(view)

        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "route_ids"],
          "alert_data" => %{"route_ids" => ["Blue"]}
        })

        render_async(view)
        open_review_modal(view)
        assert has_element?(view, "#review-modal-container")

        view |> element("button", "Keep editing") |> render_click()

        refute has_element?(view, "#review-modal-container")
      end
    end

    @tag :logged_in_user
    test "clicking submit on review modal redirects and persists the alert", %{conn: conn} do
      with_mocks(base_mocks()) do
        {:ok, view, _html} = live(conn, "/alerts/mono/new")
        get_to_submission_page_refactor(view, "Bus", "Delay")
        render_async(view)

        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "route_ids"],
          "alert_data" => %{"route_ids" => ["Blue"]}
        })

        render_async(view)
        open_review_modal(view)
        assert has_element?(view, "#review-modal-container")

        view |> element("#review-modal-container button", "Submit") |> render_click()

        flash = assert_redirect(view, "/")
        assert flash["info"] =~ ~r/New alert #[0-9]+ created/

        alert_id =
          flash["info"]
          |> String.replace("New alert #", "")
          |> String.replace(" created", "")

        alert = Alerts.get_by_alert_id(alert_id)
        assert alert != nil
        assert Enum.any?(alert.informed_entity, &(&1.route_id == "Blue"))
      end
    end
  end

  describe "navigation" do
    @tag :logged_in_user
    test "back button returns to route type and effect selection", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/mono/new/bus/delay")

      view |> element("button#back") |> render_click()

      assert has_element?(view, "#service_type_buttons")
    end
  end
end
