defmodule AlertsUIWeb.CreateAlertMonoLive.Helpers.ModeEffectChangeTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias AlertsUIWeb.CreateAlertMonoLive.Helpers.ModeEffectChange

  describe "changing paradigms" do
    test "RDS to SR" do
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
               trip_ids: []
             }

      assert replaced_values == %{route_ids: ["1", "2", "3"]}
    end

    test "SR to anything" do
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
  end
end
