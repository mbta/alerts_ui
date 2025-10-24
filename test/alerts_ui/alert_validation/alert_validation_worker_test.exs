defmodule AlertsUI.AlertValidation.AlertValidationWorkerTest do
  use AlertsUI.DataCase, async: false

  alias AlertsUI.AlertValidation.AlertValidationWorker
  alias Oban.Job

  describe "perform" do
    test "runs successfully" do
      assert AlertValidationWorker.perform(%Job{args: %{}}) == :ok
    end
  end
end
