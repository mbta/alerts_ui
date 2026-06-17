defmodule AlertsUIWeb.ViewAlertsOrderParamKnownBugTest do
  @moduledoc """
  Demonstrates a bug found while building the Playwright regression harness
  (see docs/playwright-e2e-proving-slice-report.md).

  Tagged `:known_bug` and excluded from the default run; see it with
  `mix test --include known_bug`. The test asserts the INTENDED behavior, so it
  stays red until the bug is fixed and turns green when it is.
  """
  use AlertsUIWeb.ConnCase

  import AlertsUI.Support.Factory
  import Mock
  import Phoenix.LiveViewTest

  alias MBTAV3API.Routes.Repo, as: RoutesRepo

  setup do
    insert(:alert, %{
      alert_id: "555",
      original_route_selections: ["Red"],
      header_text: "order-param fixture alert"
    })

    :ok
  end

  @tag :known_bug
  @tag :logged_in_user
  test "an unknown order_by query param is ignored rather than crashing the page", %{conn: conn} do
    with_mock(RoutesRepo, [], all: fn -> [] end, get: fn route_id -> %{name: route_id} end) do
      # BUG: handle_params calls String.to_existing_atom(params["order_by"]) on the
      # raw user value (view_alerts_live.ex ~line 97; order_direction similarly at
      # ~line 549). An unknown field raises ArgumentError instead of being
      # whitelisted/ignored, blanking the page. The fix is to validate against the
      # known sortable fields and fall back to the default.
      assert {:ok, _view, _html} =
               live(conn, "/alerts?filter[timeline]=all&order_by=zzz_not_a_real_field")
    end
  end
end
