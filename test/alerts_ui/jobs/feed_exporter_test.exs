defmodule AlertsUI.Jobs.FeedExporterTest do
  use AlertsUI.DataCase, async: false
  use Oban.Testing, repo: AlertsUI.Repo
  import Test.Support.Helpers
  import ExUnit.CaptureLog
  alias AlertsUI.Jobs.FeedExporter
  alias Oban.Job

  describe "perform" do
    setup do
      reassign_env(:alerts_ui, :get_http_fn, fn _ ->
        %{status: 200, body: Jason.encode!(%{"entity" => []})}
      end)

      reassign_env(:alerts_ui, :get_obj_fn, fn _, _ ->
        %{status_code: 200, body: Jason.encode!(%{"entity" => []})}
      end)

      reassign_env(:alerts_ui, :make_request_fn, fn _ ->
        %{status_code: 200, body: Jason.encode!(%{"entity" => []})}
      end)
    end

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
