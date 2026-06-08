defmodule AlertsUIWeb.Tickets.CopyTextStaysWhiteAtLimitTest do
  @moduledoc """
  Regression test for Asana ticket 1213791649887634
  "🐛 When text limit is reached, 'Copy text' turns red"
  https://app.asana.com/1/15492006741476/project/1167196461144361/task/1213791649887634

  Observed bug: when the Main Message textarea reaches the 255-character limit,
  the "Copy text" button text turned red, inheriting the error color from the
  character limit indicator.

  Desired behavior:
    - The red border should appear around the Main Message box.
    - The "255/255 Character limit reached" indicator text should be red.
    - The "Copy text" button text should remain unchanged (white/default).

  Fix: the `!text-error` class in `textarea_footer/1` is scoped only to the
  character counter `<div>`, not to the outer footer container, so the copy
  button (a sibling element) does not inherit the error color.

  This test pins the class structure of `textarea_footer/1` so that any future
  change incorrectly placing `!text-error` on the outer container — which would
  cascade onto the copy button — would fail here.
  """
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest
  import Phoenix.Component, only: [sigil_H: 2]

  alias AlertsUIWeb.SharedComponents

  # Build a map-backed Phoenix.HTML.Form with the given header_text value.
  defp form_with_text(text) do
    Phoenix.Component.to_form(%{"header_text" => text}, as: :alert_data)
  end

  defp render_footer(form) do
    assigns = %{form: form}

    ~H"""
    <SharedComponents.textarea_footer
      character_limit={255}
      copy_id="#alert_data_header_text"
      copy_title="Copy main message to Clipboard"
      field={@form[:header_text]}
    />
    """
    |> rendered_to_string()
  end

  describe "textarea_footer/1 — copy button does not inherit error color (AC: Copy text stays white)" do
    test "at the 255-char limit: !text-error is NOT on the outer container div" do
      text_at_limit = String.duplicate("A", 255)
      html = render_footer(form_with_text(text_at_limit))

      # The outer footer wrapper must NOT carry !text-error (that would cascade
      # onto the Copy text button).
      [outer_div | _] = Floki.parse_document!(html) |> Floki.find("div")
      outer_classes = outer_div |> Floki.attribute("class") |> List.first() || ""
      refute outer_classes =~ "!text-error",
             "Outer footer div must not carry !text-error — it would cascade onto the Copy text button"
    end

    test "at the 255-char limit: !text-error IS scoped to the character counter div, not copy button" do
      text_at_limit = String.duplicate("A", 255)
      html = render_footer(form_with_text(text_at_limit))

      # The copy button must not have !text-error applied
      copy_button_html = Floki.parse_document!(html) |> Floki.find("button") |> Floki.raw_html()
      refute copy_button_html =~ "!text-error",
             "Copy text button must not have !text-error class"

      # The character counter div (ml-auto) must have !text-error when at limit
      counter_div =
        Floki.parse_document!(html)
        |> Floki.find("div.ml-auto")
        |> List.first()

      assert counter_div != nil, "Expected a ml-auto div (character counter)"

      counter_classes = counter_div |> Floki.attribute("class") |> List.first() || ""

      assert counter_classes =~ "!text-error",
             "Character counter div must have !text-error at the 255-char limit"
    end

    test "under the 255-char limit: !text-error does not appear anywhere in the footer" do
      text_under_limit = String.duplicate("A", 254)
      html = render_footer(form_with_text(text_under_limit))

      refute html =~ "!text-error",
             "!text-error should not appear in footer when under the character limit"
    end

    test "at the limit: 'Character limit reached' text is present" do
      text_at_limit = String.duplicate("A", 255)
      html = render_footer(form_with_text(text_at_limit))
      assert html =~ "Character limit reached"
    end

    test "under the limit: 'Character limit reached' text is absent" do
      text_under_limit = String.duplicate("A", 254)
      html = render_footer(form_with_text(text_under_limit))
      refute html =~ "Character limit reached"
    end

    test "copy button is always present (with copy_id provided)" do
      # at limit
      html_at = render_footer(form_with_text(String.duplicate("A", 255)))
      assert html_at =~ "Copy text"

      # under limit
      html_under = render_footer(form_with_text(String.duplicate("A", 100)))
      assert html_under =~ "Copy text"

      # empty
      html_empty = render_footer(form_with_text(""))
      assert html_empty =~ "Copy text"
    end
  end
end
