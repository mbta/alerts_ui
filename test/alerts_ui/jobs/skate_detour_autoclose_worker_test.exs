defmodule AlertsUI.Jobs.SkateAutocloseWorkerTest do
  use AlertsUI.DataCase, async: false
  import AlertsUI.Support.Factory
  import ExUnit.CaptureLog
  import Test.Support.Helpers
  alias AlertsUI.Alerts
  alias AlertsUI.Jobs.SkateDetourAutocloseWorker
  alias Oban.Job

  describe "perform" do
    test "logs correctly when there are no alerts to close" do
      set_log_level(:info)

      insert(:alert, %{
        alert_id: "123",
        skate_detour_id: 7,
        active_period_end: nil
      })

      insert(:alert, %{
        alert_id: "456",
        active_period_end: nil
      })

      {result, log} = with_log(fn -> SkateDetourAutocloseWorker.perform(%Job{args: %{}}) end)

      assert result == :ok
      assert log =~ "[info] No Skate alerts were automatically closed"
      assert is_nil(Alerts.get_by_alert_id!("123").closed_timestamp)
      assert is_nil(Alerts.get_by_alert_id!("456").closed_timestamp)
    end

    test "correctly closes open alerts with skate ids that don't appear in list" do
      set_log_level(:info)

      insert(:alert, %{
        alert_id: "123",
        skate_detour_id: 5001,
        active_period_end: nil
      })

      insert(:alert, %{
        alert_id: "456",
        skate_detour_id: 7,
        active_period_end: nil
      })

      insert(:alert, %{
        alert_id: "789",
        skate_detour_id: 5002,
        active_period_end: nil
      })

      {result, log} = with_log(fn -> SkateDetourAutocloseWorker.perform(%Job{args: %{}}) end)

      assert result == :ok
      assert log =~ "[info] Automatically closed the following Skate alerts: 123, 789"
      assert !is_nil(Alerts.get_by_alert_id!("123").closed_timestamp)
      assert is_nil(Alerts.get_by_alert_id!("456").closed_timestamp)
      assert !is_nil(Alerts.get_by_alert_id!("789").closed_timestamp)
    end
  end
end
