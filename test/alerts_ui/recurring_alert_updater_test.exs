defmodule AlertsUI.RecurringAlertUpdaterTest do
  use AlertsUI.DataCase, async: false
  import AlertsUI.Support.Factory
  import Mock
  import ExUnit.CaptureLog
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

    test "handles errors" do
      alert =
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

      with_mock(AlertsUI.Alerts,
        list_all_open: fn -> [alert] end,
        filter_on_notification_period_start: fn _ -> [alert] end,
        update_recurring_active_periods: fn _alert -> {:error, "failed to update"} end
      ) do
        {result, log} =
          with_log(fn ->
            RecurringAlertUpdater.perform(%Job{args: %{}})
          end)

        assert result == :ok
        assert log =~ "failed to update"
      end
    end
  end
end
