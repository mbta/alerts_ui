defmodule AlertsUi.FeedImporterExporterTest do
  @moduledoc false
  use AlertsUI.DataCase, async: true
  import AlertsUI.Support.Factory
  alias AlertsUi.FeedImporterExporter
  alias Oban.Job
  alias Req.Response

  describe "perform" do
    test "runs successufully" do
      opts = [
        {:get_fn,
         fn _ ->
           body = %{"entity" => []}
           Response.new(status: 200, body: body)
         end}
      ]

      insert(:alert)

      assert FeedImporterExporter.perform(%Job{args: %{}}, opts) == :ok
    end
  end
end
