defmodule AlertsUIWeb.FormComponents.Helpers.CombinationFromInformedEntityTest do
  @moduledoc false
  use AlertsUIWeb.ConnCase
  import AlertsUI.Support.Factory
  alias AlertsUIWeb.FormComponents.Helpers.CombinationFromInformedEntity

  describe "get_combination/1" do
    test "R" do
      informed_entity = [
        build(:informed_entity, %{route_id: "1"}) |> Map.drop([:trip]),
        build(:informed_entity, %{trip: nil}) |> Map.drop([:trip]),
        build(:informed_entity, %{route_id: "3"}) |> Map.drop([:trip])
      ]

      result = CombinationFromInformedEntity.get_combination(informed_entity)
      assert result == :R
    end

    test "SR" do
      informed_entity = [
        build(:informed_entity, %{route_id: "1"}) |> Map.drop([:trip]),
        build(:informed_entity, %{route_id: "2", stop_id: "a"}) |> Map.drop([:trip]),
        build(:informed_entity, %{route_id: "3"}) |> Map.drop([:trip])
      ]

      result = CombinationFromInformedEntity.get_combination(informed_entity)
      assert result == :SR
    end

    test "RDS" do
      informed_entity = [
        build(:informed_entity, %{route_id: "1", direction_id: "0"}) |> Map.drop([:trip]),
        build(:informed_entity, %{route_id: "2", stop_id: "a"}) |> Map.drop([:trip]),
        build(:informed_entity, %{route_id: "3", direction_id: "1"}) |> Map.drop([:trip])
      ]

      result = CombinationFromInformedEntity.get_combination(informed_entity)
      assert result == :RDS
    end

    test "RDT" do
      informed_entity = [
        build(:informed_entity, %{route_id: "1", direction_id: "0"}),
        build(:informed_entity, %{route_id: "2"}),
        build(:informed_entity, %{route_id: "3", direction_id: "1"})
      ]

      result = CombinationFromInformedEntity.get_combination(informed_entity)
      assert result == :RDT
    end

    test "RDST" do
      informed_entity = [
        build(:informed_entity, %{route_id: "1", direction_id: "0"}),
        build(:informed_entity, %{route_id: "2", stop_id: "a"}),
        build(:informed_entity, %{route_id: "3", direction_id: "1"})
      ]

      result = CombinationFromInformedEntity.get_combination(informed_entity)
      assert result == :RDTS
    end
  end
end
