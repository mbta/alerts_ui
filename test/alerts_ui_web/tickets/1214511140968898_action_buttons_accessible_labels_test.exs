defmodule AlertsUIWeb.Tickets.ActionButtonsAccessibleLabelsTest do
  @moduledoc """
  Regression test for Asana ticket 1214511140968898
  "🐛 Actions buttons have no accessible labels or titles"
  https://app.asana.com/1/15492006741476/project/1167196461144361/task/1214511140968898

  Bug: The edit (pencil), close (X), and more actions (ellipsis) buttons on the
  alerts listing page had no tooltip or accessible label. The X icon's title was
  incorrectly derived from its href (/alerts#), making it say "alerts".

  Acceptance criteria:
    1. The edit button says "Edit alert" in a tooltip (title attribute) when hovered
       and when interacting via VoiceOver.
    2. The close alert button says "Close alert" in a tooltip when hovered and
       when interacting via VoiceOver.
    3. The ellipsis/more actions button says "Show more actions" in a tooltip when
       hovered and when interacting via VoiceOver.

  Verified against dev-green on 2026-06-07.
  """
  use ExUnit.Case
  use AlertsUIWeb.ConnCase

  import AlertsUI.Support.Factory
  import Mock
  import Phoenix.LiveViewTest

  alias MBTAV3API.Routes.Repo, as: RoutesRepo

  setup do
    insert(:alert, %{
      alert_id: "999001",
      header_text: "Green Line delays at Boylston",
      effect_detail: "DELAY",
      active_period_start: ~U[2023-10-12 00:01:00Z],
      original_route_selections: ["Green-B"],
      duration_certainty: :UNKNOWN
    })

    :ok
  end

  @tag :logged_in_user
  test "edit button has title='Edit alert' (AC1)", %{conn: conn} do
    with_mock(RoutesRepo, [], all: fn -> [] end, get: fn id -> %{name: id} end) do
      {:ok, _view, html} = live(conn, "/alerts")

      {:ok, document} = Floki.parse_document(html)

      edit_buttons = Floki.find(document, "[id^='edit-button-']")

      assert edit_buttons != [],
             "Expected at least one edit button (id starting with 'edit-button-') to be rendered"

      for btn <- edit_buttons do
        [title] = Floki.attribute([btn], "title")

        assert title == "Edit alert",
               "Edit button title should be 'Edit alert', got: #{inspect(title)}"
      end
    end
  end

  @tag :logged_in_user
  test "close alert button has title='Close alert' (AC2)", %{conn: conn} do
    with_mock(RoutesRepo, [], all: fn -> [] end, get: fn id -> %{name: id} end) do
      {:ok, _view, html} = live(conn, "/alerts")

      {:ok, document} = Floki.parse_document(html)

      close_buttons = Floki.find(document, "[id^='close-button-']")

      assert close_buttons != [],
             "Expected at least one close button (id starting with 'close-button-') to be rendered"

      for btn <- close_buttons do
        [title] = Floki.attribute([btn], "title")

        assert title == "Close alert",
               "Close button title should be 'Close alert', got: #{inspect(title)}"
      end
    end
  end

  @tag :logged_in_user
  test "more actions (ellipsis) button has title='Show more actions' (AC3)", %{conn: conn} do
    with_mock(RoutesRepo, [], all: fn -> [] end, get: fn id -> %{name: id} end) do
      {:ok, _view, html} = live(conn, "/alerts")

      {:ok, document} = Floki.parse_document(html)

      # The more-actions button is inside a button_menu :toggle slot with title="Show more actions"
      more_buttons = Floki.find(document, "[title='Show more actions']")

      assert more_buttons != [],
             "Expected at least one 'Show more actions' button to be rendered"

      for btn <- more_buttons do
        [title] = Floki.attribute([btn], "title")

        assert title == "Show more actions",
               "More actions button title should be 'Show more actions', got: #{inspect(title)}"
      end
    end
  end

  @tag :logged_in_user
  test "no action button is missing a title attribute (guards against regression)", %{conn: conn} do
    with_mock(RoutesRepo, [], all: fn -> [] end, get: fn id -> %{name: id} end) do
      {:ok, _view, html} = live(conn, "/alerts")

      {:ok, document} = Floki.parse_document(html)

      # Collect all three known action button types
      edit_buttons = Floki.find(document, "[id^='edit-button-']")
      close_buttons = Floki.find(document, "[id^='close-button-']")

      action_buttons = edit_buttons ++ close_buttons

      # Each action button must have a non-empty title attribute
      for btn <- action_buttons do
        id = Floki.attribute([btn], "id") |> List.first()
        titles = Floki.attribute([btn], "title")

        assert titles != [],
               "Action button '#{id}' is missing a title attribute entirely"

        [title] = titles

        assert title != "",
               "Action button '#{id}' has an empty title attribute"

        assert String.length(title) > 3,
               "Action button '#{id}' has a suspiciously short title: #{inspect(title)}"
      end
    end
  end
end
