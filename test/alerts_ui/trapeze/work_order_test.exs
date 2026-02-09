defmodule AlertsUI.Trapeze.WorkOrderTest do
  @moduledoc false
  alias AlertsUI.Trapeze.WorkOrder
  use AlertsUI.DataCase, async: false

  alias AlertsUI.Models.Alert
  alias MBTAV3API.Facilities.Facility
  alias MBTAV3API.Facilities.Repo, as: FacilitiesRepo
  alias MBTAV3API.Stops.Stop

  import Mock

  @facility %Facility{
    id: "349",
    type: "ESCALATOR",
    short_name: "Platform to Russell Field",
    long_name: "Alewife Escalator 349 (Platform to Russell Field)",
    stop: %Stop{
      id: "place-alfcl",
      name: "Aquarium",
      type: "stop"
    },
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

        output = input |> WorkOrder.from_trapeze_line()

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
  end

  describe "to_params" do
    test "turns WorkOrder into Alert params" do
      with_mock(FacilitiesRepo,
        get: fn _ -> @facility end
      ) do
        input =
          "2026-02-17T12:52:38-05:00|FP-DWNXST-ELEV-891|ELEV-891|ELEVATOR, DOWNTOWN CROSSING EL-891, OL NB-FRANKLIN ST|ORANGE LINE,RED LINE - MAIN|310-2026-184|2026-01-12T15:50:03+00:00|2026-01-12T15:52:14+00:00|2026-01-12T15:50:03+00:00|1999-12-31T11:59:59+00:00|OPEN"

        output =
          input
          |> WorkOrder.from_trapeze_line()
          |> WorkOrder.to_params()

        assert output == %{
                 active_period_start: ~U[2026-01-12 15:50:03Z],
                 active_period_end: nil,
                 closed_timestamp: nil,
                 notification_period_start: ~U[2026-01-12 15:50:03Z],
                 notification_period_end: nil,
                 primary_service_type: "access",
                 cause_detail: "maintenance",
                 cause: :MAINTENANCE,
                 combination: :ACCESS,
                 duration_certainty: :UNKNOWN,
                 effect_detail: "ELEVATOR CLOSURE",
                 effect_name: "Elevator Closure",
                 effect: :ACCESSIBILITY_ISSUE,
                 service_effect_text: "elevator unavailable",
                 original_facility_selections: [
                   "ELEVATOR, DOWNTOWN CROSSING EL-891, OL NB-FRANKLIN ST|891"
                 ],
                 severity_level: :WARNING,
                 severity: 3,
                 work_order_id: "310-2026-184",
                 informed_entity: [
                   %{facility_id: "891"}
                 ],
                 header_text:
                   "Alewife Escalator 349 (Platform to Russell Field) unavailable due to maintenance",
                 description_text: "",
                 source: :TRAPEZE,
                 status: :open
               }
      end
    end
  end
end
