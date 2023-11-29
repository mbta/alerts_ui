defmodule AlertsUi.FeedImporterExporterTest do
  use AlertsUI.DataCase, async: true
  use Oban.Testing, repo: AlertsUI.Repo
  import AlertsUI.Support.Factory
  import Test.Support.Helpers
  import ExUnit.CaptureLog
  alias AlertsUi.FeedImporterExporter
  alias Oban.Job
  alias Req.Response

  describe "perform" do
    test "runs successfully" do
      set_log_level(:info)

      opts = [
        {:get_fn,
         fn _ ->
           body = %{
             "header" => %{
               "gtfs_realtime_version" => "2.0",
               "incrementality" => "FULL_DATASET",
               "timestamp" => 1_700_593_672
             },
             "entity" => []
           }

           Response.new(status: 200, body: body)
         end},
        {:write_fn, fn _, _ -> nil end}
      ]

      {result, _log} =
        with_log(fn ->
          FeedImporterExporter.perform(%Job{args: %{}}, opts)
        end)

      assert result == :ok
    end

    test "logs correctly if feeds match" do
      set_log_level(:info)
      insert(:alert)

      opts = [
        {:get_fn,
         fn _ ->
           body = %{
             "header" => %{
               "gtfs_realtime_version" => "2.0",
               "incrementality" => "FULL_DATASET",
               "timestamp" => 1_700_593_672
             },
             "entity" => [
               build(:alert_entity_data)
             ]
           }

           Response.new(status: 200, body: body)
         end},
        {:write_fn, fn _, _ -> nil end}
      ]

      insert(:alert, %{alert_id: "123456"})

      {_result, log} =
        with_log(fn ->
          FeedImporterExporter.perform(%Job{args: %{}}, opts)
        end)

      assert log =~ "Export ok!"
    end

    test "logs error if feed lengths don't match" do
      opts = [
        {:get_fn,
         fn _ ->
           body = %{
             "header" => %{
               "gtfs_realtime_version" => "2.0",
               "incrementality" => "FULL_DATASET",
               "timestamp" => 1_700_593_672
             },
             "entity" => [
               build(:alert_entity_data, %{alert_id: "654321"}),
               build(:alert_entity_data, %{alert_id: "123456"})
             ]
           }

           Response.new(status: 200, body: body)
         end},
        {:write_fn, fn _, _ -> nil end}
      ]

      insert(:alert, %{alert_id: "654321"})

      {_result, log} =
        with_log(fn ->
          FeedImporterExporter.perform(%Job{args: %{}}, opts)
        end)

      refute log =~ "Export ok!"
      assert log =~ "Export mismatch problem: alert_list_length_difference"
    end
  end
end
