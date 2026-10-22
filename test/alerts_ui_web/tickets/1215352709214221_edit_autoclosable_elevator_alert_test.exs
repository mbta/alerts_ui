defmodule AlertsUIWeb.Tickets.EditAutoclosableElevatorAlertTest do
  @moduledoc """
  Regression test for Asana ticket 1215352709214221
  "🐛 User can't edit Supporting Info of Trapeze elevator alert"
  https://app.asana.com/1/15492006741476/project/1167196461144361/task/1215352709214221

  Bug: editing an imported Trapeze elevator/escalator alert (whose end is "When work order
  is closed") and submitting dropped its auto-close flag, because `enforce_defaults` reset
  `can_close_automatically` back to its schema default whenever the submitted value matched
  the existing one (`get_change` is nil for unchanged fields).
  """
  use ExUnit.Case, async: false
  use AlertsUIWeb.ConnCase

  import AlertsUI.Support.Factory
  import Mock
  import Phoenix.LiveViewTest
  import Test.Support.Helpers

  alias AlertsUI.Alerts
  alias MBTAV3API.Facilities.Facility
  alias MBTAV3API.Facilities.Repo, as: FacilitiesRepo
  alias MBTAV3API.Routes.Repo, as: RoutesRepo
  alias MBTAV3API.Routes.Route
  alias MBTAV3API.Stops.Repo, as: StopsRepo
  alias MBTAV3API.Stops.Stop

  @facility %Facility{
    id: "128",
    type: "ESCALATOR",
    short_name: "Forest Hills escalator",
    long_name: "Forest Hills Escalator 128",
    stop: %Stop{id: "place-forhl", name: "Forest Hills", child_ids: []}
  }

  @tag :logged_in_user
  test "editing a Trapeze escalator alert keeps it auto-closable after submitting",
       %{conn: conn} do
    with_mocks([
      {FacilitiesRepo, [],
       [
         get_by_type: fn _types, _ -> [@facility] end,
         get: fn "128" -> @facility end
       ]},
      {StopsRepo, [],
       [
         all: fn _, _ -> [] end,
         by_route: fn _route, _direction, _opts -> [] end,
         get: fn _id -> @facility.stop end,
         get!: fn _id -> @facility.stop end,
         get_parent: fn _id -> nil end
       ]},
      {RoutesRepo, [],
       [
         by_stop: fn _id -> [%Route{id: "16", type: 3, name: "16"}] end,
         by_type: fn _ -> [] end
       ]}
    ]) do
      # Seed a Trapeze, auto-closable ESCALATOR_CLOSURE alert with no end (1000054's shape).
      now_et = DateTime.utc_now() |> DateTime.shift_zone!("America/New_York")

      {:ok, alert} =
        Alerts.create_or_update_alert(
          %{
            alert_id: "trapeze-escalator-#{System.unique_integer([:positive])}",
            source: :TRAPEZE,
            work_order_id: "310-2026-0000",
            effect: "ACCESSIBILITY_ISSUE",
            effect_detail: "ESCALATOR_CLOSURE",
            effect_name: "Escalator Closure",
            primary_service_type: "access",
            can_close_automatically: true,
            duration_certainty: :UNKNOWN,
            active_period_start: DateTime.to_naive(now_et),
            active_period_end: nil,
            active_period: [%{start: DateTime.to_naive(now_et), end: nil}],
            header_text: "Forest Hills Escalator 128 is out of service.",
            informed_entity: [%{facility_id: "128", activities: [:USING_ESCALATOR]}],
            severity: 3,
            last_modified_timestamp: DateTime.utc_now(),
            reminder_times: []
          },
          build(:user)
        )

      {:ok, view, _html} =
        live(conn, "/alerts/edit/#{alert.alert_id}")

      render_async(view)

      open_review_modal(view)
      submit_alert(view)

      updated = Alerts.get_by_alert_id(alert.alert_id)

      assert is_nil(updated.active_period_end),
             "an auto-closable alert should persist with no end time"

      assert updated.can_close_automatically,
             "an auto-closable alert should stay auto-closable after editing"
    end
  end
end
