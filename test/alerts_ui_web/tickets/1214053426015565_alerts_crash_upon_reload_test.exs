defmodule AlertsUIWeb.Tickets.AlertsCrashUponReloadTest do
  @moduledoc """
  Regression test for Asana ticket 1214053426015565
  "🐛 Alerts crash upon reload"
  https://app.asana.com/1/15492006741476/project/1167196461144361/task/1214053426015565

  Observed: the alert form crashed with "Internal server error" when the
  page was RELOADED for alerts whose effect is a 2-word effect, e.g.:

    * Bus • Multi-route detour   (URL: /alerts/new/bus/multi-route_detour)
    * Any facility alert         (URL: /alerts/new/facility/access_issue)
    * Any systemwide alert       (URL: /alerts/new/systemwide/amber_alert)

  A reload re-mounts the LiveView and re-parses the `effect_name` segment from
  the URL via `CreateAlertLive.Helpers.Path.effect_from_url_name/1`. The bug
  was that the 2-word / hyphenated effect URL segment could not be reconstructed
  into a valid effect display name on the fresh mount, crashing the render.

  Desired behavior: reloading the form must not crash.

  This test pins both entry points a reload hits:
    * the disconnected static render (`get/2`, i.e. the dead mount that produces
      the initial HTML on a hard reload) must return 200, not a 500, and
    * the connected mount (`live/2`) must render the form for the requested
      effect.

  It also round-trips every effect URL name through `effect_from_url_name/1` to
  guard against a future effect whose 2-word reconstruction regresses.
  """
  use ExUnit.Case
  use AlertsUIWeb.ConnCase

  import Phoenix.LiveViewTest
  import Mock
  alias MBTAV3API.Facilities.Repo, as: FacilitiesRepo

  alias AlertsUIWeb.CreateAlertLive.Helpers.Path, as: PathHelper
  alias AlertsUIWeb.Helpers.EffectsForRouteTypes

  # Each tuple is {route_type_segment, effect_url_segment, expected_title_fragment}.
  # All three were called out in the ticket as crashing on reload, and each has a
  # multi-word effect name (the root of the bug).
  @reload_cases [
    {"bus", "multi-route_detour", "Multi-Route Detour"},
    {"facility", "access_issue", "Access Issue"},
    {"systemwide", "amber_alert", "Amber Alert"}
  ]

  describe "reloading the form with a 2-word effect does not crash" do
    @tag :logged_in_user
    test "the disconnected static render (hard reload) returns 200, not a 500", %{conn: conn} do
      for {route_type, effect, title_fragment} <- @reload_cases do
        url = "/alerts/new/#{route_type}/#{effect}"

        html = conn |> get(url) |> html_response(200)

        refute html =~ "Internal server error",
               "reload of #{url} showed an Internal server error"

        assert html =~ title_fragment,
               "reload of #{url} did not render the expected effect title #{inspect(title_fragment)}"
      end
    end

    @tag :logged_in_user
    test "the connected mount renders the form for the requested effect", %{conn: conn} do
      for {route_type, effect, title_fragment} <- @reload_cases do
        url = "/alerts/new/#{route_type}/#{effect}"

        with_mock(FacilitiesRepo,
          get_by_type: fn _facility_types, _opts -> [] end
        ) do
          {:ok, _view, html} = live(conn, url)

          assert html =~ title_fragment,
                 "connected mount of #{url} did not render #{inspect(title_fragment)}"
        end
      end
    end
  end

  describe "effect_from_url_name/1 round-trips every effect" do
    test "every effect URL name reconstructs to a known effect display name" do
      for route_type <- [:bus, :commuter_rail, :facility, :ferry, :subway, :systemwide],
          effect <- EffectsForRouteTypes.list_effects(route_type) do
        # Mirror how the URL segment is produced from a display name: lowercase,
        # spaces -> underscores (e.g. "Multi-route detour" -> "multi-route_detour").
        url_name = effect |> String.downcase() |> String.replace(" ", "_")

        reconstructed = PathHelper.effect_from_url_name(url_name)

        assert String.downcase(reconstructed) == String.downcase(effect),
               "effect #{inspect(effect)} (url #{inspect(url_name)}) did not round-trip; got #{inspect(reconstructed)}"
      end
    end
  end
end
