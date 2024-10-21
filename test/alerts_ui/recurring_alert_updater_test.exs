defmodule AlertsUI.RecurringAlertUpdaterTest do
  use AlertsUI.DataCase, async: false
  import AlertsUI.Support.Factory
  alias AlertsUI.RecurringAlertUpdater
  alias Oban.Job

  describe "perform" do
    test "runs successfully" do
      insert(:alert, %{
        alert_id: "123",
        recurrence_days: [:monday, :tuesday, :wednesday, :thursday, :friday],
        active_period: [
          build(:active_period, %{
            start: ~U[2024-10-22 13:00:00Z],
            end: ~U[2024-10-23 01:00:00Z]
          }),
          build(:active_period, %{
            start: ~U[2024-10-23 13:00:00Z],
            end: ~U[2024-10-24 01:00:00Z]
          })
        ],
        active_period_end: nil
      })

      assert RecurringAlertUpdater.perform(%Job{args: %{}}) == :ok
    end
  end
end
