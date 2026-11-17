defmodule AlertsUI.Jobs.SkateUpdateWorkerTest do
  use AlertsUI.DataCase, async: false
  import AlertsUI.Support.Factory
  import ExUnit.CaptureLog
  import Mock
  import Test.Support.Helpers
  alias AlertsUI.Alerts
  alias AlertsUI.Jobs.SkateDetourUpdateWorker
  alias AlertsUI.SkateDetours.GetDetours
  alias MBTAV3API.RoutePatterns.Repo, as: RoutePatternsRepo
  alias MBTAV3API.RoutePatterns.RoutePattern, as: RoutePattern
  alias MBTAV3API.Routes.Repo, as: RoutesRepo
  alias MBTAV3API.Routes.Route
  alias MBTAV3API.Stops.Repo, as: StopsRepo
  alias MBTAV3API.Stops.Stop
  alias Oban.Job

  describe "perform" do
    test "exits correctly when there are no alerts to close" do
      set_log_level(:info)

      {result, log} = with_log(fn -> SkateDetourUpdateWorker.perform(%Job{args: %{}}) end)

      assert result == :ok
      assert log == ""
    end

    test "correctly closes open alerts with skate ids that don't appear in list" do
      set_log_level(:info)

      insert(:alert, %{
        alert_id: "123",
        skate_detour_id: 5001,
        active_period_end: nil
      })

      insert(:alert, %{
        alert_id: "789",
        skate_detour_id: 5002,
        active_period_end: nil
      })

      {result, log} = with_log(fn -> SkateDetourUpdateWorker.perform(%Job{args: %{}}) end)

      assert result == :ok
      assert log =~ "[info] Automatically closed the following Skate alerts: 123, 789"
      assert !is_nil(Alerts.get_by_alert_id!("123").closed_timestamp)
      assert !is_nil(Alerts.get_by_alert_id!("789").closed_timestamp)
    end

    test "correctly modifies alerts open skate alerts whose last modified time is before
    the skate detour's last updated time" do
      stop = %Stop{id: "72", name: "Massachusetts Ave @ Pearl St"}

      detour = %AlertsUI.Models.SkateDetour{
        id: 7,
        route_id: "1",
        reason: "Drawbridge being raised",
        nearest_intersection: "Massachusetts Avenue & Western Avenue",
        estimated_duration: "2026-04-14",
        activated_at: ~U[2026-05-10 18:44:19Z],
        updated_at: ~U[2026-05-11 13:37:59Z],
        autoclose_on: nil,
        direction_id: 1,
        missed_stops: ["72"],
        route_segments: nil,
        connection_points: ["71", "73"],
        missed_stops_text_only: nil,
        connection_points_text_only: nil
      }

      with_mocks([
        {GetDetours, [],
         [
           get_detours: fn ->
             [detour]
           end
         ]},
        {RoutePatternsRepo, [],
         [
           by_route_id: fn _, _opts ->
             [
               %RoutePattern{
                 direction_id: 1,
                 stops: [stop],
                 route_id: "1",
                 listed_route: true,
                 id: "rp_1"
               }
             ]
           end,
           included_stops_by_route_id: fn _route_id, _direction -> [stop] end
         ]},
        {RoutesRepo, [], [get: fn _, _opts -> %Route{id: "1", type: 3, name: "1"} end]},
        {StopsRepo, [],
         [
           all: fn
             ["filter[id]": "72"], _opts ->
               [stop]

             ["filter[id]": "71,73"], _opts ->
               [
                 %Stop{id: "71", name: "Massachusetts Ave opp Inman St"},
                 %Stop{id: "73", name: "Massachusetts Ave @ Sidney St"}
               ]
           end
         ]}
      ]) do
        set_log_level(:info)

        original_created_at_timestamp = ~U[2026-05-10 14:30:54Z]

        insert(:alert, %{
          alert_id: "123",
          skate_detour_id: 7,
          active_period_end: nil,
          cause: :ACCIDENT,
          cause_detail: "ACCIDENT",
          original_route_selections: ["1|1"],
          original_stop_selections: ["Massachusetts Ave opp Inman St|71"],
          original_direction_selections: ["Inbound|1"],
          informed_entity: [
            build(:informed_entity, %{route_id: "1", route_type: 3, stop_id: "71"})
          ],
          header_text: "original header text",
          description_text: "original description text",
          service_effect_text: "original service effect text",
          severity: 7,
          created_at: original_created_at_timestamp,
          last_modified_timestamp: original_created_at_timestamp
        })

        insert(:alert, %{
          alert_id: "456",
          skate_detour_id: 7,
          active_period_end: nil,
          cause: :ACCIDENT,
          cause_detail: "ACCIDENT",
          created_at: ~U[2026-05-12 13:37:59Z],
          last_modified_timestamp: ~U[2026-05-12 13:37:59Z]
        })

        {result, log} = with_log(fn -> SkateDetourUpdateWorker.perform(%Job{args: %{}}) end)
        assert log =~ "Automatically updated the following Skate alerts: 123"
        assert result == :ok

        non_updated_alert = Alerts.get_by_alert_id!("456")

        assert non_updated_alert.last_modified_timestamp == ~U[2026-05-12 13:37:59Z]

        updated_alert = Alerts.get_by_alert_id!("123")

        assert %{
                 alert_id: "123",
                 closed_timestamp: nil,
                 skate_detour_id: 7,
                 active_period_end: nil,
                 cause: :OTHER_CAUSE,
                 cause_detail: "DRAWBRIDGE_BEING_RAISED",
                 original_route_selections: ["1|1"],
                 original_stop_selections: ["Massachusetts Ave @ Pearl St|72"],
                 original_direction_selections: ["Inbound|1"],
                 header_text:
                   "Route 1 inbound is detoured, skipping Massachusetts Ave @ Pearl St due to a drawbridge being raised. The closest stops with service are Massachusetts Ave opp Inman St and Massachusetts Ave @ Sidney St.",
                 description_text: "Skipped inbound stops:\nMassachusetts Ave @ Pearl St",
                 service_effect_text: "Route 1 detour",
                 severity: 7
               } = updated_alert

        assert DateTime.compare(
                 updated_alert.last_modified_timestamp,
                 original_created_at_timestamp
               ) == :gt

        assert DateTime.compare(updated_alert.created_at, original_created_at_timestamp) == :eq

        assert %AlertsUI.Models.InformedEntity{
                 route_type: 3,
                 direction_id: 1,
                 activities: [:BOARD, :EXIT],
                 stop_id: "72",
                 agency_id: "1"
               } = hd(updated_alert.informed_entity)
      end
    end

    test "correctly modifies alerts open skate alerts whose missed stops are child stops" do
      bus_route = %Route{
        direction_names: %{0 => "Outbound", 1 => "Inbound"},
        sort_order: 1,
        id: "741",
        type: 3,
        name: "SL1"
      }

      stop_zero = %Stop{
        id: "place-crtst",
        type: 3,
        name: "Courthouse"
      }

      stop_one = %Stop{
        id: "place-wtcst",
        type: 3,
        name: "World Trade Center"
      }

      stop_two = %Stop{
        id: "place-conrd",
        type: 3,
        name: "Silver Line Way"
      }

      stop_three = %Stop{
        id: "17091",
        type: 3,
        name: "Terminal A"
      }

      with_mocks([
        {RoutesRepo, [],
         [
           by_type: fn _ -> [bus_route] end,
           get: fn _, _ -> bus_route end
         ]},
        {RoutePatternsRepo, [],
         [
           by_route_id: fn _, _opts ->
             [
               %RoutePattern{
                 direction_id: 0,
                 stops: [stop_one, stop_two],
                 route_id: bus_route.id,
                 listed_route: true,
                 id: "rp_1"
               }
             ]
           end,
           included_stops_by_route_id: fn _route_id, _direction -> [stop_one, stop_two] end
         ]},
        {StopsRepo, [],
         [
           by_route: fn _, _, _ -> [stop_zero, stop_one, stop_two, stop_three] end,
           get_parent: fn
             "74612" -> stop_zero
             "74613" -> stop_one
           end,
           all: fn
             ["filter[id]": "74613,place-conrd"], _opts ->
               [
                 %Stop{
                   id: "74613",
                   type: 3,
                   name: "World Trade Center",
                   parent_id: stop_one.id
                 },
                 stop_two
               ]

             ["filter[id]": "74612,17091"], _opts ->
               [
                 %Stop{
                   id: "74612",
                   type: 3,
                   name: "Courthouse",
                   parent_id: stop_zero.id
                 },
                 stop_three
               ]

             ["filter[id]": "place-wtcst"], _opts ->
               [stop_one]
           end
         ]}
      ]) do
        set_log_level(:info)

        original_created_at_timestamp = ~U[2026-03-10 14:30:54Z]

        insert(:alert, %{
          alert_id: "123",
          skate_detour_id: 11,
          active_period_end: nil,
          original_route_selections: ["SL1|#{bus_route.id}"],
          original_stop_selections: ["World Trade Center|place-wtcst"],
          original_direction_selections: ["Outbound|0"],
          informed_entity: [
            build(:informed_entity, %{route_id: "741", route_type: 3, stop_id: "place-wtcst"})
          ],
          header_text: "original header text",
          description_text: "original description text",
          service_effect_text: "original service effect text",
          severity: 7,
          created_at: original_created_at_timestamp,
          last_modified_timestamp: original_created_at_timestamp
        })

        {result, log} = with_log(fn -> SkateDetourUpdateWorker.perform(%Job{args: %{}}) end)
        assert log =~ "Automatically updated the following Skate alerts: 123"
        assert result == :ok

        updated_alert = Alerts.get_by_alert_id!("123")

        assert true

        assert %{
                 original_stop_selections: [
                   "Silver Line Way|place-conrd",
                   "World Trade Center|place-wtcst"
                 ],
                 header_text:
                   "SL1 outbound is detoured, skipping Silver Line Way and World Trade Center due to a parade. The closest stops with service are Courthouse and Terminal A.",
                 description_text: "Skipped outbound stops:\nSilver Line Way\nWorld Trade Center",
                 service_effect_text: "SL1 detour"
               } = updated_alert
      end
    end
  end
end
