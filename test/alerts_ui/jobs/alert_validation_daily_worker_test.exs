defmodule AlertsUI.Jobs.AlertValidationDailyWorkerTest do
  use AlertsUI.DataCase, async: false

  alias AlertsUI.Jobs.AlertValidationDailyWorker
  alias Oban.Job

  describe "perform" do
    test "runs successfully" do
      assert AlertValidationDailyWorker.perform(%Job{args: %{}}) == :ok
    end
  end
end
