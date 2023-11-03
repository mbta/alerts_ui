defmodule AlertsUi.FeedImporterExporterTest do
  @moduledoc false
  use AlertsUI.DataCase, async: true

  alias AlertsUi.FeedImporterExporter

  describe "perform" do
    test "runs successufully" do
      assert FeedImporterExporter.perform(%Oban.Job{args: %{}}) == :ok
    end
  end
end
