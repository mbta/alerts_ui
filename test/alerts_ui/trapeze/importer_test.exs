defmodule AlertsUI.Trapeze.ImporterTest do
  @moduledoc false
  alias AlertsUI.Trapeze.Models.TrapezeMonitor
  use AlertsUI.DataCase, async: false

  alias AlertsUI.Models.Alert
  alias AlertsUI.Trapeze.Importer
  alias AlertsUI.Trapeze.Monitor
  alias AlertsUI.Trapeze.SFTP
  alias MBTAV3API.Facilities.Facility
  alias MBTAV3API.Facilities.Repo, as: FacilitiesRepo
  alias MBTAV3API.Stops.Stop

  import AlertsUI.Support.Factory
  import ExUnit.CaptureLog
  import Test.Support.Helpers

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

  def latest_monitor,
    do: Repo.one(from t in TrapezeMonitor, order_by: [desc: t.created_at], limit: 1)

  describe "perform" do
    test "with incomplete configuration stops early" do
      with_mocks([
        {FacilitiesRepo, [], [get: fn _ -> @facility end]}
      ]) do
        reassign_env(:alerts_ui, :trapeze_sftp_host, "")
        reassign_env(:alerts_ui, :trapeze_sftp_port, "")
        reassign_env(:alerts_ui, :trapeze_sftp_user, "")
        reassign_env(:alerts_ui, :trapeze_sftp_password, "")
        reassign_env(:alerts_ui, :trapeze_sftp_filename, "")

        {_, log} = with_log(fn -> Importer.perform([], %{}) end)

        assert log =~ ~r/warning.*AlertsUI.Trapeze.Monitor: Missing Configuration/
      end
    end

    test "in production without confirmation stops early" do
      with_mocks([
        {FacilitiesRepo, [], [get: fn _ -> @facility end]}
      ]) do
        reassign_env(:alerts_ui, :trapeze_sftp_host, "host")
        reassign_env(:alerts_ui, :trapeze_sftp_port, "port")
        reassign_env(:alerts_ui, :trapeze_sftp_user, "user")
        reassign_env(:alerts_ui, :trapeze_sftp_password, "password")
        reassign_env(:alerts_ui, :trapeze_sftp_filename, "filename")
        reassign_env(:alerts_ui, :sentry_env, "prod")
        reassign_env(:alerts_ui, :trapeze_in_production, "false")

        {_, log} = with_log(fn -> Importer.perform([], %{}) end)

        assert log =~ ~r/warning.*AlertsUI.Trapeze.Monitor: Running in Production/
      end
    end

    test "that in the right env it completes" do
      with_mocks([
        {FacilitiesRepo, [], [get: fn _ -> @facility end]},
        {SFTP, [],
         [
           source_description: fn ->
             %{host: "host", port: 22, user: "user", filename: "filename", password: "password"}
           end,
           fetch: fn _ -> {:ok, {[], nil}} end
         ]}
      ]) do
        reassign_env(:alerts_ui, :sentry_env, "test")
        before_monitor = latest_monitor()

        with_log(fn -> Importer.perform([], %{}) end)

        after_monitor = latest_monitor()
        assert before_monitor == nil
        assert after_monitor != nil
      end
    end
  end

  describe "process_feed" do
    test "turns Trapeze lines into Alerts" do
      with_mock(FacilitiesRepo,
        get: fn _ -> @facility end
      ) do
        input = [
          "2026-02-17T12:52:38-05:00|FP-DWNXST-ELEV-891|ELEV-891|ELEVATOR, DOWNTOWN CROSSING EL-891, OL NB-FRANKLIN ST|ORANGE LINE,RED LINE - MAIN|310-2026-184|2026-01-12T15:50:03+00:00|2026-01-12T15:52:14+00:00|2026-01-12T15:50:03+00:00||OPEN",
          "2026-02-17T12:52:38-05:00|FP-STATST-ESCL-502|ESCL-502|ESCALATOR, STATE ESC-502, BLUE LINE NB--LOBBY|BLUE LINE,ORANGE LINE|310-2026-180|2026-01-12T11:29:05+00:00|2026-01-12T11:31:37+00:00|2026-01-12T11:29:05+00:00|2026-01-12T13:29:05+00:00|CLOSED",
          "2026-02-17T12:52:38-05:00|FP-GOVCST-ESCL-444|ESCL-444|ESCALATOR, GOVERNMENT CENTER ESC-444, ST -LVL - GL|BLUE LINE|310-2026-163|2026-01-11T05:23:58+00:00|2026-01-11T05:25:38+00:00|2026-01-11T05:23:58+00:00||OPEN",
          "2026-02-17T12:52:38-05:00|FS-GOVCST-ESCL-800|ESCL-800|special secret escalator|BLUE LINE|310-2026-222|2026-01-11T05:23:58+00:00|2026-01-11T05:25:38+00:00|2026-01-11T05:23:58+00:00||OPEN"
        ]

        with_log(fn ->
          Monitor.start()
          Importer.process_feed(input)
          Monitor.close()
        end)

        alert_1 = get("310-2026-184")
        alert_2 = get("310-2026-180")
        alert_3 = get("310-2026-163")
        alert_4 = get("310-2026-222")

        assert alert_1
        assert alert_1.closed_timestamp == nil
        assert alert_2 == nil
        assert alert_3
        assert alert_3.closed_timestamp == nil
        assert alert_4 == nil
      end
    end

    test "handles multiple work orders for the same elevator" do
      with_mock(FacilitiesRepo,
        get: fn _ -> @facility end
      ) do
        input = [
          "2026-02-17T12:52:38-05:00|FP-DWNXST-ELEV-891|ELEV-891|ELEVATOR, DOWNTOWN CROSSING EL-891, OL NB-FRANKLIN ST|ORANGE LINE,RED LINE - MAIN|310-2026-184|2026-01-12T15:50:03+00:00|2026-01-12T15:52:14+00:00|2026-01-12T15:50:03+00:00||OPEN",
          "2026-02-17T12:52:38-05:00|FP-DWNXST-ELEV-891|ELEV-891|ELEVATOR, DOWNTOWN CROSSING EL-891, OL NB-FRANKLIN ST|ORANGE LINE,RED LINE - MAIN|310-2026-999|2026-01-12T15:50:03+00:00|2026-01-12T15:52:14+00:00|2026-01-12T15:50:03+00:00||OPEN"
        ]

        with_log(fn ->
          Monitor.start()
          Importer.process_feed(input)
          Monitor.close()
        end)

        alert_1 = get("310-2026-184")
        alert_2 = get("310-2026-999")

        assert alert_1
        assert alert_2
      end
    end
  end

  describe "persist" do
    test "alert does exist, and closed_timestamp is nil, save it" do
      existing_alert =
        insert(:alert, %{
          work_order_id: "TESTORDER1",
          closed_timestamp: nil
        })

      result =
        Importer.persist(%{
          primary_service_type: "access",
          effect_name: "Elevator Closure",
          original_facility_selections: ["stop|123"],
          work_order_id: "TESTORDER1",
          closed_timestamp: nil,
          status: :open
        })

      alert = Repo.reload!(existing_alert)
      assert alert.closed_timestamp == nil
      assert result == {:ok, "IGNORE open, no change"}
    end

    test "alert does exist, and closed_timestamp exists, save it" do
      existing_alert =
        insert(:alert, %{
          work_order_id: "TESTORDER1",
          closed_timestamp: nil
        })

      result =
        Importer.persist(%{
          primary_service_type: "access",
          effect_name: "Elevator Closure",
          original_facility_selections: ["stop|123"],
          work_order_id: "TESTORDER1",
          closed_timestamp: ~U[2026-02-19 08:01:00Z],
          status: :closed
        })

      alert = Repo.reload!(existing_alert)
      assert alert.closed_timestamp != nil
      assert result == {:ok, "CLOSE"}
    end

    test "alert does not exist, but closed_timestamp is nil, save it" do
      result =
        Importer.persist(
          build(:alert_map, %{
            primary_service_type: "access",
            effect_name: "Elevator Closure",
            original_facility_selections: ["stop|123"],
            work_order_id: "TESTORDER1",
            closed_timestamp: nil,
            status: :open
          })
        )

      maybe_alert = get("TESTORDER1")
      assert maybe_alert != nil
      assert result == {:ok, "CREATE"}
    end

    test "alert does not exist, but closed_timestamp exists, ignore it" do
      result =
        Importer.persist(%{
          primary_service_type: "access",
          effect_name: "Elevator Closure",
          original_facility_selections: ["stop|123"],
          work_order_id: "TESTORDER1",
          closed_timestamp: ~U[2026-02-19 08:01:00Z],
          status: :closed
        })

      maybe_alert = get("TESTORDER1")
      assert maybe_alert == nil
      assert result == {:ok, "IGNORE already closed"}
    end

    test "alert is closed, but open in import, ignore it" do
      existing_alert =
        insert(:alert, %{
          work_order_id: "TESTORDER1",
          closed_timestamp: ~U[2026-02-14T12:00:00Z]
        })

      result =
        Importer.persist(%{
          primary_service_type: "access",
          effect_name: "Elevator Closure",
          original_facility_selections: ["stop|123"],
          work_order_id: "TESTORDER1",
          closed_timestamp: nil,
          status: :open
        })

      alert = Repo.reload!(existing_alert)
      assert alert.closed_timestamp == ~U[2026-02-14T12:00:00Z]
      assert result == {:ok, "IGNORE closed manually"}
    end

    test "alert is closed, but closed in import, ignore it" do
      existing_alert =
        insert(:alert, %{
          work_order_id: "TESTORDER1",
          closed_timestamp: ~U[2026-02-14T12:00:00Z]
        })

      result =
        Importer.persist(%{
          primary_service_type: "access",
          effect_name: "Elevator Closure",
          original_facility_selections: ["stop|123"],
          work_order_id: "TESTORDER1",
          closed_timestamp: ~U[2026-02-14T12:00:00Z],
          status: :closed
        })

      alert = Repo.reload!(existing_alert)
      assert alert.closed_timestamp == ~U[2026-02-14T12:00:00Z]
      assert result == {:ok, "IGNORE closed, no change"}
    end
  end
end
