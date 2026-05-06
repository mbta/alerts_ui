defmodule AlertsUIWeb.FormComponents.AccessAffectedServiceTest do
  @moduledoc false
  use AlertsUIWeb.ConnCase
  import Mock

  import LiveIsolatedComponent
  import Mock
  import Phoenix.LiveViewTest
  import Test.Support.Helpers

  alias AlertsUIWeb.FormComponents.AccessAffectedService
  alias AlertsUIWeb.Step
  alias MBTAV3API.Facilities.Facility
  alias MBTAV3API.Facilities.Repo, as: FacilitiesRepo
  alias MBTAV3API.RoutePatterns.Repo, as: RoutePatternsRepo
  alias MBTAV3API.Stops.Stop

  @assigns %{
    id: "details",
    progress: %Step{
      name: "affected-service",
      previous: "route_type_and_effect",
      next: "success",
      label: "Alert Details"
    },
    alert_data: %{route_type: nil, effect_name: "Bike Issue"},
    form_type: :creating
  }

  @facility %Facility{
    id: "Facility-3",
    long_name: "Example Facility",
    stop: %Stop{id: "place-sstat", name: "South Station"}
  }

  @facility_two %Facility{
    id: "Facility-7",
    long_name: "Example Facility Two",
    stop: %Stop{id: "place-aqucl", name: "Aquarium"}
  }

  @facility_three %Facility{
    id: "Facility-10",
    long_name: "Another Place Entirely",
    stop: %Stop{id: "place-apent", name: "Somewhere Else"}
  }

  describe "component" do
    test "renders" do
      rendered = render_component(AccessAffectedService, @assigns)

      assert rendered =~ ~s(id="access_service_view")
    end

    test "it sends section_completed if no error in changeset" do
      :ACCESS_ISSUE

      {:ok, view, _html} =
        live_isolated_component(AccessAffectedService, %{
          @assigns
          | alert_data: %{route_type: nil, effect_name: "Access Issue"}
        })

      view
      |> element("form")
      |> render_change(%{"access_affected_service" => %{"facility_ids" => ["Facility-3"]}})

      assert_receive {:__live_isolated_component_handle_info_received__, _pid,
                      {:section_completed, %AccessAffectedService{facility_ids: ["Facility-3"]}}}
    end

    test "search works" do
      with_mock(FacilitiesRepo, get_by_type: fn _facility_types, _opts -> [@facility] end) do
        :BIKE_ISSUE

        {:ok, view, _html} = live_isolated_component(AccessAffectedService, @assigns)

        {:ok, document} =
          view
          |> render_async()
          |> Floki.parse_document()

        assert document_has_element?(
                 document,
                 "select#access_affected_service_facility_ids > option[value=\"Facility-3\"]"
               )

        {:ok, document} =
          view
          |> element("form")
          |> render_change(%{"access_affected_service" => %{"facility_search_term" => "q"}})
          |> Floki.parse_document()

        refute document_has_element?(
                 document,
                 "select#access_affected_service_facility_ids > option[value=\"Facility-3\"][selected=\"selected\"]"
               )
      end
    end

    test "search does not reset itself on selection" do
      with_mock(FacilitiesRepo,
        get_by_type: fn _facility_types, _opts -> [@facility, @facility_two, @facility_three] end
      ) do
        :BIKE_ISSUE

        matcher = fn v ->
          "select#access_affected_service_facility_ids > option[value=\"#{v}\"]"
        end

        {:ok, view, _html} = live_isolated_component(AccessAffectedService, @assigns)

        {:ok, document} =
          view
          |> render_async()
          |> Floki.parse_document()

        assert document_has_element?(document, matcher.("Facility-3"))

        {:ok, document} =
          view
          |> element("form")
          |> render_change(%{"access_affected_service" => %{"facility_search_term" => "Place"}})
          |> Floki.parse_document()

        refute document_has_element?(document, matcher.("Facility-3"))
        refute document_has_element?(document, matcher.("Facility-7"))
        assert document_has_element?(document, matcher.("Facility-10"))

        {:ok, document} =
          view
          |> element("form")
          |> render_change(%{"access_affected_service" => %{"facility_id" => "Facility-10"}})
          |> Floki.parse_document()

        refute document_has_element?(document, matcher.("Facility-3"))
        refute document_has_element?(document, matcher.("Facility-7"))
        assert document_has_element?(document, matcher.("Facility-10"))
      end
    end

    test "modal search works" do
      with_mock(FacilitiesRepo, get_by_type: fn _facility_types, _opts -> [@facility] end) do
        :BIKE_ISSUE

        {:ok, view, _html} = live_isolated_component(AccessAffectedService, @assigns)

        assert view
               |> element("select#access_affected_service_stop_id")
               |> render_async() =~
                 ~s(value="place-sstat">South Station</option>)

        view
        |> element("form")
        |> render_change(%{"access_affected_service" => %{"stop_search_term" => "q"}})

        refute view
               |> element("select#access_affected_service_stop_id")
               |> render_async() =~
                 ~s(<option value="place-sstat">South Station</option>)
      end
    end

    test "add stop filter on facilities works" do
      with_mock(FacilitiesRepo,
        get_by_type: fn _facility_types, _opts -> [@facility, @facility_two] end
      ) do
        {:ok, view, _html} =
          live_isolated_component(
            AccessAffectedService,
            @assigns
          )

        # Set baseline unfiltered
        {:ok, document} =
          view
          |> render_async()
          |> Floki.parse_document()

        assert Floki.find(document, "option[value=\"Facility-3\"]")
        assert Floki.find(document, "option[value=\"Facility-7\"]")

        # Add stop filter
        view
        |> element("form")
        |> render_change(%{
          "access_affected_service" => %{"stop_id" => "place-sstat"}
        })

        # Submit filter
        {:ok, document} =
          view
          |> with_target("#access_service_view")
          |> render_click(:accepted_stops_modal)
          |> Floki.parse_document()

        # Verify filtered and filter text updated
        assert document_has_element?(document, "option[value=\"Facility-3\"]")
        refute document_has_element?(document, "option[value=\"Facility-7\"]")
        assert view |> render_async() =~ ~s(Filter: South Station)
      end
    end

    test "clear stop filter for facilities works" do
      with_mock(FacilitiesRepo,
        get_by_type: fn _facility_types, _opts -> [@facility, @facility_two] end
      ) do
        {:ok, view, _html} =
          live_isolated_component(
            AccessAffectedService,
            @assigns
          )

        # Add stop filter
        view
        |> element("form")
        |> render_change(%{
          "access_affected_service" => %{"stop_id" => "place-sstat"}
        })

        # Submit filter
        view
        |> with_target("#access_service_view")
        |> render_click(:accepted_stops_modal)

        # Clear filter
        {:ok, document} =
          view
          |> with_target("#access_service_view")
          |> render_click(:clear_filter, %{"filter-id" => "stops-filter-modal"})
          |> Floki.parse_document()

        # Verify unfiltered
        assert document_has_element?(document, "option[value=\"Facility-3\"]")
        assert document_has_element?(document, "option[value=\"Facility-7\"]")
        # Verify text changed
        assert render(view) =~ ~s(Filter: All stops)
        # Verify modal is cleared
        assert document_has_element?(document, "option[value=\"default\"][selected=\"selected\"]")
      end
    end

    test "it sends errors if errors changeset" do
      :FACILITY_ISSUE

      {:ok, view, _html} =
        live_isolated_component(AccessAffectedService, %{
          @assigns
          | alert_data: %{route_type: nil, effect_name: "Facility Issue"}
        })

      view
      |> element("form")
      |> render_change(%{"access_affected_service" => %{"facility_ids" => []}})

      assert_receive {:__live_isolated_component_handle_info_received__, _pid,
                      {:section_completed,
                       %Ecto.Changeset{
                         errors: [facility_ids: {"can't be blank", [validation: :required]}]
                       }}}
    end

    test "renders while editing an existing alerts" do
      with_mock(FacilitiesRepo, get_by_type: fn _facility_types, _opts -> [@facility] end) do
        :BIKE_ISSUE

        alert_data = %AlertsUIWeb.FormComponents.Helpers.AlertData{
          facility_ids: ["Facility-3"],
          effect_name: "Bike Issue"
        }

        assigns = @assigns |> Map.merge(%{alert_data: alert_data, form_type: :editing})

        {:ok, view, _html} = live_isolated_component(AccessAffectedService, assigns)

        {:ok, document} =
          view
          |> element("select#access_affected_service_facility_ids")
          |> render_async()
          |> Floki.parse_document()

        assert document_has_element?(document, "option[value=\"Facility-3\"]")
      end
    end

    @tag :logged_in_user
    test "shows missing field error upon submission", %{conn: conn} do
      :PARKING_ISSUE

      with_mocks([
        {RoutePatternsRepo, [], [included_stops_by_route_id: fn _route_id, _direction -> [] end]},
        {FacilitiesRepo, [], get_by_type: fn _types, _opts -> [] end}
      ]) do
        {:ok, view, _html} = live(conn, "/alerts/new")

        get_to_submission_page(view, "Facility", "Parking issue")

        refute view
               |> render() =~
                 ~s(text-text-error)

        view
        |> element("button#review", "Review and submit")
        |> render_click()

        assert view
               |> render() =~
                 ~s(text-text-error)
      end
    end
  end
end
