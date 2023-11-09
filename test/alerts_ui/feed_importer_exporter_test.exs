defmodule AlertsUi.FeedImporterExporterTest do
  @moduledoc false
  use AlertsUI.DataCase, async: true
  import AlertsUI.Support.Factory
  alias AlertsUi.FeedImporterExporter

  describe "perform" do
    test "runs successufully" do
      insert(:alert)
      assert FeedImporterExporter.perform(%Oban.Job{args: %{}}) == :ok
    end
  end
end
