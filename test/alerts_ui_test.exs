defmodule AlertsUITest do
  @moduledoc false
  use AlertsUI.DataCase, async: true
  import Test.Support.Helpers

  describe "config/1" do
    test "retrieves the requested application configuration value" do
      reassign_env(:alerts_ui, :test_env_var, "MOCK VALUE")

      assert AlertsUI.config(:test_env_var) == "MOCK VALUE"
    end
  end
end
