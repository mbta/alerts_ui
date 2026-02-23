defmodule AlertsUI.Jobs.FeedCheckerTest do
  use AlertsUI.DataCase, async: false
  use Oban.Testing, repo: AlertsUI.Repo
  import Test.Support.Helpers
  import ExUnit.CaptureLog
  alias AlertsUI.Jobs.FeedChecker
  alias Oban.Job

  describe "perform" do
    setup do
      :combined_enhanced_json_output_filename
      :combined_enhanced_sita_json_output_filename
      :combined_standard_json_output_filename
      :combined_protobuf_output_filename

      reassign_env(:alerts_ui, :get_http_fn, fn _ ->
        %{status: 200, body: Jason.encode!(%{"entity" => []})}
      end)
    end

    test "runs successfully" do
      set_log_level(:info)

      {result, _log} =
        with_log(fn ->
          FeedChecker.perform(%Job{args: %{}})
        end)

      assert result == :ok
    end
  end
end
