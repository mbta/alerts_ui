defmodule AlertsUIWeb.Tickets.FacilitiesVisibleWithoutStopFilterTest do
  @moduledoc """
  Regression test for Asana ticket 1214053426015558
  "🐛 Some facilities can't be selected and submitted successfully"
  https://app.asana.com/1/15492006741476/project/1167196461144361/task/1214053426015558

  Bug: Creating a Facility • Access Issue alert and selecting a facility whose
  name starts with "Terminal" (or any facility when no stop filter had been set)
  showed a "You must select a facility" validation error on submit, even though
  a facility was visually selected.

  Root cause: `AccessAffectedServiceSlice.async_assign_selections/2` called
  `filter_facility_by_stop_ids(facility, stop_id, ...)` where `stop_id` could
  be `nil` before the user had ever set a stop filter. Inside
  `filter_facility_by_stop_ids/3`, the guard checks
  `stop_id_filter_value === "default"` — `nil !== "default"` — so it fell
  through to `facility.stop.id === nil`, which is always false, silently
  filtering OUT all facilities from the picker. With an empty facility list the
  user saw options (stale HTML from the previous render) but could not actually
  select and submit one.

  Fix: the call was changed to `stop_id || "default"`, so an unset stop filter
  is treated identically to the explicit "All stops" default.

  These tests guard against that regression recurring:
    1. The facility list is non-empty (all facilities visible) when no stop
       filter has been applied — the direct condition that caused the bug.
    2. Selecting a facility and clicking "Review and submit" does NOT produce
       a "You must select a facility" validation error.
  """
  use ExUnit.Case, async: false
  use AlertsUIWeb.ConnCase
  import Mock
  import Phoenix.LiveViewTest
  import Test.Support.Helpers

  alias MBTAV3API.Facilities.Facility
  alias MBTAV3API.Facilities.Repo, as: FacilitiesRepo
  alias MBTAV3API.Stops.Stop

  # Simulate a "Terminal"-style facility: its stop has a real id, but the
  # facility itself is associated with a distinct stop (not nil). This mirrors
  # the real data shape for Terminal A / Terminal B facilities at Logan Airport.
  @terminal_stop %Stop{id: "17091", name: "Terminal A"}
  @terminal_facility %Facility{
    id: "bike-17091",
    long_name: "Terminal A bike rack",
    stop: @terminal_stop
  }

  @other_stop %Stop{id: "place-sstat", name: "South Station"}
  @other_facility %Facility{
    id: "Facility-3",
    long_name: "South Station Elevator",
    stop: @other_stop
  }

  # Navigate to the Facility • Bike Issue form (combination :ACCESS).
  defp navigate_to_access(conn, view),
    do: get_to_submission_page(conn, view, "Facility", "Bike issue")

  describe "facility list is populated when no stop filter is applied" do
    @tag :logged_in_user
    test "all facilities are visible before any stop filter is set", %{conn: conn} do
      # Before the fix, stop_id was nil → filter treated every facility as
      # not matching any stop → empty list. After the fix, nil → "default"
      # → show all.
      with_mock(FacilitiesRepo,
        get_by_type: fn _types, _ -> [@terminal_facility, @other_facility] end
      ) do
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = navigate_to_access(conn, view)
        render_async(view)

        html = render(view)

        # Both facilities must be present in the rendered select options
        assert html =~ ~s(value="bike-17091"),
               "Terminal A bike rack option not rendered — facility list is empty without stop filter"

        assert html =~ ~s(value="Facility-3"),
               "South Station Elevator option not rendered — facility list is empty without stop filter"
      end
    end
  end

  describe "selecting a facility and reviewing does not raise a facility validation error" do
    @tag :logged_in_user
    test "selecting a Terminal facility and clicking Review shows no facility error", %{
      conn: conn
    } do
      with_mock(FacilitiesRepo,
        get_by_type: fn _types, _ -> [@terminal_facility, @other_facility] end,
        # AlertBuilder.original_selections_from_form/2 calls Repo.get/1 for each
        # selected facility when building the review modal preview.
        get: fn "bike-17091" -> @terminal_facility end
      ) do
        {:ok, view, _html} = live(conn, "/alerts/new")
        view = navigate_to_access(conn, view)
        render_async(view)

        # Select the Terminal A bike rack facility (as the user would from the
        # list — no stop filter applied first).
        view
        |> element("form")
        |> render_change(%{
          "alert_data" => %{
            "facility_ids" => ["bike-17091"],
            "header_text" => "QA regression - Terminal facility access issue"
          }
        })

        # Click "Review and submit" — fires the "review" event which sets
        # submitted? = true and runs the facility_ids validation.
        open_review_modal(view)

        html = render(view)

        # The review modal must have opened (not been blocked by a validation error)
        assert has_element?(view, "#review-modal-container"),
               "Review modal did not open — facility validation error may have blocked it"

        # No "You must select a facility" error must appear in the rendered HTML
        refute html =~ "You must select a facility",
               "Got 'You must select a facility' error even though a Terminal facility was selected"
      end
    end
  end
end
