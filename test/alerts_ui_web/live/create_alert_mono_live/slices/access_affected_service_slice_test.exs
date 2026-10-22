defmodule AlertsUIWeb.CreateAlertMonoLive.Slices.AccessAffectedServiceSliceTest do
  use ExUnit.Case, async: false
  use AlertsUIWeb.ConnCase
  import AlertsUI.Support.Factory
  import Phoenix.LiveViewTest
  import Mock
  import Test.Support.Helpers
  alias AlertsUI.Alerts
  alias MBTAV3API.Facilities.Facility
  alias MBTAV3API.Facilities.Repo, as: FacilitiesRepo
  alias MBTAV3API.Stops.Stop

  @stop_sstat %Stop{id: "place-sstat", name: "South Station"}
  @stop_aqucl %Stop{id: "place-aqucl", name: "Aquarium"}
  @stop_apent %Stop{id: "place-apent", name: "Somewhere Else"}

  @facility %Facility{
    id: "Facility-3",
    long_name: "Example Facility",
    stop: @stop_sstat
  }

  @facility_two %Facility{
    id: "Facility-7",
    long_name: "Example Facility Two",
    stop: @stop_aqucl
  }

  @facility_three %Facility{
    id: "Facility-10",
    long_name: "Another Place Entirely",
    stop: @stop_apent
  }

  # "Bike Issue" + "Facility" navigation → combination :ACCESS
  defp navigate_to_access(conn, view) do
    get_to_submission_page(conn, view, "Facility", "Bike issue")
  end

  describe "component" do
    @tag :logged_in_user
    test "renders", %{conn: conn} do
      with_mock(FacilitiesRepo, get_by_type: fn _types, _ -> [@facility] end) do
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = navigate_to_access(conn, view)
        render_async(view)
        assert render(view) =~ ~s(id="access_service_view")
      end
    end

    @tag :logged_in_user
    test "facility search works", %{conn: conn} do
      with_mock(FacilitiesRepo,
        get_by_type: fn _types, _ -> [@facility, @facility_two, @facility_three] end
      ) do
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = navigate_to_access(conn, view)
        render_async(view)

        {:ok, document} = view |> render() |> Floki.parse_document()
        assert document_has_element?(document, "option[value=\"Facility-3\"]")
        assert document_has_element?(document, "option[value=\"Facility-7\"]")
        assert document_has_element?(document, "option[value=\"Facility-10\"]")

        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "facility_search_term"],
          "alert_data" => %{"facility_search_term" => "Another"}
        })

        render_async(view)

        {:ok, document} = view |> render() |> Floki.parse_document()
        assert document_has_element?(document, "option[value=\"Facility-10\"]")
        refute document_has_element?(document, "option[value=\"Facility-3\"]")
        refute document_has_element?(document, "option[value=\"Facility-7\"]")
      end
    end

    @tag :logged_in_user
    test "facility search clears", %{conn: conn} do
      with_mock(FacilitiesRepo, get_by_type: fn _types, _ -> [@facility, @facility_two] end) do
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = navigate_to_access(conn, view)
        render_async(view)

        {:ok, document} = view |> render() |> Floki.parse_document()
        assert document_has_element?(document, "option[value=\"Facility-3\"]")

        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "facility_search_term"],
          "alert_data" => %{"facility_search_term" => "q"}
        })

        render_async(view)

        {:ok, document} = view |> render() |> Floki.parse_document()
        refute document_has_element?(document, "option[value=\"Facility-3\"]")

        render_click(view, "reset_search_filter", %{
          "name" => "alert_data[facility_search_term]"
        })

        render_async(view)

        {:ok, document} = view |> render() |> Floki.parse_document()
        assert document_has_element?(document, "option[value=\"Facility-3\"]")
      end
    end

    @tag :logged_in_user
    test "facility search does not reset on selection", %{conn: conn} do
      with_mock(FacilitiesRepo,
        get_by_type: fn _types, _ -> [@facility, @facility_two, @facility_three] end
      ) do
        matcher = fn v -> "option[value=\"#{v}\"]" end

        {:ok, view, _html} = live(conn, "/alerts/new")
        view = navigate_to_access(conn, view)
        render_async(view)

        # Filter to only Facility-10
        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "facility_search_term"],
          "alert_data" => %{"facility_search_term" => "Another"}
        })

        render_async(view)

        {:ok, document} = view |> render() |> Floki.parse_document()
        refute document_has_element?(document, matcher.("Facility-3"))
        refute document_has_element?(document, matcher.("Facility-7"))
        assert document_has_element?(document, matcher.("Facility-10"))

        # Selecting Facility-10 should not clear the search
        view
        |> element("form")
        |> render_change(%{
          "alert_data" => %{"facility_ids" => ["Facility-10"]}
        })

        render_async(view)

        {:ok, document} = view |> render() |> Floki.parse_document()
        refute document_has_element?(document, matcher.("Facility-3"))
        refute document_has_element?(document, matcher.("Facility-7"))
        assert document_has_element?(document, matcher.("Facility-10"))
      end
    end

    @tag :logged_in_user
    test "modal stop search works", %{conn: conn} do
      with_mock(FacilitiesRepo, get_by_type: fn _types, _ -> [@facility, @facility_two] end) do
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = navigate_to_access(conn, view)
        render_async(view)

        assert render(view) =~ ~s(South Station)

        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "stop_search_term"],
          "alert_data" => %{"stop_search_term" => "South"}
        })

        render_async(view)

        {:ok, document} = view |> render() |> Floki.parse_document()

        assert document_has_element?(
                 document,
                 "select#alert_data_stop_id > option[value=\"place-sstat\"]"
               )

        refute document_has_element?(
                 document,
                 "select#alert_data_stop_id > option[value=\"place-aqucl\"]"
               )
      end
    end

    @tag :logged_in_user
    test "modal stop search clears", %{conn: conn} do
      with_mock(FacilitiesRepo, get_by_type: fn _types, _ -> [@facility, @facility_two] end) do
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = navigate_to_access(conn, view)
        render_async(view)

        {:ok, document} = view |> render() |> Floki.parse_document()

        assert document_has_element?(
                 document,
                 "select#alert_data_stop_id > option[value=\"place-sstat\"]"
               )

        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "stop_search_term"],
          "alert_data" => %{"stop_search_term" => "q"}
        })

        render_async(view)

        {:ok, document} = view |> render() |> Floki.parse_document()

        refute document_has_element?(
                 document,
                 "select#alert_data_stop_id > option[value=\"place-sstat\"]"
               )

        render_click(view, "reset_search_filter", %{"name" => "alert_data[stop_search_term]"})
        render_async(view)

        {:ok, document} = view |> render() |> Floki.parse_document()

        assert document_has_element?(
                 document,
                 "select#alert_data_stop_id > option[value=\"place-sstat\"]"
               )
      end
    end

    @tag :logged_in_user
    test "add stop filter on facilities works", %{conn: conn} do
      with_mock(FacilitiesRepo,
        get_by_type: fn _types, _ -> [@facility, @facility_two] end
      ) do
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = navigate_to_access(conn, view)
        render_async(view)

        {:ok, document} = view |> render() |> Floki.parse_document()
        assert document_has_element?(document, "option[value=\"Facility-3\"]")
        assert document_has_element?(document, "option[value=\"Facility-7\"]")

        # Select a stop filter
        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "stop_id"],
          "alert_data" => %{"stop_id" => "place-sstat"}
        })

        render_async(view)

        # Accept the filter
        render_click(view, "accept_filter")
        render_async(view)

        {:ok, document} = view |> render() |> Floki.parse_document()
        assert document_has_element?(document, "option[value=\"Facility-3\"]")
        refute document_has_element?(document, "option[value=\"Facility-7\"]")
        assert render(view) =~ ~s(Filter: South Station)
      end
    end

    @tag :logged_in_user
    test "clear stop filter for facilities works", %{conn: conn} do
      with_mock(FacilitiesRepo,
        get_by_type: fn _types, _ -> [@facility, @facility_two] end
      ) do
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = navigate_to_access(conn, view)
        render_async(view)

        # Apply stop filter
        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "stop_id"],
          "alert_data" => %{"stop_id" => "place-sstat"}
        })

        render_async(view)
        render_click(view, "accept_filter")
        render_async(view)

        assert render(view) =~ ~s(Filter: South Station)

        # Clear filter
        render_click(view, "clear_filter", %{"filter-id" => "stops-filter-modal"})
        render_async(view)

        assert render(view) =~ ~s(Filter: All stops)

        {:ok, document} = view |> render() |> Floki.parse_document()
        assert document_has_element?(document, "option[value=\"Facility-3\"]")
        assert document_has_element?(document, "option[value=\"Facility-7\"]")
      end
    end

    @tag :logged_in_user
    test "renders while editing an existing alert", %{conn: conn} do
      alert_params =
        build(:alert_map, %{
          alert_id: "test-access-edit",
          effect: :OTHER_EFFECT,
          effect_detail: "BIKE_ISSUE",
          primary_service_type: "access",
          informed_entity: [
            %{facility_id: "Facility-3", route_type: nil}
          ],
          original_facility_selections: ["Facility-3"]
        })

      {:ok, _} = Alerts.create_or_update_alert(alert_params, build(:user))

      with_mock(FacilitiesRepo, get_by_type: fn _types, _ -> [@facility] end) do
        {:ok, view, _html} = live(conn, "/alerts/edit/test-access-edit")
        render_async(view)

        {:ok, document} = view |> render() |> Floki.parse_document()
        assert document_has_element?(document, "option[value=\"Facility-3\"]")
      end
    end

    @tag :logged_in_user
    test "shows error when no facility selected and review is clicked", %{conn: conn} do
      with_mock(FacilitiesRepo, get_by_type: fn _types, _ -> [] end) do
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = navigate_to_access(conn, view)
        render_async(view)

        view |> element("button#review", "Review and submit") |> render_click()

        refute has_element?(view, "#review-modal-container")

        assert view
               |> element("#flash")
               |> render() =~ "Select facility"
      end
    end

    @tag :logged_in_user
    test "renders single facility select properly", %{conn: conn} do
      with_mock(FacilitiesRepo, get_by_type: fn _types, _ -> [] end) do
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Facility", "Elevator closure")
        render_async(view)

        refute view
               |> element("#alert_data_single_facility_id")
               |> render() =~ "multiple",
               "Elevator closures can only select one option"
      end
    end

    @tag :logged_in_user
    test "renders multiple facility select properly", %{conn: conn} do
      with_mock(FacilitiesRepo, get_by_type: fn _types, _ -> [] end) do
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Facility", "Bike issue")
        render_async(view)

        assert view
               |> element("#alert_data_facility_ids")
               |> render() =~ "multiple",
               "Bike issues allow multiple facilities to be selected"
      end
    end
  end
end
