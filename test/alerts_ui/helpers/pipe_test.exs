defmodule AlertsUI.Helpers.PipeTest do
  @moduledoc false
  use ExUnit.Case, asyne: false

  alias AlertsUI.Helpers.Pipe

  describe "default_to/2" do
    test "uses default value when nil" do
      assert nil |> Pipe.default_to(:default) == :default
    end

    test "uses pipe value when not nil" do
      assert :value |> Pipe.default_to(:default) == :value
    end
  end
end
