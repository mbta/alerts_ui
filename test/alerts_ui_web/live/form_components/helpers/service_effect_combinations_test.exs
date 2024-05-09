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

    test "RDST with direction in trip" do
      informed_entity = %AlertsUI.Models.InformedEntity{
        agency_id: "1",
        route_id: "CR-Fitchburg",
        facility_id: nil,
        route_type: 2,
        direction_id: nil,
        stop_id: "FR-0451-02",
        activities: [:BOARD, :EXIT, :RIDE],
        trip: %AlertsUI.Models.TripDescriptor{
          trip_id: "CR-627728-402",
          route_id: "CR-Fitchburg",
          direction_id: 1,
          created_at: ~U[2024-05-07 19:13:24Z],
          updated_at: ~U[2024-05-07 19:13:24Z]
        }
      }

      result = ServiceEffectCombinations.get_combination([informed_entity])
      assert result == :RDTS
    end

    test "systemwide" do
      informed_entity = [
        build(:informed_entity, %{route_id: nil, trip: nil})
      ]

      result = ServiceEffectCombinations.get_combination(informed_entity)

      assert result == nil
    end
  end
end
