defmodule AlertsUI.Trapeze.MonitorTest do
  @moduledoc false
  alias AlertsUI.Trapeze.Models.TrapezeMonitor
  alias AlertsUI.Trapeze.Monitor
  use AlertsUI.DataCase, async: false

  import AlertsUI.Support.Factory
  import ExUnit.CaptureLog
  import Mock

  @now DateTime.from_iso8601("2026-02-14T12:00:00-05:00")
       |> elem(1)
       |> DateTime.truncate(:second)
  @two_and_a_half_minutes_ago @now
                              |> DateTime.add(-2, :minute)
                              |> DateTime.add(-30, :second)
  @seven_minutes_ago @now
                     |> DateTime.add(-7, :minute)
  @fifteen_and_a_quarter_minutes_ago @now
                                     |> DateTime.add(-15, :minute)
                                     |> DateTime.add(-15, :second)

  @feed_open_1 "2026-02-14T11:59:00-05:00|FP-DWNXST-ELEV-891|ELEV-891|ELEVATOR, DOWNTOWN CROSSING EL-891, OL NB-FRANKLIN ST|ORANGE LINE,RED LINE - MAIN|310-2026-184|2026-01-12T15:50:03+00:00|2026-01-12T15:52:14+00:00|2026-01-12T15:50:03+00:00||OPEN"
  @feed_closed_1 "2026-02-14T11:59:00-05:00|FP-STATST-ESCL-502|ESCL-502|ESCALATOR, STATE ESC-502, BLUE LINE NB--LOBBY|BLUE LINE,ORANGE LINE|310-2026-180|2026-01-12T11:29:05+00:00|2026-01-12T11:31:37+00:00|2026-01-12T11:29:05+00:00|2026-02-14T11:59:00-05:00|CLOSED"
  @feed_open_2 "2026-02-14T11:59:00-05:00|FP-GOVCST-ESCL-444|ESCL-444|ESCALATOR, GOVERNMENT CENTER ESC-444, ST -LVL - GL|BLUE LINE|310-2026-163|2026-01-11T05:23:58+00:00|2026-01-11T05:25:38+00:00|2026-01-11T05:23:58+00:00||OPEN"

  setup_all do
    Logger.configure(level: :info)

    on_exit(fn ->
      Logger.configure(level: :warning)
    end)
  end

  describe "start/0" do
    setup_with_mocks([{DateTime, [:passthrough], [now!: fn _ -> @now end]}]) do
      :ok
    end

    test "with no successful checks prints a warning" do
      {_, log} = with_log(fn -> Monitor.start() end)

      assert log =~ ~r/warning.*AlertsUI.Trapeze.Monitor: No previously successful checks!/
    end

    test "with a older successful checks prints a error" do
      insert(:trapeze_monitor, %{result: "ok", checked_at: @fifteen_and_a_quarter_minutes_ago})

      {_, log} = with_log(fn -> Monitor.start() end)

      assert log =~
               ~r/error.*AlertsUI.Trapeze.Monitor: Last successful check 15 minutes, 15 seconds ago: 2026-02-14T16:44:45Z/
    end

    test "with a less recent successful checks prints a warning" do
      insert(:trapeze_monitor, %{result: "ok", checked_at: @seven_minutes_ago})

      {_, log} = with_log(fn -> Monitor.start() end)

      assert log =~
               ~r/warning.*AlertsUI.Trapeze.Monitor: Last successful check 7 minutes, 0 seconds ago: 2026-02-14T16:53:00Z/
    end

    test "with a recent successful checks prints a message" do
      insert(:trapeze_monitor, %{result: "ok", checked_at: @two_and_a_half_minutes_ago})

      {_, log} = with_log(fn -> Monitor.start() end)

      assert log =~
               ~r/info.*AlertsUI.Trapeze.Monitor: Last successful check 2 minutes, 30 seconds ago: 2026-02-14T16:57:30Z/
    end
  end

  describe "processing/2" do
    setup_with_mocks([{DateTime, [:passthrough], [now!: fn _ -> @now end]}]) do
      :ok
    end

    test "it logs info about the feed" do
      feed = [@feed_open_1, @feed_closed_1, @feed_open_2]
      checksum = :crypto.hash(:md5, feed |> Enum.join("\n")) |> Base.encode16()

      {_, log} =
        with_log(fn ->
          Monitor.start()

          Monitor.processing(feed, ~N[2026-02-14T11:58:00])
        end)

      report = Monitor.report()
      assert report.checked_at == @now
      assert report.processed_at == ~U[2026-02-14T16:58:00Z]
      assert report.checksum == checksum

      assert log =~
               ~r/info.*AlertsUI.Trapeze.Monitor: Processing 3 entries. Checksum 6DC20286CC1989A0961A31FA8942B629./
    end

    test "it gets check time from feed if unavailable" do
      feed = [@feed_open_1, @feed_closed_1, @feed_open_2]

      with_log(fn ->
        Monitor.start()

        Monitor.processing(feed, nil)
      end)

      report = Monitor.report()
      assert report.processed_at == ~U[2026-02-14T16:59:00Z]
    end

    test "it logs an info message if feed updated recently" do
      feed = [@feed_open_1, @feed_closed_1, @feed_open_2]

      {_, log} =
        with_log(fn ->
          Monitor.start()

          Monitor.processing(feed, ~N[2026-02-14T11:58:00])
        end)

      report = Monitor.report()
      assert report.processed_at == ~U[2026-02-14T16:58:00Z]

      assert log =~
               ~r/info.*AlertsUI.Trapeze.Monitor: Work Order file updated 2 minutes, 0 seconds ago: 2026-02-14T16:58:00Z/
    end

    test "it logs a warning message if feed updated 30-120 minutes ago" do
      feed = [@feed_open_1, @feed_closed_1, @feed_open_2]

      {_, log} =
        with_log(fn ->
          Monitor.start()

          Monitor.processing(feed, ~N[2026-02-14T11:15:22])
        end)

      report = Monitor.report()
      assert report.processed_at == ~U[2026-02-14T16:15:22Z]

      assert log =~
               ~r/warning.*AlertsUI.Trapeze.Monitor: Work Order file updated 44 minutes, 38 seconds ago: 2026-02-14T16:15:22Z/
    end

    test "it logs an error message if feed updated 2+ hours ago" do
      feed = [@feed_open_1, @feed_closed_1, @feed_open_2]

      {_, log} =
        with_log(fn ->
          Monitor.start()

          Monitor.processing(feed, ~N[2026-02-14T08:08:08])
        end)

      report = Monitor.report()
      assert report.processed_at == ~U[2026-02-14T13:08:08Z]

      assert log =~
               ~r/error.*AlertsUI.Trapeze.Monitor: Work Order file updated 231 minutes, 52 seconds ago: 2026-02-14T13:08:08Z/
    end
  end

  describe "result/1" do
    setup_with_mocks([
      {DateTime, [:passthrough], [now!: fn _ -> @now end]}
    ]) do
      :ok
    end

    test "errors with Exceptions with messages log the Exception + message" do
      with_log(fn -> Monitor.start() end)

      try do
        raise "a message!"
      rescue
        e ->
          with_log(fn -> Monitor.result({:error, e}) end)
          report = Monitor.report()
          assert report.result == "error"
          assert report.reason == "Unable to import. RuntimeError: a message!"
      end
    end

    test "logs the reason for result of :warning, and records it in Monitor" do
      {_, log} =
        with_log(fn ->
          Monitor.start()

          Monitor.result({:warning, "a warning!"})
        end)

      report = Monitor.report()
      assert report.result == "warning"
      assert report.reason == "a warning!"
      assert log =~ ~r/warning.*AlertsUI.Trapeze.Monitor: a warning!/
    end

    test "logs nothing for result of :ok, but records it in Monitor" do
      {_, log} =
        with_log(fn ->
          Monitor.start()

          Monitor.result({:ok, "ignored"})
        end)

      report = Monitor.report()
      assert report.result == "ok"
      assert report.reason == "ignored"
      refute log =~ ~r/info.*AlertsUI.Trapeze.Monitor: ignored/
    end
  end

  describe "work orders" do
    setup_with_mocks([
      {DateTime, [:passthrough], [now!: fn _ -> @now end]}
    ]) do
      :ok
    end

    test "start_work_order starts a new line entry" do
      with_log(fn ->
        Monitor.start()

        Monitor.start_work_order("Test Line 1")
        Monitor.start_work_order("Test Line 2")
      end)

      report = Monitor.report()
      assert report.work_order_changes == ["Processing: Test Line 2", "Processing: Test Line 1"]
    end

    test "finish_work_order ends and logs a line entry info" do
      {_, log} =
        with_log(fn ->
          Monitor.start()
          Monitor.start_work_order("WORKORDER-123")
          Monitor.start_work_order("WORKORDER-789|OPEN")

          Monitor.finish_work_order({:ok, "created"})
        end)

      assert log =~ ~r/info.*AlertsUI.Trapeze.Monitor: Processing: WORKORDER-789/
    end

    test "finish_work_order ends and logs a line entry error" do
      {_, log} =
        with_log(fn ->
          Monitor.start()
          Monitor.start_work_order("ABC-123")
          Monitor.start_work_order("WORKORDER-789")

          Monitor.finish_work_order({:error, "silly"})
        end)

      assert log =~ ~r/error.*AlertsUI.Trapeze.Monitor: Processing: WORKORDER-789 silly/
    end
  end

  describe "finish/0" do
    test "creates a TrapezeMonitor record" do
      with_log(fn ->
        Monitor.start()
        Monitor.start_work_order("WORKORDER")
        Monitor.finish_work_order({:ok, "gravity"})
        Monitor.result({:ok, "cool"})

        Monitor.finalize()
      end)

      record = Repo.one(from t in TrapezeMonitor, order_by: [desc: t.created_at], limit: 1)
      assert record.result == "ok"
      assert record.reason == "cool"
      assert record.work_order_changes == ["Processing: WORKORDER gravity"]
    end
  end
end
