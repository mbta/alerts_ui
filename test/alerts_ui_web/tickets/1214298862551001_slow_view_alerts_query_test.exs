defmodule AlertsUIWeb.Tickets.SlowViewAlertsQueryTest do
  @moduledoc """
  Regression test for Asana ticket 1214298862551001
  "🐌 Slow database query(?) on View Alerts Page"
  https://app.asana.com/1/15492006741476/project/1167196461144361/task/1214298862551001

  Prod database errors / 500s were attributed to many users idling on the View
  Alerts page, with `list_all_paginated` queries piling up. The fix (PR #1036,
  "reduce list_all_paginated calls on view alerts mount") reduced the number of
  times the expensive `list_all_paginated` query runs during page load:

    * `mount/3` no longer runs the query at all (it assigns `alerts: []` and an
      empty `%Flop.Meta{}`).
    * `handle_params/3` short-circuits with `{:noreply, socket}` on the dead /
      disconnected static mount (`%{transport_pid: nil}`), so the static render
      issues ZERO `list_all_paginated` queries.
    * The query only runs once the LiveView is connected (via the live
      `handle_params/3`), and the periodic `:update` poll is only scheduled when
      `connected?(socket)`.

  This test pins that behavior: the static (disconnected) render must NOT emit
  alert rows / run the listing query, while the connected mount must populate
  them. A regression that reinstates the query on the dead mount would repopulate
  the static HTML and fail this test.
  """
  use ExUnit.Case
  use AlertsUIWeb.ConnCase

  import AlertsUI.Support.Factory
  import Mock
  import Phoenix.LiveViewTest

  alias MBTAV3API.Routes.Repo, as: RoutesRepo

  setup do
    insert(:alert, %{
      alert_id: "777",
      original_route_selections: ["Orange"],
      header_text: "ticket-1214298862551001 fixture alert"
    })

    :ok
  end

  @tag :logged_in_user
  test "the disconnected static mount does not run list_all_paginated", %{conn: conn} do
    with_mock(RoutesRepo, [], all: fn -> [] end, get: fn route_id -> %{name: route_id} end) do
      # `get/2` performs only the static (dead) render — no connected mount.
      # On the dead mount, mount/3 assigns alerts: [] and handle_params/3
      # short-circuits, so the listing query never runs and no alert row is
      # rendered.
      static_html = conn |> get("/alerts?filter[timeline]=all") |> html_response(200)

      refute static_html =~ "777"
      refute static_html =~ "ticket-1214298862551001 fixture alert"
    end
  end

  @tag :logged_in_user
  test "the connected mount runs list_all_paginated and populates the alert", %{conn: conn} do
    with_mock(RoutesRepo, [], all: fn -> [] end, get: fn route_id -> %{name: route_id} end) do
      # `live/2` upgrades to the connected mount, where the live
      # handle_params/3 runs list_all_paginated once and populates the table.
      {:ok, _view, html} = live(conn, "/alerts?filter[timeline]=all")

      assert html =~ "777"
    end
  end
end
