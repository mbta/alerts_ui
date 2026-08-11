defmodule AlertsUI.Jobs.DelayedJobTest do
  use AlertsUI.DataCase, async: false

  defmodule Dummy do
    def perform(%{args: args}, _opts \\ []), do: {:ok, Map.get(args, "value")}
  end

  defmodule DummyWithError do
    def perform(_args, _opts \\ []), do: raise("Error")
  end

  alias AlertsUI.Jobs.DelayedJob
  alias Oban.Job
  import Mock
  import ExUnit.CaptureLog

  describe "perform" do
    test "runs successfully" do
      with_mock(Process, sleep: fn ms -> ms end) do
        result =
          DelayedJob.perform(%Job{
            args: %{"delay" => 5000, "module" => Dummy, "args" => %{"value" => "correct"}}
          })

        assert result == {:ok, "correct"}
        assert_called(Process.sleep(5000))
      end
    end

    test "logs errors" do
      with_mock(Process, [:passthrough], sleep: fn ms -> ms end) do
        {_, log} =
          with_log(fn ->
            DelayedJob.perform(%Job{args: %{"delay" => 1, "module" => DummyWithError}})
          end)

        assert_called(Process.sleep(1))
        assert log =~ ~r/\[error\] Error delaying job\. .*RuntimeError.*/
      end
    end
  end
end
