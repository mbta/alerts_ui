defmodule AlertsUI.Jobs.AlertValidationUpcomingWorkerTest do
  use AlertsUI.DataCase, async: false
  import ExUnit.CaptureLog
  import Test.Support.Helpers
  import Mock
  alias AlertsUI.Jobs.AlertValidationUpcomingWorker
  alias AlertsUI.Models.LastGTFSValidation
  alias Oban.Job

  describe "perform" do
    # test "runs successfully" do
    #   assert AlertValidationUpcomingWorker.perform(%Job{args: %{}}) == :ok
    # end

    test "runs validator if no time is stored" do
      with_mock(Req,
        get: fn _ ->
          {:ok,
           %Req.Response{
             body: %{
               "data" => %{
                 "attributes" => %{"route" => %{"last_updated" => "2025-11-01T14:45:54Z"}}
               }
             }
           }}
        end
      ) do
        set_log_level(:info)

        {_result, log} =
          with_log(fn ->
            AlertValidationUpcomingWorker.perform(%Job{args: %{}})
          end)

        assert log =~ "New GTFS detected in dev. Updating stored time and validating alerts"
        refute is_nil(LastGTFSValidation.get_most_recent_validation())
      end
    end

    test "runs validator if stored time is before incoming time" do
      with_mocks([
        {Req, [],
         [
           get: fn _ ->
             {:ok,
              %Req.Response{
                body: %{
                  "data" => %{
                    "attributes" => %{"route" => %{"last_updated" => "2025-11-10T14:45:54Z"}}
                  }
                }
              }}
           end
         ]},
        {DateTime, [:passthrough],
         [
           utc_now: fn -> ~U[2025-11-10 15:45:54Z] end
         ]}
      ]) do
        set_log_level(:info)
        LastGTFSValidation.store_last_gtfs_validation(~U[2025-11-01 14:45:54Z])

        {_result, log} =
          with_log(fn ->
            AlertValidationUpcomingWorker.perform(%Job{args: %{}})
          end)

        assert LastGTFSValidation.get_most_recent_validation() == ~U[2025-11-10 15:45:54Z]
        assert log =~ "New GTFS detected in dev. Updating stored time and validating alerts"
      end
    end

    test "doesn't run validator if stored time is after incoming time" do
      with_mock(Req,
        get: fn _ ->
          {:ok,
           %Req.Response{
             body: %{
               "data" => %{
                 "attributes" => %{"route" => %{"last_updated" => "2025-11-01T14:45:54Z"}}
               }
             }
           }}
        end
      ) do
        set_log_level(:info)
        LastGTFSValidation.store_last_gtfs_validation(~U[2025-11-10 14:45:54Z])

        {_result, log} =
          with_log(fn ->
            AlertValidationUpcomingWorker.perform(%Job{args: %{}})
          end)

        refute log =~ "New GTFS detected in dev. Updating stored time and validating alerts"
        assert LastGTFSValidation.get_most_recent_validation() == ~U[2025-11-10 14:45:54Z]
      end
    end
  end

  describe "last_updated_time_after_stored_time?/2" do
    test "stored time is nil" do
      result =
        AlertValidationUpcomingWorker.last_updated_time_after_stored_time?(
          DateTime.utc_now(),
          nil
        )

      assert result == true
    end

    test "incoming time is after stored time" do
      incoming_time = ~U[2025-11-10 14:45:54Z]
      stored_time = ~U[2025-11-01 14:45:54Z]

      result =
        AlertValidationUpcomingWorker.last_updated_time_after_stored_time?(
          incoming_time,
          stored_time
        )

      assert result == true
    end

    test "incoming time is before stored time" do
      incoming_time = ~U[2025-11-01 14:45:54Z]
      stored_time = ~U[2025-11-10 14:45:54Z]

      result =
        AlertValidationUpcomingWorker.last_updated_time_after_stored_time?(
          incoming_time,
          stored_time
        )

      assert result == false
    end
  end
end
