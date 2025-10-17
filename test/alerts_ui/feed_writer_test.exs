defmodule AlertsUI.FeedWriterTest do
  use AlertsUI.DataCase, async: false

  alias AlertsUI.FeedWriter
  alias Oban.Job
  import Test.Support.Helpers

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
      assert FeedWriter.perform(%Job{args: %{}}) == :ok
    end
  end
end
