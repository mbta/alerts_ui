defmodule AlertsUIWeb.Tickets.SearchBarPersistsOnSelectionTest do
  @moduledoc """
  Regression test for Asana ticket 1214108822755652
  "🐛 Facility selector & filter search bar clears upon selection"
  https://app.asana.com/1/15492006741476/project/1167196461144361/task/1214108822755652

  Acceptance criteria covered:
    * When a user enters a search term in a search bar (selector or filter) and
      then selects an option, the search term must NOT be cleared.
        - Test case: Facility selector
        - Test case: Facility stop filter (modal)
    * The filter modal's width must NOT change based on the length of the
      results (the modal is pinned to a fixed width via its container class).

  Verified against dev-green on 2026-06-06 (Facility > Parking Closure).
  """
  use ExUnit.Case, async: false
  use AlertsUIWeb.ConnCase
  import Phoenix.LiveViewTest
  import Mock
  import Test.Support.Helpers
  alias MBTAV3API.Facilities.Facility
  alias MBTAV3API.Facilities.Repo, as: FacilitiesRepo
  alias MBTAV3API.Stops.Stop

  @stop_a %Stop{id: "place-aaaaa", name: "Wellesley Farms"}
  @stop_b %Stop{id: "place-bbbbb", name: "Quincy Center"}

  @facility_a %Facility{id: "Facility-A", long_name: "Wellesley Farms Parking Lot", stop: @stop_a}
  @facility_b %Facility{id: "Facility-B", long_name: "Quincy Center Garage", stop: @stop_b}

  # Parking Closure is a multi-select facility effect, the ticket's example.
  defp navigate_to_parking_closure(conn, view) do
    get_to_submission_page(conn, view, "Facility", "Parking closure")
  end

  defp type_in_filter(view, field, term) do
    view
    |> element("form")
    |> render_change(%{
      "_target" => ["alert_data", field],
      "alert_data" => %{field => term}
    })

    render_async(view)
  end

  describe "facility selector (AC1: search term persists on selection)" do
    @tag :logged_in_user
    test "selecting a facility does not clear the facility search term", %{conn: conn} do
      with_mock(FacilitiesRepo, get_by_type: fn _types, _ -> [@facility_a, @facility_b] end) do
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = navigate_to_parking_closure(conn, view)
        render_async(view)

        # Enter a search term that narrows to a single facility.
        type_in_filter(view, "facility_search_term", "Wellesley")

        {:ok, document} = view |> render() |> Floki.parse_document()
        assert document_has_element?(document, "option[value=\"Facility-A\"]")
        refute document_has_element?(document, "option[value=\"Facility-B\"]")

        # Select that facility.
        view
        |> element("form")
        |> render_change(%{"alert_data" => %{"facility_ids" => ["Facility-A"]}})

        render_async(view)

        # BUG would have been: the search input value is wiped to "".
        {:ok, document} = view |> render() |> Floki.parse_document()

        assert search_term_value(document, "alert_data_facility_search_term") == "Wellesley",
               "facility search term should persist after selecting an option"

        # And the filtered list should still reflect the still-present term.
        assert document_has_element?(document, "option[value=\"Facility-A\"]")
        refute document_has_element?(document, "option[value=\"Facility-B\"]")
      end
    end
  end

  describe "facility stop filter modal (AC1: search term persists; AC3: fixed width)" do
    @tag :logged_in_user
    test "selecting a stop does not clear the modal stop search term", %{conn: conn} do
      with_mock(FacilitiesRepo, get_by_type: fn _types, _ -> [@facility_a, @facility_b] end) do
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = navigate_to_parking_closure(conn, view)
        render_async(view)

        # Type into the modal's stop search bar; narrows to one stop.
        type_in_filter(view, "stop_search_term", "Wellesley")

        {:ok, document} = view |> render() |> Floki.parse_document()

        assert document_has_element?(
                 document,
                 "select#alert_data_stop_id > option[value=\"place-aaaaa\"]"
               )

        refute document_has_element?(
                 document,
                 "select#alert_data_stop_id > option[value=\"place-bbbbb\"]"
               )

        # Select the stop option in the modal.
        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "stop_id"],
          "alert_data" => %{"stop_id" => "place-aaaaa"}
        })

        render_async(view)

        # BUG would have been: stop search term cleared & option not selected.
        {:ok, document} = view |> render() |> Floki.parse_document()

        assert search_term_value(document, "alert_data_stop_search_term") == "Wellesley",
               "modal stop search term should persist after selecting an option"

        assert document_has_element?(
                 document,
                 "select#alert_data_stop_id > option[value=\"place-aaaaa\"][selected]"
               ),
               "selected stop option should still appear selected"
      end
    end

    @tag :logged_in_user
    test "modal width is pinned and independent of result count (AC3)", %{conn: conn} do
      with_mock(FacilitiesRepo, get_by_type: fn _types, _ -> [@facility_a, @facility_b] end) do
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = navigate_to_parking_closure(conn, view)
        render_async(view)

        # The modal panel carries a fixed width class regardless of result count.
        # (Driven from the slice's `container_class="md:!w-[25rem]"`.)
        {:ok, doc_all} = view |> render() |> Floki.parse_document()
        assert modal_container_class(doc_all) =~ "w-[25rem]"

        # Narrow results to one match.
        type_in_filter(view, "stop_search_term", "Wellesley")
        {:ok, doc_one} = view |> render() |> Floki.parse_document()
        assert modal_container_class(doc_one) =~ "w-[25rem]"

        # Narrow to zero matches.
        type_in_filter(view, "stop_search_term", "zzzzzznomatch")
        {:ok, doc_none} = view |> render() |> Floki.parse_document()
        assert modal_container_class(doc_none) =~ "w-[25rem]"

        # The width-bearing class is identical across all three states.
        assert modal_container_class(doc_all) == modal_container_class(doc_one)
        assert modal_container_class(doc_one) == modal_container_class(doc_none)
      end
    end
  end

  # Reads the `value` attribute of the named search input.
  defp search_term_value(document, input_id) do
    case Floki.attribute(Floki.find(document, "input##{input_id}"), "value") do
      [value | _] -> value
      [] -> nil
    end
  end

  defp modal_container_class(document) do
    case Floki.attribute(Floki.find(document, "#stops-filter-modal-container"), "class") do
      [class | _] -> class
      [] -> nil
    end
  end
end
