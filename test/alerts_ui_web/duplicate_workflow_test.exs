defmodule AlertsUIWeb.DuplicateWorkflowTest do
  @moduledoc """
  Module for end-to-end alert duplication tests
  """
  use AlertsUIWeb.ConnCase

  import AlertsUI.Support.Factory
  import Mock
  import Phoenix.LiveViewTest
  import Test.Support.Helpers

  alias AlertsUI.Alerts
  alias MBTAV3API.RoutePatterns.Repo, as: RoutePatternsRepo
  alias MBTAV3API.Routes.Repo, as: RoutesRepo
  alias MBTAV3API.Routes.Route
  alias MBTAV3API.Stops.Repo, as: StopsRepo
  alias MBTAV3API.Stops.Stop

  @tomorrow_datetime DateTime.utc_now()
                     |> DateTime.shift_zone!("America/New_York")
                     |> DateTime.add(1, :day)

  @later_datetime DateTime.add(@tomorrow_datetime, 3, :day)

  @route_one %Route{
    sort_order: 1,
    id: "1",
    type: 3,
    name: "bus route 1",
    direction_names: %{0 => "Outbound", 1 => "Inbound"}
  }
  @route_two %Route{sort_order: 2, id: "2", name: "2"}
  @routes [@route_one, @route_two]
  @stop %Stop{id: "stop-id", name: "Stop Name"}

  @tag :logged_in_user
  test "duplicate alert and verify content matches the original", %{conn: conn} do
    with_mocks([
      {RoutePatternsRepo, [],
       [
         included_stops_by_route_id: fn _route_id, _direction -> [] end,
         by_route_id: fn _route_id, _opts -> [] end
       ]},
      {RoutesRepo, [],
       [
         by_type: fn _types -> @routes end,
         get: fn _id -> @route_one end,
         get: fn _id, _opts -> @route_one end,
         all: fn -> @routes end,
         all: fn _opts -> @routes end
       ]},
      {StopsRepo, [],
       [
         by_route: fn _route, _direction, _opts -> [@stop] end,
         get_parent: fn nil -> nil end,
         all: fn ["filter[id]": ""], _ -> [@stop] end
       ]}
    ]) do
      alert_params =
        build(:alert_map, %{
          active_period_end: @later_datetime,
          active_period_start: @tomorrow_datetime,
          alert_id: "123",
          duration_certainty: "KNOWN",
          effect: :OTHER_EFFECT,
          effect_detail: "DELAY",
          informed_entity: [%{activities: [:BOARD, :EXIT, :RIDE], route_type: 3, route_id: "1"}],
          original_route_selections: ["bus route 1|1"],
          primary_service_type: "3",
          recurrence_days: []
        })

      {:ok, _} =
        Alerts.create_or_update_alert(
          alert_params,
          build(:user, first_name: "Original", last_name: "Creator")
        )

      {:ok, view, _html} = live(conn, "/alerts/duplicate/123")

      open_review_modal(view)
      refute render(view) =~ ~r/Created by.*\s* Original Creator/

      view
      |> element("#review-modal-container button", "Submit")
      |> render_click()

      # query the db
      flash = assert_redirect(view, "/")
      assert flash["info"] =~ ~r/Alert #[0-9]+ duplicated from #[0-9]/

      alert_id =
        flash["info"]
        |> String.replace("Alert #", "")
        |> String.replace(" duplicated from #123", "")

      assert %AlertsUI.Models.Alert{
               active_period: _,
               active_period_end: _,
               active_period_start: _,
               banner_text: nil,
               cause: nil,
               cause_detail: nil,
               closed_timestamp: nil,
               created_timestamp: _,
               description_text: "b",
               draft: false,
               duration_certainty: :KNOWN,
               effect: :OTHER_EFFECT,
               effect_detail: "DELAY",
               header_text: "a",
               image_alternative_text: nil,
               image_url: nil,
               informed_entity: [
                 %AlertsUI.Models.InformedEntity{
                   agency_id: nil,
                   route_id: "1",
                   facility_id: nil,
                   route_type: 3,
                   direction_id: nil,
                   stop_id: nil,
                   activities: [:BOARD, :EXIT, :RIDE],
                   trip: nil
                 }
               ],
               original_route_selections: ["bus route 1|1"],
               original_stop_selections: nil,
               recurrence_days: [],
               recurrence_text: nil,
               reminder_times: [],
               severity: 3
             } = AlertsUI.Alerts.get_by_alert_id(123)

      assert %AlertsUI.Models.Alert{
               active_period: _,
               active_period_end: _,
               active_period_start: _,
               banner_text: nil,
               cause: nil,
               cause_detail: nil,
               closed_timestamp: nil,
               created_timestamp: _,
               description_text: "b",
               draft: false,
               duration_certainty: :KNOWN,
               effect: :OTHER_EFFECT,
               effect_detail: "DELAY",
               header_text: "a",
               image_alternative_text: nil,
               image_url: nil,
               informed_entity: [
                 %AlertsUI.Models.InformedEntity{
                   route_id: "1",
                   facility_id: nil,
                   route_type: 3,
                   direction_id: nil,
                   stop_id: nil,
                   activities: [:BOARD, :EXIT, :RIDE],
                   trip: nil
                 }
               ],
               original_route_selections: ["bus route 1|1"],
               original_stop_selections: [],
               recurrence_days: [],
               recurrence_text: nil,
               reminder_times: [],
               severity: 3
             } = AlertsUI.Alerts.get_by_alert_id(alert_id)
    end
  end

  @tag :logged_in_user
  test "duplicate alert, tweak it, and verify content is as expected", %{conn: conn} do
    with_mocks([
      {RoutePatternsRepo, [],
       [
         included_stops_by_route_id: fn _route_id, _direction -> [] end,
         by_route_id: fn _route_id, _opts -> [] end
       ]},
      {RoutesRepo, [],
       [
         by_type: fn _types -> @routes end,
         get: fn _id -> @route_one end,
         get: fn _id, _opts -> @route_one end,
         all: fn -> @routes end,
         all: fn _opts -> @routes end
       ]},
      {StopsRepo, [],
       [
         by_route: fn _route, _direction, _opts -> [@stop] end,
         get_parent: fn nil -> nil end,
         all: fn _, _ -> [@stop] end
       ]}
    ]) do
      alert_params =
        build(:alert_map, %{
          active_period_end: @later_datetime,
          active_period_start: @tomorrow_datetime,
          alert_id: "123",
          duration_certainty: "KNOWN",
          effect: :OTHER_EFFECT,
          effect_detail: "DELAY",
          informed_entity: [%{route_type: 3, route_id: "1"}],
          original_route_selections: ["bus route 1|1"],
          primary_service_type: "3"
        })

      {:ok, _} =
        Alerts.create_or_update_alert(alert_params, build(:user))

      {:ok, view, _html} = live(conn, "/alerts/duplicate/123")

      assert render_async(view) =~
               ~r/<option value="default" selected="">.*All Stops.*<\/option>/s

      view
      |> element("form")
      |> render_change(%{
        alert_data: %{
          stop_names_and_ids: ["Stop Name (outbound)|stop-id"]
        }
      })

      open_review_modal(view)

      view
      |> element("#review-modal-container button", "Submit")
      |> render_click()

      # query the db
      flash = assert_redirect(view, "/")
      assert flash["info"] =~ ~r/Alert #[0-9]+ duplicated from #[0-9]/

      alert_id =
        flash["info"]
        |> String.replace("Alert #", "")
        |> String.replace(" duplicated from #123", "")

      assert %AlertsUI.Models.Alert{
               active_period: _,
               active_period_start: _,
               alert_lifecycle: nil,
               banner_text: nil,
               cause: :UNKNOWN_CAUSE,
               cause_detail: nil,
               closed_timestamp: nil,
               created_timestamp: _,
               description_text: "b",
               draft: false,
               duration_certainty: :KNOWN,
               effect: :OTHER_EFFECT,
               effect_detail: "DELAY",
               effect_name: "Delay",
               header_text: "a",
               image_alternative_text: nil,
               image_url: nil,
               informed_entity: [
                 %AlertsUI.Models.InformedEntity{
                   activities: [:BOARD, :EXIT, :RIDE],
                   agency_id: "1",
                   direction_id: nil,
                   facility_id: nil,
                   route_id: "1",
                   route_type: 3,
                   stop_id: "stop-id",
                   trip: nil
                 }
               ],
               last_modified_timestamp: _,
               notification_period_start: _,
               original_route_selections: ["bus route 1|1"],
               recurrence_days: [],
               recurrence_text: nil,
               reminder_times: [],
               service_effect_text: "bus route 1 delay",
               severity: 3,
               severity_level: :WARNING,
               short_header_text: nil,
               timeframe_text: nil,
               tts_description_text: nil,
               tts_header_text: nil,
               url: nil,
               original_stop_selections: ["Stop Name (outbound)|stop-id"]
             } = AlertsUI.Alerts.get_by_alert_id(alert_id)
    end
  end
end
