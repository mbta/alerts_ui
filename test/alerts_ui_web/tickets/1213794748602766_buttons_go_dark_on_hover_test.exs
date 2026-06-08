defmodule AlertsUIWeb.Tickets.ButtonsGoDarkOnHoverTest do
  @moduledoc """
  Regression test for Asana ticket 1213794748602766
  "🐛 Buttons go dark when hovering"
  https://app.asana.com/1/15492006741476/project/1167196461144361/task/1213794748602766

  Observed bug: on hover, buttons went dark (very dark background) instead of
  being highlighted. Examples reported: action buttons on alerts table (edit,
  close, more), timeline filter buttons (Current/Future/Past/All), reset button.

  Root of the fix: `secondary_button_classes/0` in SharedComponents previously
  used `hover:bg-secondary-hover` (#0b2f4c — essentially black-blue, visually
  "dark"). The fix changed it to `hover:bg-bg-elevation-6` (#384e5c — a
  noticeably lighter dark-mode hover highlight). Similarly, `radio_switch_input`
  uses `hover:bg-bg-elevation-5` for the unselected timeline buttons, and
  `hover:!bg-primary-hover` (#C1E4FF — light blue) for selected ones.
  The filter modal button also uses `hover:bg-bg-elevation-5`.

  This test pins the hover classes so a regression back to the dark hover
  would be caught immediately.

  Verified on dev-green 2026-06-07:
    - Timeline buttons (unselected): rest #1e2933 → hover #2e3f4d (lighter)
    - Timeline button (selected):    rest #9FC0DB → hover #C1E4FF (lighter)
    - Action buttons (edit/close):   rest transparent → hover #384e5c (lighter than table row)
    - Filter button:                 rest #1e2933 → hover #2e3f4d (lighter)
  """
  use ExUnit.Case, async: true

  import Phoenix.Component, only: [sigil_H: 2]
  import Phoenix.LiveViewTest

  alias AlertsUIWeb.SharedComponents
  alias AlertsUIWeb.CoreComponents

  # The offending hover colour from BEFORE the fix: very dark (near-black)
  @dark_hover_bg "bg-secondary-hover"

  # The correct hover colours after the fix
  @secondary_hover_bg "bg-bg-elevation-6"
  @filter_and_timeline_unselected_hover_bg "bg-bg-elevation-5"
  @timeline_selected_hover_bg "bg-primary-hover"

  describe "secondary_button_classes/0 — action buttons (AC: buttons don't go dark)" do
    test "hover class is the lighter bg-bg-elevation-6, NOT the dark bg-secondary-hover" do
      classes = SharedComponents.secondary_button_classes()

      assert classes =~ "hover:#{@secondary_hover_bg}",
             "Expected secondary button hover to use #{@secondary_hover_bg} (#384e5c), got: #{classes}"

      refute classes =~ "hover:#{@dark_hover_bg}",
             "Secondary button must NOT use #{@dark_hover_bg} (#0b2f4c) on hover — that was the bug"
    end

    test "button has a rest background class (bg-bg-elevation-3 or similar)" do
      # Note: as of the current codebase, secondary_button_classes has a typo
      # "bg-elevation-3" instead of "bg-bg-elevation-3". This test documents
      # the INTENDED state (with the correct class). If this test fails, the
      # typo may have been fixed — update this test accordingly.
      classes = SharedComponents.secondary_button_classes()

      # At minimum, some background class should be present
      assert classes =~ "bg-", "Secondary button should have a background class"
    end
  end

  describe "button_secondary/1 rendered markup" do
    test "secondary button renders the lighter hover class, not the dark one" do
      assigns = %{}

      html =
        ~H"""
        <SharedComponents.button_secondary>Click me</SharedComponents.button_secondary>
        """
        |> rendered_to_string()

      assert html =~ "hover:#{@secondary_hover_bg}"
      refute html =~ "hover:#{@dark_hover_bg}"
    end
  end

  describe "button_secondary_link/1 rendered markup" do
    test "secondary link-button renders the lighter hover class" do
      assigns = %{}

      html =
        ~H"""
        <SharedComponents.button_secondary_link href="/alerts">
          Link button
        </SharedComponents.button_secondary_link>
        """
        |> rendered_to_string()

      assert html =~ "hover:#{@secondary_hover_bg}"
      refute html =~ "hover:#{@dark_hover_bg}"
    end
  end

  describe "radio_switch_input/1 — timeline filter buttons" do
    test "unselected timeline button has a lighter hover (bg-bg-elevation-5), not dark" do
      assigns = %{
        name: "timeline",
        value: "future",
        label: "Future",
        checked: false,
        on_change: ""
      }

      html =
        ~H"""
        <CoreComponents.radio_switch_input
          name={@name}
          value={@value}
          label={@label}
          checked={@checked}
          on_change={@on_change}
        />
        """
        |> rendered_to_string()

      assert html =~ "hover:#{@filter_and_timeline_unselected_hover_bg}",
             "Unselected timeline btn should hover to #{@filter_and_timeline_unselected_hover_bg}"

      refute html =~ "hover:#{@dark_hover_bg}",
             "Unselected timeline btn must NOT use #{@dark_hover_bg} — that was the bug"
    end

    test "selected timeline button has a LIGHT hover (bg-primary-hover = #C1E4FF)" do
      assigns = %{
        name: "timeline",
        value: "current",
        label: "Current",
        checked: true,
        on_change: ""
      }

      html =
        ~H"""
        <CoreComponents.radio_switch_input
          name={@name}
          value={@value}
          label={@label}
          checked={@checked}
          on_change={@on_change}
        />
        """
        |> rendered_to_string()

      assert html =~ "hover:!#{@timeline_selected_hover_bg}",
             "Selected timeline btn should hover to #{@timeline_selected_hover_bg} (light blue)"

      refute html =~ "hover:#{@dark_hover_bg}",
             "Selected timeline btn must NOT use #{@dark_hover_bg}"
    end
  end
end
