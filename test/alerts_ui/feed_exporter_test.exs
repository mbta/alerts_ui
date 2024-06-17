defmodule AlertsUI.FeedExporterTest do
  use AlertsUI.DataCase, async: false
  use Oban.Testing, repo: AlertsUI.Repo
  import Test.Support.Helpers
  import ExUnit.CaptureLog
  alias AlertsUI.FeedExporter
  alias Oban.Job

  describe "perform" do
    test "runs successfully" do
      set_log_level(:info)

      {result, _log} =
        with_log(fn ->
          FeedExporter.perform(%Job{args: %{}})
        end)

      assert result == :ok
    end
  end
end
