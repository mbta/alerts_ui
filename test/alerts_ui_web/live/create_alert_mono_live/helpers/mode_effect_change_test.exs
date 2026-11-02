defmodule AlertsUIWeb.CreateAlertLive.Helpers.ModeEffectChangeTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias AlertsUIWeb.CreateAlertLive.Helpers.ModeEffectChange

  describe "changing paradigms" do
    test "RDS to SR retains stops" do
      form = %{
        combination: :RDS,
        route_type: 3,
        route_ids: ["1", "2", "3"],
        stop_ids: ["place-sstat"],
        stop_names_and_ids: ["South Station|place-sstat"]
      }

      %{new: new_values, replaced: replaced_values} =
        ModeEffectChange.new_form_values(form, 3, "stop_closure")

      assert new_values === %{
               facility_ids: [],
               route_ids: [],
               trip_ids: [],
               direction: nil,
               service_types: []
             }

      assert replaced_values == %{route_ids: ["1", "2", "3"]}
    end

    test "RDTS to SR retains stops" do
      form = %{
        combination: :RDTS,
        route_type: 4,
        route_ids: ["boat-1", "boat-2", "boat-3"],
        trip_ids: ["trip-id"],
        stop_ids: ["boat-rowes"],
        stop_names_and_ids: ["Rowes|boat-rowes"]
      }

      %{new: new_values, replaced: replaced_values} =
        ModeEffectChange.new_form_values(form, 4, "dock_issue")

      assert new_values === %{
               facility_ids: [],
               route_ids: [],
               trip_ids: [],
               direction: nil,
               service_types: []
             }

      assert replaced_values == %{
               route_ids: ["boat-1", "boat-2", "boat-3"],
               trip_ids: ["trip-id"]
             }
    end

    test "SR to anything wipes everything" do
      form = %{
        combination: :SR,
        route_type: 3,
        route_ids: ["1", "2", "3"],
        stop_ids: ["place-sstat"],
        stop_names_and_ids: ["South Station|place-sstat"]
      }

      for {route_type, effect_name} <- [
            {3, "delay"},
            {3, "detour"},
            {2, "delay"},
            {4, "notice"},
            {nil, "amber_alert"}
          ] do
        %{new: new_values, replaced: replaced_values} =
          ModeEffectChange.new_form_values(form, route_type, effect_name)

        assert new_values === ModeEffectChange.full_reset()

        assert replaced_values == %{
                 route_ids: ["1", "2", "3"],
                 stop_ids: ["place-sstat"],
                 stop_names_and_ids: ["South Station|place-sstat"]
               }
      end
    end

    test "RDT to RDTS retains everything" do
      form = %{
        combination: :RDT,
        route_type: 4,
        route_ids: ["boat-1", "boat-2", "boat-3"],
        trip_ids: ["trip-1"]
      }

      %{new: new_values, replaced: replaced_values} =
        ModeEffectChange.new_form_values(form, 4, "delay")

      assert new_values === %{}

      assert replaced_values == %{}
    end

    test "RDTS to RDT retains everything but stops" do
      form = %{
        combination: :RDTS,
        route_type: 4,
        route_ids: ["boat-1", "boat-2", "boat-3"],
        stop_ids: ["boat-rowes"],
        stop_names_and_ids: ["Rowes|boat-rowes"]
      }

      %{new: new_values, replaced: replaced_values} =
        ModeEffectChange.new_form_values(form, 4, "cancellation")

      assert new_values === %{
               stop_ids: [],
               stop_names_and_ids: [],
               facility_ids: [],
               service_types: []
             }

      assert replaced_values == %{
               stop_ids: ["boat-rowes"],
               stop_names_and_ids: ["Rowes|boat-rowes"]
             }
    end

    test "R to anything else (except SR) retains routes" do
      form = %{
        combination: :R,
        route_type: 4,
        route_ids: ["boat-1", "boat-2", "boat-3"]
      }

      for {route_type, effect_name} <- [
            # RDTS
            {4, "delay"},
            # R
            {4, "extra_service"},
            # RDT
            {4, "cancellation"}
          ] do
        %{new: new_values, replaced: replaced_values} =
          ModeEffectChange.new_form_values(form, route_type, effect_name)

        assert new_values === %{}

        assert replaced_values == %{}
      end
    end

    test "anything (except SR) to R retains routes" do
      for {combination, data} <- [
            {:RDTS,
             %{
               direction: "0",
               trip_ids: ["boat-trip"],
               stop_ids: ["boat-rowes"],
               stop_names_and_ids: ["Rowes|boat-rowes"]
             }},
            {:RDT, %{direction: "0", trip_ids: ["boat-trip"]}}
          ] do
        form =
          Map.merge(
            %{
              combination: combination,
              route_type: 4,
              route_ids: ["boat-1", "boat-2", "boat-3"]
            },
            data
          )

        %{new: new_values, replaced: replaced_values} =
          ModeEffectChange.new_form_values(form, 4, "extra_service")

        assert new_values === %{
                 facility_ids: [],
                 trip_ids: [],
                 direction: nil,
                 stop_ids: [],
                 stop_names_and_ids: [],
                 service_types: []
               }

        assert replaced_values == data
      end
    end

    test "R to SR retains nothing" do
      form = %{
        combination: :R,
        route_type: 3,
        route_ids: ["1", "2", "3"]
      }

      %{new: new_values, replaced: replaced_values} =
        ModeEffectChange.new_form_values(form, 3, "stop_closure")

      assert new_values === ModeEffectChange.full_reset()

      assert replaced_values == %{route_ids: ["1", "2", "3"]}
    end
  end
end
