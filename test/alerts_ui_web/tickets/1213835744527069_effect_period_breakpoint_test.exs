defmodule AlertsUIWeb.Tickets.EffectPeriodBreakpointTest do
  @moduledoc """
  Regression test for Asana ticket 1213835744527069 —
  "🐛 Awkward breaking point in effect period inputs".
  https://app.asana.com/1/15492006741476/project/1167196461144361/task/1213835744527069

  Bug: in the screen widths between "everything on one row" and "everything on
  its own row", the effect-period inputs broke at a confusing point — the effect
  START datetime picker could wrap to the row below while the START dropdown
  stayed up, splitting the start group across rows.

  Acceptance criteria: in that interim band keep the inputs grouped —
    * Row 1: effect START dropdown + datetime picker + "to"
    * Row 2: effect END dropdown + datetime picker

  The fix (CreateAlertMonoLive.Slices.TimeRangeSlice.one_time_alert/1) groups the
  controls into nested flex containers instead of a single flat flex-wrap row, so
  wrapping happens BETWEEN the start group and the end group, never mid-group.

  This is a layout/structure concern. Rather than asserting pixel geometry (done
  separately with headless Playwright on dev-green), this test pins the DOM
  STRUCTURE that produces the correct wrapping: the effect-start specifier select,
  the start datetime picker, and the "to" label all live inside ONE wrapping group
  element that does NOT also contain the effect-end specifier select; the end
  specifier select + end datetime live in a SEPARATE sibling group. A regression to
  flat sibling layout (the bug) would put all of these in one container and fail
  these assertions.
  """
  use ExUnit.Case, async: false
  use AlertsUIWeb.ConnCase

  import Phoenix.LiveViewTest
  import Test.Support.Helpers

  @start_specifier_name "alert_data[active_period_start_specifier]"
  @end_specifier_name "alert_data[active_period_end_specifier]"
  @start_datetime_name "alert_data[active_period_start]"
  @end_datetime_name "alert_data[active_period_end]"

  describe "effect period responsive grouping (ticket 1213835744527069)" do
    @tag :logged_in_user
    test "start group (dropdown + datetime + 'to') is wrapped separately from the end group",
         %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/new")
      view = get_to_submission_page(conn, view, "Bus", "Delay")

      # Reproduce the ticket: choose Custom in both the effect start and end dropdowns,
      # which reveals both datetime pickers.
      view
      |> element("form")
      |> render_change(%{
        "alert_data" => %{
          "active_period_start_specifier" => "custom",
          "active_period_end_specifier" => "custom"
        }
      })

      html = render(view)
      {:ok, doc} = Floki.parse_fragment(html)

      time_range = Floki.find(doc, "#time_range_view")
      assert time_range != [], "expected the Timeframe section (#time_range_view) to render"

      # Sanity: with both specifiers Custom, both datetime pickers are present and visible
      # (the visible ones are not class "hidden"). We assert on the visible datetime inputs.
      start_dt = visible_input(time_range, @start_datetime_name)
      end_dt = visible_input(time_range, @end_datetime_name)
      assert start_dt != nil, "effect start datetime picker should be visible when Custom"
      assert end_dt != nil, "effect end datetime picker should be visible when Custom"

      # There must be a wrapping group that holds the effect-START specifier select,
      # the start datetime picker, AND the "to" label, while EXCLUDING the effect-END
      # controls. That separation is what keeps start (+ "to") on row 1 and end on
      # row 2 at intermediate widths. (Each .select/.datetime component renders its
      # own div, so we look for the tightest enclosing group, not those leaf wrappers.)
      start_group = tightest_group_containing(time_range, @start_specifier_name, require_to: true)

      assert start_group != nil,
             ~s|expected a wrapping group holding the effect start dropdown, its datetime picker, and "to"|

      assert input_present?(start_group, @start_datetime_name),
             "effect start datetime picker must be grouped with the effect start dropdown"

      assert to_label_present?(start_group),
             ~s|the "to" label must ride with the effect start group (row 1)|

      refute input_present?(start_group, @end_specifier_name),
             "effect end dropdown must NOT share the start group's wrapper (a flat single-row layout regression would put them together)"

      refute input_present?(start_group, @end_datetime_name),
             "effect end datetime picker must NOT share the start group's wrapper"

      # And the end group is its own wrapper: end specifier + end datetime, no start
      # controls — so the wrapping breaks cleanly between the two groups.
      end_group = tightest_group_containing(time_range, @end_specifier_name)
      assert end_group != nil

      assert input_present?(end_group, @end_datetime_name),
             "effect end datetime picker must be grouped with the effect end dropdown"

      refute input_present?(end_group, @start_specifier_name),
             "effect start dropdown must NOT share the end group's wrapper"
    end
  end

  # --- helpers ----------------------------------------------------------------

  # An input is "visible" when its rendered class string does not contain "hidden".
  defp visible_input(scope, name) do
    scope
    |> Floki.find(~s|input[name="#{name}"]|)
    |> Enum.find(fn el ->
      classes = el |> Floki.attribute("class") |> List.first() |> to_string()
      not String.contains?(classes, "hidden")
    end)
  end

  defp input_present?(scope, name) do
    Floki.find(scope, ~s|[name="#{name}"]|) != []
  end

  defp to_label_present?(scope) do
    scope
    |> Floki.find("p")
    |> Enum.any?(fn p -> p |> Floki.text() |> String.trim() == "to" end)
  end

  # Find the tightest wrapping <div> that groups a specifier select WITH its own
  # datetime picker. Each .select / .datetime component renders its own leaf <div>
  # (one control apiece), so we require the candidate to contain >= 2 controls — that
  # excludes those leaf wrappers and returns the actual group container. Among the
  # qualifying divs we take the one with the fewest controls (the tightest group).
  defp tightest_group_containing(time_range, specifier_name, opts \\ []) do
    datetime_name = String.replace(specifier_name, "_specifier", "")
    require_to = Keyword.get(opts, :require_to, false)

    time_range
    |> Floki.find("div")
    |> Enum.filter(fn div ->
      Floki.find(div, ~s|[name="#{specifier_name}"]|) != [] and
        Floki.find(div, ~s|[name="#{datetime_name}"]|) != [] and
        (not require_to or to_label_present?(div))
    end)
    |> Enum.min_by(
      fn div -> length(Floki.find(div, "select")) + length(Floki.find(div, "input")) end,
      fn -> nil end
    )
  end
end
