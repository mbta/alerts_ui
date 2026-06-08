defmodule AlertsUIWeb.Tickets.HoverCssSelectedButtonsTest do
  @moduledoc """
  Regression test for Asana ticket 1212952513436008
  "🐛 Adjust hover CSS for selected buttons"
  https://app.asana.com/1/15492006741476/project/1167196461144361/task/1212952513436008

  Observed bug: when deselecting a toggle button (day-of-week selectors, route/line
  buttons, alert-form-page-1 effect buttons), the button looked like it stayed
  selected while the cursor was still hovering over it — the hover state of an
  unselected button was visually indistinguishable from the selected state.

  Acceptance criteria:
    1. It should be obvious when a button is no longer/not selected, even if the
       cursor is still hovering over it.
    2. Works on both desktop and mobile (CSS classes are viewport-independent here).
    3. Use Benji's recommendation: distinct hover vs selected vs unselected states.

  The fix lives in `AlertsUIWeb.SharedComponents.toggle_button_classes/0`, applied
  by both `button_toggle/1` (effect & route-type buttons, page 1) and
  `toggle_checkgroup/1` (day-of-week + line selection). The four states resolve to
  these Tailwind background tokens (see assets/tailwind.config.js):

      selected   (rest)  -> bg-secondary-active   #9FC0DB
      selected   + hover -> bg-primary-hover       #C1E4FF
      unselected (rest)  -> bg-bg-elevation-3      #1E2933
      unselected + hover -> bg-bg-elevation-4       #2B3741

  Verified live on dev-green (day-of-week + line buttons, desktop + mobile):
  deselecting a day while the cursor stays over it returns it to #2B3741
  (unselected-hover, dark), never the light selected family.

  This test pins the class assignment so a future regression that reuses one
  family's hover/selected background for the other would fail here.
  """
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest
  import Phoenix.Component, only: [sigil_H: 2]

  alias AlertsUIWeb.SharedComponents

  # The selected ("on") and unselected ("off") background tokens must be disjoint
  # so the two states can never look alike — including each state's hover variant.
  @selected_bg "bg-secondary-active"
  @selected_hover_bg "bg-primary-hover"
  @unselected_bg "bg-bg-elevation-3"
  @unselected_hover_bg "bg-bg-elevation-4"

  defp render_toggle(active?) do
    assigns = %{active: active?}

    ~H"""
    <SharedComponents.button_toggle active={@active} value="monday">Monday</SharedComponents.button_toggle>
    """
    |> rendered_to_string()
  end

  describe "toggle_button_classes/0 — the fix's source of truth" do
    test "selected and unselected use disjoint background tokens (AC1 at rest)" do
      classes = SharedComponents.toggle_button_classes()
      on = Keyword.fetch!(classes, :toggled_on)
      off = Keyword.fetch!(classes, :toggled_off)

      assert on =~ @selected_bg
      assert on =~ @selected_hover_bg
      assert off =~ @unselected_bg
      assert off =~ @unselected_hover_bg

      # The crux of the bug: the unselected button must NEVER carry a selected
      # background (rest or hover), or a hovered-unselected button would look selected.
      refute off =~ @selected_bg
      refute off =~ @selected_hover_bg
      # ...and the selected button must never carry an unselected background.
      refute on =~ @unselected_bg
      refute on =~ @unselected_hover_bg
    end

    test "each state has a distinct hover treatment (Benji's recommendation, AC3)" do
      classes = SharedComponents.toggle_button_classes()
      on = Keyword.fetch!(classes, :toggled_on)
      off = Keyword.fetch!(classes, :toggled_off)

      # selected hover differs from selected rest
      assert on =~ "hover:#{@selected_hover_bg}"
      assert on =~ @selected_bg
      assert @selected_hover_bg != @selected_bg

      # unselected hover differs from unselected rest
      assert off =~ "hover:#{@unselected_hover_bg}"
      assert off =~ @unselected_bg
      assert @unselected_hover_bg != @unselected_bg
    end
  end

  describe "button_toggle/1 rendered markup" do
    test "selected button renders the selected (light) background, not the unselected one" do
      html = render_toggle(true)

      assert html =~ @selected_bg
      assert html =~ "hover:#{@selected_hover_bg}"
      refute html =~ @unselected_bg
    end

    test "unselected button renders the unselected (dark) background and a dark hover, never a selected one" do
      html = render_toggle(false)

      assert html =~ @unselected_bg
      assert html =~ "hover:#{@unselected_hover_bg}"
      # AC1: hovering an unselected button must not produce a selected-looking color.
      refute html =~ @selected_bg
      refute html =~ "hover:#{@selected_hover_bg}"
    end
  end
end
