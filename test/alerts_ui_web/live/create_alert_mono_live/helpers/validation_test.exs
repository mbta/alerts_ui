defmodule AlertsUIWeb.CreateAlertLive.Helpers.ValidationTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias AlertsUIWeb.CreateAlertLive.Helpers.Validation

  defp changeset_with(value) do
    Ecto.Changeset.cast({%{f: value}, %{f: :string}}, %{}, [:f])
  end

  defp list_changeset_with(value) do
    Ecto.Changeset.cast({%{f: value}, %{f: {:array, :string}}}, %{}, [:f])
  end

  describe "always_validate_required/3" do
    test "adds an error when the field is nil" do
      changeset = Validation.always_validate_required(changeset_with(nil), :f, "is required")

      assert changeset.errors[:f] == {"is required", []}
    end

    test "adds an error when the field is an empty string" do
      changeset = Validation.always_validate_required(changeset_with(""), :f, "is required")

      assert changeset.errors[:f] == {"is required", []}
    end

    test "adds an error when the field is an empty list" do
      changeset =
        Validation.always_validate_required(list_changeset_with([]), :f, "is required")

      assert changeset.errors[:f] == {"is required", []}
    end

    test "leaves the changeset unchanged when the field is populated" do
      changeset = Validation.always_validate_required(changeset_with("hi"), :f, "is required")

      assert changeset.errors == []
    end

    test "leaves the changeset unchanged when a list field has elements" do
      changeset =
        Validation.always_validate_required(list_changeset_with(["a"]), :f, "is required")

      assert changeset.errors == []
    end
  end
end
