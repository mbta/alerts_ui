defmodule AlertsUIWeb.CreateAlertMonoLive.Slices.StopRouteServiceSliceTest do
  use ExUnit.Case, async: false
  use AlertsUIWeb.ConnCase
  import AlertsUI.Support.Factory
  import Ecto.Changeset
  import Phoenix.LiveViewTest
  import Mock
  import Test.Support.Helpers
  alias AlertsUIWeb.CreateAlertMonoLive.Slices.StopRouteServiceSlice
  alias AlertsUI.Alerts
  alias MBTAV3API.Routes.Repo, as: RoutesRepo
  alias MBTAV3API.Routes.Route
  alias MBTAV3API.Schedules.Repo, as: SchedulesRepo
  alias MBTAV3API.Stops.Repo, as: StopsRepo
  alias MBTAV3API.Stops.Stop

  describe "stop_id_options/5 preservation logic" do
    test "a stop that was selected but is no longer in available_stops disappears when selected_stops is empty" do
      available_stops = [%Stop{id: "place-dwnxg", name: "Downtown Crossing"}]

      options =
        StopRouteServiceSlice.stop_id_options(
          available_stops,
          [],
          nil,
          1,
          ["place-pktrm"]
        )

      option_values = Enum.map(options, &Keyword.get(&1, :value))

      refute "place-pktrm" in option_values,
             "Expected Park Street to be absent from options, but it appeared — " <>
               "this would mean preservation is working, disproving the hypothesis"
    end

    test "a stop that was selected IS preserved when it is present in selected_stops" do
      park_street = %Stop{id: "place-pktrm", name: "Park Street"}
      available_stops = [%Stop{id: "place-dwnxg", name: "Downtown Crossing"}]

      options =
        StopRouteServiceSlice.stop_id_options(
          available_stops,
          [park_street],
          nil,
          1,
          ["place-pktrm"]
        )

      option_values = Enum.map(options, &Keyword.get(&1, :value))

      assert "place-pktrm" in option_values,
        "Expected Park Street to be preserved in options when selected_stops is populated"
    end
  end

  # Subway routes (type 1) for "Station Closure" → combination :SR
  @route %Route{sort_order: 1, id: "Blue", name: "Blue Line", type: 1}
  @route_two %Route{sort_order: 2, id: "Red", name: "Red Line", type: 1}
  @shuttle_route %Route{
    sort_order: 99,
    id: "Shuttle-BlueLine",
    name: "Blue Line Shuttle",
    description: :rail_replacement_bus,
    type: 1
  }
  @stop %Stop{id: "place-aqucl", name: "Aquarium"}
  @stop_two %Stop{id: "place-pktrm", name: "Park Street"}

  defp base_mocks do
    [
      {RoutesRepo, [],
       [
         by_type: fn _ -> [@route] end,
         by_stop: fn _ -> [@route] end,
         by_stop: fn _, _ -> [@route] end
       ]},
      {StopsRepo, [],
       [
         by_route_type: fn _, _ -> [@stop] end,
         by_route: fn _, _, _ -> [@stop] end
       ]}
    ]
  end

  describe "component" do
    @tag :logged_in_user
    test "renders", %{conn: conn} do
      with_mocks(base_mocks()) do
        {:ok, view, _html} = live(conn, "/alerts/mono/new")
        get_to_submission_page_refactor(view, "Subway", "Station Closure")
        render_async(view)
        assert render(view) =~ ~s(id="stop_route_service_view")
      end
    end

    @tag :logged_in_user
    test "shuttle routes are filtered out of routes filter list", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _ -> [@route, @shuttle_route] end,
           by_stop: fn _ -> [@route, @shuttle_route] end,
           by_stop: fn _, _ -> [@route, @shuttle_route] end
         ]},
        {StopsRepo, [],
         [
           by_route_type: fn _, _ -> [@stop] end,
           by_route: fn _, _, _ -> [@stop] end
         ]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/mono/new")
        get_to_submission_page_refactor(view, "Subway", "Station Closure")
        render_async(view)

        refute render(view) =~ "Shuttle"
      end
    end

    @tag :logged_in_user
    test "stop search works", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _ -> [@route, @route_two] end,
           by_stop: fn _ -> [@route, @route_two] end,
           by_stop: fn _, _ -> [@route, @route_two] end
         ]},
        {StopsRepo, [],
         [
           by_route_type: fn _, _ -> [@stop, @stop_two] end,
           by_route: fn _, _, _ -> [@stop, @stop_two] end
         ]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/mono/new")
        get_to_submission_page_refactor(view, "Subway", "Station Closure")
        render_async(view)

        {:ok, document} = view |> render() |> Floki.parse_document()
        assert Test.Support.Helpers.document_has_element?(document, "option[value=\"place-aqucl\"]")
        assert Test.Support.Helpers.document_has_element?(document, "option[value=\"place-pktrm\"]")

        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "stop_search_term"],
          "alert_data" => %{"stop_search_term" => "Aqua"}
        })

        render_async(view)

        {:ok, document} = view |> render() |> Floki.parse_document()
        assert Test.Support.Helpers.document_has_element?(document, "option[value=\"place-aqucl\"]")
        refute Test.Support.Helpers.document_has_element?(document, "option[value=\"place-pktrm\"]")
      end
    end

    @tag :logged_in_user
    test "stop search can clear", %{conn: conn} do
      with_mocks(base_mocks()) do
        {:ok, view, _html} = live(conn, "/alerts/mono/new")
        get_to_submission_page_refactor(view, "Subway", "Station Closure")
        render_async(view)

        {:ok, document} = view |> render() |> Floki.parse_document()

        assert Test.Support.Helpers.document_has_element?(
                 document,
                 "option[value=\"place-aqucl\"]"
               )

        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "stop_search_term"],
          "alert_data" => %{"stop_search_term" => "x"}
        })

        render_async(view)

        {:ok, document} = view |> render() |> Floki.parse_document()

        refute Test.Support.Helpers.document_has_element?(
                 document,
                 "option[value=\"place-aqucl\"]"
               )

        render_click(view, "reset_search_filter", %{"name" => "alert_data[stop_search_term]"})
        render_async(view)

        {:ok, document} = view |> render() |> Floki.parse_document()

        assert Test.Support.Helpers.document_has_element?(
                 document,
                 "option[value=\"place-aqucl\"]"
               )
      end
    end

    @tag :logged_in_user
    test "modal route search works", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _ -> [@route, @route_two] end,
           by_stop: fn _ -> [@route, @route_two] end,
           by_stop: fn _, _ -> [@route, @route_two] end
         ]},
        {StopsRepo, [],
         [
           by_route_type: fn _, _ -> [@stop] end,
           by_route: fn _, _, _ -> [@stop] end
         ]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/mono/new")
        get_to_submission_page_refactor(view, "Subway", "Station Closure")
        render_async(view)

        {:ok, document} = view |> render() |> Floki.parse_document()

        assert Test.Support.Helpers.document_has_element?(
                 document,
                 "select#alert_data_modal_route_id > option[value=\"Blue\"]"
               )

        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "modal_route_search_term"],
          "alert_data" => %{"modal_route_search_term" => "Red"}
        })

        render_async(view)

        {:ok, document} = view |> render() |> Floki.parse_document()

        refute Test.Support.Helpers.document_has_element?(
                 document,
                 "select#alert_data_modal_route_id > option[value=\"Blue\"]"
               )

        assert Test.Support.Helpers.document_has_element?(
                 document,
                 "select#alert_data_modal_route_id > option[value=\"Red\"]"
               )
      end
    end

    @tag :logged_in_user
    test "modal route search can clear", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _ -> [@route, @route_two] end,
           by_stop: fn _ -> [@route, @route_two] end,
           by_stop: fn _, _ -> [@route, @route_two] end
         ]},
        {StopsRepo, [],
         [
           by_route_type: fn _, _ -> [@stop] end,
           by_route: fn _, _, _ -> [@stop] end
         ]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/mono/new")
        get_to_submission_page_refactor(view, "Subway", "Station Closure")
        render_async(view)

        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "modal_route_search_term"],
          "alert_data" => %{"modal_route_search_term" => "Red"}
        })

        render_async(view)

        {:ok, document} = view |> render() |> Floki.parse_document()

        refute Test.Support.Helpers.document_has_element?(
                 document,
                 "select#alert_data_modal_route_id > option[value=\"Blue\"]"
               )

        render_click(view, "reset_search_filter", %{
          "name" => "alert_data[modal_route_search_term]"
        })

        render_async(view)

        {:ok, document} = view |> render() |> Floki.parse_document()

        assert Test.Support.Helpers.document_has_element?(
                 document,
                 "select#alert_data_modal_route_id > option[value=\"Blue\"]"
               )
      end
    end

    @tag :logged_in_user
    test "add route filter on stops works", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _ -> [@route, @route_two] end,
           by_stop: fn _ -> [@route, @route_two] end,
           by_stop: fn _, _ -> [@route, @route_two] end
         ]},
        {StopsRepo, [],
         [
           by_route_type: fn _, _ -> [@stop, @stop_two] end,
           by_route: fn
             "Blue", _, _ -> [@stop]
             _, _, _ -> [@stop, @stop_two]
           end
         ]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/mono/new")
        get_to_submission_page_refactor(view, "Subway", "Station Closure")
        render_async(view)

        assert render(view) =~ "place-aqucl"
        assert render(view) =~ "place-pktrm"

        # Set modal route filter
        view
        |> element("form")
        |> render_change(%{
          "alert_data" => %{"modal_route_id" => "Blue"}
        })

        render_click(view, "accept_filter")
        render_async(view)

        assert render(view) =~ ~s(Filter: Blue Line)
        assert render(view) =~ "place-aqucl"
        refute render(view) =~ "place-pktrm"
      end
    end

    @tag :logged_in_user
    test "clear route filter works", %{conn: conn} do
      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _ -> [@route, @route_two] end,
           by_stop: fn _ -> [@route, @route_two] end,
           by_stop: fn _, _ -> [@route, @route_two] end
         ]},
        {StopsRepo, [],
         [
           by_route_type: fn _, _ -> [@stop, @stop_two] end,
           by_route: fn
             "Blue", _, _ -> [@stop]
             _, _, _ -> [@stop, @stop_two]
           end
         ]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/mono/new")
        get_to_submission_page_refactor(view, "Subway", "Station Closure")
        render_async(view)

        # Apply route filter
        view
        |> element("form")
        |> render_change(%{"alert_data" => %{"modal_route_id" => "Blue"}})

        render_click(view, "accept_filter")
        render_async(view)

        assert render(view) =~ ~s(Filter: Blue Line)

        # Clear filter
        render_click(view, "clear_filter", %{"filter-id" => "routes-filter-modal"})
        render_async(view)

        assert render(view) =~ ~s(Filter: All routes)
        assert render(view) =~ "place-pktrm"
      end
    end

    @tag :logged_in_user
    test "works correctly if editing", %{conn: conn} do
      alert_params =
        build(:alert_map, %{
          alert_id: "test-sr-edit",
          effect: :NO_SERVICE,
          effect_detail: "STATION_CLOSURE",
          effect_name: "Station Closure",
          primary_service_type: "1",
          informed_entity: [
            %{route_type: 1, stop_id: "place-aqucl", route_id: "Blue"}
          ],
          original_stop_selections: ["place-aqucl"],
          original_route_selections: ["Blue Line|Blue"]
        })

      {:ok, _} = Alerts.create_or_update_alert(alert_params, build(:user))

      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _ -> [@route] end,
           get: fn _ -> @route end,
           get: fn _, _ -> @route end,
           by_stop: fn _ -> [@route] end,
           by_stop: fn _, _ -> [@route] end
         ]},
        {StopsRepo, [],
         [
           by_route_type: fn _, _ -> [@stop] end,
           by_route: fn _, _, _ -> [@stop] end,
           get_parent: fn _ -> @stop end
         ]},
        {SchedulesRepo, [],
         [
           by_route_ids: fn _, _ -> [] end,
           end_of_rating: fn -> Date.utc_today() end
         ]}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/mono/edit/test-sr-edit")
        render_async(view)

        {:ok, document} = view |> render() |> Floki.parse_document()

        assert Test.Support.Helpers.document_has_element?(
                 document,
                 "option[value=\"place-aqucl\"][selected=\"selected\"]"
               )
      end
    end

    @tag :logged_in_user
    test "review modal shows errors when stop and route not selected", %{conn: conn} do
      with_mocks(base_mocks()) do
        {:ok, view, _html} = live(conn, "/alerts/mono/new")
        get_to_submission_page_refactor(view, "Subway", "Station Closure")
        render_async(view)

        view |> element("button#review", "Review and submit") |> render_click()

        refute has_element?(view, "#review-modal-container")
        assert render(view) =~ "Please fix the following errors"
      end
    end
  end
end
