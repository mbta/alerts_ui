defmodule AlertsUI.Jobs.AlertAssociationDailyWorkerTest do
  use AlertsUI.DataCase, async: false

  alias AlertsUI.Jobs.AlertAssociationDailyWorker
  alias Oban.Job

  describe "perform" do
    test "runs successfully" do
      assert AlertAssociationDailyWorker.perform(%Job{args: %{}}) == :ok
    end
  end
end
