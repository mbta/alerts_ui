defmodule AlertsUI.Trapeze.WorkOrderTest do
  @moduledoc false
  alias AlertsUI.Trapeze.WorkOrder
  use AlertsUI.DataCase, async: false

  alias AlertsUI.Models.Alert
  alias MBTAV3API.Facilities.Facility
  alias MBTAV3API.Facilities.Repo, as: FacilitiesRepo
  alias MBTAV3API.Stops.Repo, as: StopsRepo
  alias MBTAV3API.Stops.Stop

  import Mock

  @stop %Stop{
    id: "place-alfcl",
    name: "Aquarium",
    type: "stop",
    child_ids: ["place"]
  }
  @facility %Facility{
    id: "349",
    type: "ESCALATOR",
    short_name: "Platform to Russell Field",
    long_name: "Alewife Escalator 349 (Platform to Russell Field)",
    stop: @stop,
    latitude: 42.395428,
    longitude: -71.142483,
    properties: [
      %{name: "direction", value: "up"},
      %{name: "excludes-stop", value: 141},
      %{name: "excludes-stop", value: 9_070_061},
      %{name: "excludes-stop", value: "door-alfcl-alewife"},
      %{name: "excludes-stop", value: "door-alfcl-busway"},
      %{name: "excludes-stop", value: "door-alfcl-cambridgepark"},
      %{name: "excludes-stop", value: "door-alfcl-pathbusway"},
      %{name: "excludes-stop", value: "door-alfcl-steel"}
    ]
  }

  def get(work_order_id),
    do: Repo.one(from a in Alert, where: a.work_order_id == ^work_order_id)

  describe "from_trapeze_line" do
    test "turns Trapeze lines into WorkOrders" do
      with_mock(FacilitiesRepo,
        get: fn _ -> @facility end
      ) do
        input =
          "2026-02-17T12:52:38-05:00|FP-DWNXST-ELEV-891|ELEV-891|ELEVATOR, DOWNTOWN CROSSING EL-891, OL NB-FRANKLIN ST|ORANGE LINE,RED LINE - MAIN|310-2026-184|2026-01-12T15:50:03+00:00|2026-01-12T15:52:14+00:00|2026-01-12T15:50:03+00:00||OPEN"

        {:ok, output} = input |> WorkOrder.from_trapeze_line()

        assert output == %WorkOrder{
                 file_process_datetime: ~U[2026-02-17 17:52:38Z],
                 equipment_id: "FP-DWNXST-ELEV-891",
                 effect: :elevator,
                 facility_id: "891",
                 asset_id: "ELEV-891",
                 description: "ELEVATOR, DOWNTOWN CROSSING EL-891, OL NB-FRANKLIN ST",
                 lines: "ORANGE LINE,RED LINE - MAIN",
                 work_order_id: "310-2026-184",
                 create_datetime: ~U[2026-01-12 15:50:03Z],
                 update_datetime: ~U[2026-01-12 15:52:14Z],
                 start_datetime: ~U[2026-01-12 15:50:03Z],
                 end_datetime: nil,
                 status: :open
               }
      end
    end

    test "skips lines that are not public facilities" do
      with_mock(FacilitiesRepo,
        get: fn _ -> @facility end
      ) do
        input =
          "2026-02-17T12:52:38-05:00|FS-DWNXST-ELEV-891|ELEV-891|ELEVATOR, DOWNTOWN CROSSING EL-891, OL NB-FRANKLIN ST|ORANGE LINE,RED LINE - MAIN|310-2026-184|2026-01-12T15:50:03+00:00|2026-01-12T15:52:14+00:00|2026-01-12T15:50:03+00:00||OPEN"

        output = input |> WorkOrder.from_trapeze_line()

        assert output == {:skip, "equipment_id (column B) marked FS"}
      end
    end
  end

  describe "to_params" do
    test "turns WorkOrder into Alert params" do
      dt = DateTime.new!(~D[2026-03-01], ~T[12:34:56])

      with_mocks([
        {FacilitiesRepo, [], [get: fn _ -> @facility end]},
        {DateTime, [:passthrough], [utc_now: fn -> dt end]},
        {StopsRepo, [], [get: fn _ -> @stop end, get!: fn _ -> @stop end]}
      ]) do
        input =
          "2026-02-17T12:52:38-05:00|FP-DWNXST-ELEV-891|ELEV-891|ELEVATOR, DOWNTOWN CROSSING EL-891, OL NB-FRANKLIN ST|ORANGE LINE,RED LINE - MAIN|310-2026-184|2026-01-12T15:50:03+00:00|2026-01-12T15:52:14+00:00|2026-01-12T15:50:03+00:00|1999-12-31T11:59:59+00:00|OPEN"

        {:ok, wo} = WorkOrder.from_trapeze_line(input)
        {:ok, output} = WorkOrder.to_params(wo)

        assert output == %{
                 active_period_start: ~N[2026-03-01 07:34:56],
                 active_period_end: nil,
                 closed_timestamp: nil,
                 notification_period_start: ~N[2026-01-12 10:50:03],
                 notification_period_end: nil,
                 cause_detail: "MAINTENANCE",
                 cause: :MAINTENANCE,
                 combination: :ACCESS,
                 effect_detail: "ELEVATOR_CLOSURE",
                 effect_name: "Elevator Closure",
                 effect: "ACCESSIBILITY_ISSUE",
                 severity: 3,
                 work_order_id: "310-2026-184",
                 header_text:
                   "Alewife Escalator 349 (Platform to Russell Field) is unavailable due to maintenance.",
                 description_text: nil,
                 service_effect_text: "Aquarium elevator unavailable",
                 source: :TRAPEZE,
                 status: :open,
                 active_period_end_specifier: :until_further_notice,
                 active_period_start_specifier: :custom,
                 alert_timing: :one_time,
                 stops_with_context: [],
                 direction: "",
                 facility_ids: ["891"],
                 notification_specifier: :now,
                 reminder_times: [],
                 route_ids: [],
                 route_type: nil,
                 route_types_by_id: %{},
                 service_types: [],
                 stop_ids: [],
                 stop_names_and_ids: [],
                 trip_ids: [],
                 trip_information_by_id: []
               }
      end
    end
  end
end
