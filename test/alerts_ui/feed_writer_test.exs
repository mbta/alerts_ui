defmodule AlertsUI.FeedWriterTest do
  use AlertsUI.DataCase, async: false

  alias AlertsUI.FeedWriter
  alias Oban.Job

  describe "perform" do
    test "runs successfully" do
      assert FeedWriter.perform(%Job{args: %{}}) == :ok
    end
  end
end
