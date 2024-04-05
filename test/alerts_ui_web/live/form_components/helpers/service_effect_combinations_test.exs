defmodule AlertsUIWeb.FormComponents.Helpers.ServiceEffectCombinationsTest do
  @moduledoc false
  use AlertsUIWeb.ConnCase
  import AlertsUI.Support.Factory
  alias AlertsUIWeb.FormComponents.Helpers.ServiceEffectCombinations

  doctest AlertsUIWeb.FormComponents.Helpers.ServiceEffectCombinations

  describe "get_combination/1" do
    test "empty list" do
      assert ServiceEffectCombinations.get_combination([]) == nil
    end

    test "R" do
      informed_entity = [
        build(:informed_entity, %{route_id: "1", trip: nil}),
        build(:informed_entity, %{trip: nil}),
        build(:informed_entity, %{route_id: "3", trip: nil})
      ]

      result = ServiceEffectCombinations.get_combination(informed_entity)
      assert result == :R
    end

    test "SR" do
      informed_entity = [
        build(:informed_entity, %{route_id: "1", trip: nil}),
        build(:informed_entity, %{route_id: "2", stop_id: "a", trip: nil}),
        build(:informed_entity, %{route_id: "3", trip: nil})
      ]

      result = ServiceEffectCombinations.get_combination(informed_entity)
      assert result == :SR
    end

    test "RDS" do
      informed_entity = [
        build(:informed_entity, %{route_id: "1", direction_id: "0", trip: nil}),
        build(:informed_entity, %{route_id: "2", stop_id: "a", trip: nil}),
        build(:informed_entity, %{route_id: "3", direction_id: "1", trip: nil})
      ]

      result = ServiceEffectCombinations.get_combination(informed_entity)
      assert result == :RDS
    end

    test "RDT" do
      informed_entity = [
        build(:informed_entity, %{route_id: "1", direction_id: "0"}),
        build(:informed_entity, %{route_id: "2", trip: nil}),
        build(:informed_entity, %{route_id: "3", direction_id: "1", trip: nil})
      ]

      result = ServiceEffectCombinations.get_combination(informed_entity)
      assert result == :RDT
    end

    test "RDST" do
      informed_entity = [
        build(:informed_entity, %{route_id: "1", direction_id: "0"}),
        build(:informed_entity, %{route_id: "2", stop_id: "a", trip: nil}),
        build(:informed_entity, %{route_id: "3", direction_id: "1", trip: nil})
      ]

      result = ServiceEffectCombinations.get_combination(informed_entity)
      assert result == :RDTS
    end
  end
end
