defmodule AlertsUIWeb.Tickets.AffectedServiceFilterWeirdnessTest do
  @moduledoc """
  Regression test for Asana ticket 1212270992306498
  "🐛 Weirdness in affected service filter"
  https://app.asana.com/0/1167196461144361/1212270992306498

  Two issues were reported:

  Issue 1 (scroll jump): Selecting a route in the stop-filter modal would jump
  the visible window so the selected route appeared at the bottom. Fixed by the
  `Selector` JS hook saving `scrollTop` on `pointerdown` and restoring it in
  `updated()`. This is a client-side (JS) fix and cannot be exercised in ExUnit;
  the hook is tested implicitly via the broader selector test suite.

  Issue 2 (visual deselection): After searching for a route in the modal filter
  and clicking the result, the option would appear visually UN-selected — though
  it still counted as selected when "Apply" was clicked. Root cause: the
  `modal_route_id_options` were not using `values_to_keep` for the selected
  route ID, so after a LiveView re-render triggered by the selection, the
  selected option was filtered out of the DOM and appeared absent/unselected.
  Fix: the slice now passes `values_to_keep: [modal_route_id]` so the currently
  selected route is always present in the rendered option list, regardless of
  the active search term.

  Acceptance criteria tested here (Issue 2):
    * After selecting a route in the modal filter (via a type-narrowed search),
      the selected route MUST remain present in the options list so it renders
      as `selected="selected"` in the DOM.
    * The selected route MUST be present even when the search term is later
      changed to something that would otherwise filter it out.

  Verified against dev-green on 2026-06-08 (Bus > Multi-route detour).
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

  # Bus routes (type 3) for Bus > Multi-route detour
  @route_88 %Route{sort_order: 1, id: "88", name: "88", type: 3}
  @route_77 %Route{sort_order: 2, id: "77", name: "77", type: 3}
  @route_1 %Route{sort_order: 3, id: "1", name: "1", type: 3}

  @stop %Stop{id: "place-aqucl", name: "Aquarium"}

  defp base_mocks do
    [
      {RoutesRepo, [],
       [
         by_type: fn _ -> [@route_88, @route_77, @route_1] end,
         by_stop: fn _ -> [@route_88, @route_77, @route_1] end,
         by_stop: fn _, _ -> [@route_88, @route_77, @route_1] end
       ]},
      {StopsRepo, [],
       [
         by_route: fn _, _, _ -> [@stop] end
       ]}
    ]
  end

  describe "Issue 2: modal route filter - selected route stays visually selected" do
    @tag :logged_in_user
    test "selected route is present in options after LiveView re-render", %{conn: conn} do
      with_mocks(base_mocks()) do
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Bus", "Multi-route detour")
        render_async(view)

        # All three routes should be present in the modal filter select initially
        {:ok, doc_initial} = view |> render() |> Floki.parse_document()

        assert document_has_element?(
                 doc_initial,
                 "select#alert_data_modal_route_id > option[value=\"88\"]"
               )

        assert document_has_element?(
                 doc_initial,
                 "select#alert_data_modal_route_id > option[value=\"77\"]"
               )

        assert document_has_element?(
                 doc_initial,
                 "select#alert_data_modal_route_id > option[value=\"1\"]"
               )

        # User types "88" in the modal search to narrow the list
        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "modal_route_search_term"],
          "alert_data" => %{"modal_route_search_term" => "88"}
        })

        render_async(view)

        {:ok, doc_searched} = view |> render() |> Floki.parse_document()

        # Only route 88 should appear after searching
        assert document_has_element?(
                 doc_searched,
                 "select#alert_data_modal_route_id > option[value=\"88\"]"
               ),
               "route 88 should be present in options after searching for '88'"

        refute document_has_element?(
                 doc_searched,
                 "select#alert_data_modal_route_id > option[value=\"77\"]"
               ),
               "route 77 should NOT be present in options when search term is '88'"

        # User clicks route 88 (selects it)
        # Use _target so the modal_route_id change does not trigger an unnecessary async reload
        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "modal_route_id"],
          "alert_data" => %{"modal_route_id" => "88"}
        })

        render_async(view)

        # BUG would have been: route 88 option is not rendered in the DOM (filtered out),
        # so it appears visually unselected even though the form value is "88".
        {:ok, doc_selected} = view |> render() |> Floki.parse_document()

        assert document_has_element?(
                 doc_selected,
                 "select#alert_data_modal_route_id > option[value=\"88\"]"
               ),
               "route 88 MUST remain present in options after being selected (values_to_keep fix)"

        # The route 88 option must be marked as selected
        assert document_has_element?(
                 doc_selected,
                 "select#alert_data_modal_route_id > option[value=\"88\"][selected]"
               ),
               "route 88 must have selected attribute after being selected"
      end
    end

    @tag :logged_in_user
    test "selected route is preserved in options even when search term changes", %{conn: conn} do
      with_mocks(base_mocks()) do
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = get_to_submission_page(conn, view, "Bus", "Multi-route detour")
        render_async(view)

        # Select route 88 in the modal
        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "modal_route_id"],
          "alert_data" => %{"modal_route_id" => "88"}
        })

        render_async(view)

        # Now change the search term to "77" (which does NOT match route 88)
        view
        |> element("form")
        |> render_change(%{
          "_target" => ["alert_data", "modal_route_search_term"],
          "alert_data" => %{"modal_route_search_term" => "77"}
        })

        render_async(view)

        # BUG would have been: route 88 is filtered out by the "77" search term,
        # disappearing from the option list and appearing visually deselected.
        # Fix: values_to_keep: [modal_route_id] ensures the selected route stays.
        {:ok, doc_changed_search} = view |> render() |> Floki.parse_document()

        assert document_has_element?(
                 doc_changed_search,
                 "select#alert_data_modal_route_id > option[value=\"88\"]"
               ),
               "selected route 88 must remain visible even when search term changes to '77'"

        # Route 77 should also be present (it matches the search)
        assert document_has_element?(
                 doc_changed_search,
                 "select#alert_data_modal_route_id > option[value=\"77\"]"
               )

        # Route 1 should NOT be present (doesn't match "77")
        refute document_has_element?(
                 doc_changed_search,
                 "select#alert_data_modal_route_id > option[value=\"1\"]"
               )
      end
    end
  end
end
