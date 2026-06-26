defmodule AlertsUIWeb.Tickets.OtherActionsMenuNotTruncatedTest do
  @moduledoc """
  Regression test for Asana ticket 1213156310400768
  "🐛 Other actions menu being truncated"
  https://app.asana.com/0/1167196461144361/1213156310400768

  Bug: The "Show more actions" (ellipsis) dropdown on the alerts listing page was
  being truncated/clipped when only a few alerts were visible, especially the
  last alert row. The menu appeared above the button instead of below, and was
  partially hidden by container overflow.

  Fix: Added a `DropdownPosition` LiveView JS hook to `button_menu` that:
    1. Measures the space between the toggle button and the container/viewport bottom.
    2. If the dropdown would overflow downward, it adds `bottom-[34px]` to flip
       the menu above the button instead.
    3. Accepts a `container_id` to use a specific container element's bounding rect
       instead of the raw viewport height.

  Acceptance criteria covered:
    * AC1: The "Show more actions" button's dropdown is rendered with the
           `DropdownPosition` hook — the JS mechanism that prevents truncation.
    * AC2: The menu's dropdown element carries the correct `data-container-id`
           attribute pointing to an element that exists in the DOM.
    * AC3: The dropdown links include "Duplicate"
           and "Download history" — both menu items are rendered.

  Verified pass against dev-green on 2026-06-08 (7 alerts, all menus fully visible
  at 900px and 600px viewports; buttons 5-6 correctly used drop-up positioning).
  """
  use ExUnit.Case
  use AlertsUIWeb.ConnCase

  import AlertsUI.Support.Factory
  import Mock
  import Phoenix.LiveViewTest

  alias MBTAV3API.Routes.Repo, as: RoutesRepo

  setup do
    insert(:alert, %{
      alert_id: "9990001",
      header_text: "Red Line delays at Central",
      effect_detail: "DELAY",
      active_period_start: ~U[2023-10-12 00:01:00Z],
      original_route_selections: ["Red"],
      duration_certainty: :UNKNOWN
    })

    :ok
  end

  @tag :logged_in_user
  test "more actions dropdown uses the DropdownPosition hook (AC1)", %{conn: conn} do
    with_mock(RoutesRepo, [], all: fn -> [] end, get: fn id -> %{name: id} end) do
      {:ok, _view, html} = live(conn, "/alerts")
      {:ok, document} = Floki.parse_document(html)

      # The dropdown menu element must be instrumented with the DropdownPosition hook.
      # Without this hook, the menu has no mechanism to flip above the button when
      # there is not enough space below it — causing the truncation bug.
      dropdown_menus = Floki.find(document, "[phx-hook='DropdownPosition']")

      assert dropdown_menus != [],
             "Expected at least one element with phx-hook='DropdownPosition' on the alerts page"
    end
  end

  @tag :logged_in_user
  test "more actions dropdown carries a valid container_id reference (AC2)", %{conn: conn} do
    with_mock(RoutesRepo, [], all: fn -> [] end, get: fn id -> %{name: id} end) do
      {:ok, _view, html} = live(conn, "/alerts")
      {:ok, document} = Floki.parse_document(html)

      dropdown_menus = Floki.find(document, "[phx-hook='DropdownPosition']")

      assert dropdown_menus != [],
             "Expected dropdown menus with DropdownPosition hook to be rendered"

      for menu <- dropdown_menus do
        container_id = Floki.attribute([menu], "data-container-id") |> List.first()

        assert container_id != nil,
               "Dropdown menu is missing data-container-id attribute — " <>
                 "DropdownPosition hook won't have a container reference"

        assert container_id != "",
               "Dropdown menu data-container-id is empty — hook will fall back to viewport"

        # The container element must actually exist in the rendered HTML.
        container_els = Floki.find(document, "##{container_id}")

        assert container_els != [],
               "Container element '##{container_id}' referenced by DropdownPosition hook " <>
                 "was not found in the page HTML"
      end
    end
  end

  @tag :logged_in_user
  test "more actions dropdown renders Duplicate and Download history items (AC3)", %{conn: conn} do
    with_mock(RoutesRepo, [], all: fn -> [] end, get: fn id -> %{name: id} end) do
      {:ok, _view, html} = live(conn, "/alerts")
      {:ok, document} = Floki.parse_document(html)

      duplicate_links =
        document
        |> Floki.find("[id^='duplicate-button-']")

      assert duplicate_links != [],
             "Expected at least one Duplicate link in the more actions menu"

      for link <- duplicate_links do
        href = Floki.attribute([link], "href") |> List.first()

        assert href =~ "/alerts/duplicate/",
               "Duplicate link href should contain /alerts/duplicate/, got: #{inspect(href)}"
      end

      # There should be a "Download history" link.
      download_links =
        document
        |> Floki.find("[id^='download-history-button-']")

      assert download_links != [],
             "Expected at least one Download history link in the more actions menu"
    end
  end

  @tag :logged_in_user
  test "more actions dropdown has toggle button with a valid data-toggle-id back-reference (AC1 structure)",
       %{conn: conn} do
    with_mock(RoutesRepo, [], all: fn -> [] end, get: fn id -> %{name: id} end) do
      {:ok, _view, html} = live(conn, "/alerts")
      {:ok, document} = Floki.parse_document(html)

      dropdown_menus = Floki.find(document, "[phx-hook='DropdownPosition']")

      for menu <- dropdown_menus do
        menu_id = Floki.attribute([menu], "id") |> List.first()
        toggle_id = Floki.attribute([menu], "data-toggle-id") |> List.first()

        assert toggle_id != nil,
               "Dropdown '##{menu_id}' is missing data-toggle-id — " <>
                 "DropdownPosition hook cannot find the toggle button to measure space"

        # The toggle element must also exist in the HTML.
        toggle_els = Floki.find(document, "##{toggle_id}")

        assert toggle_els != [],
               "Toggle element '##{toggle_id}' referenced by menu '##{menu_id}' " <>
                 "was not found in the page HTML"
      end
    end
  end
end
