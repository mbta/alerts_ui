defmodule AlertsUI.Models.ReminderTimeTest do
  @moduledoc false
  use AlertsUI.DataCase, async: true
  alias AlertsUI.Models.ReminderTime

  describe "changeset/2" do
    test "create with reminder time is valid" do
      params = %{reminder_time: ~U[2024-09-25 00:01:00Z]}
      changeset = ReminderTime.changeset(%ReminderTime{}, params)
      assert changeset.valid?
    end
  end
end
