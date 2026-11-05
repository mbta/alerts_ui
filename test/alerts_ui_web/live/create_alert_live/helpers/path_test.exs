defmodule AlertsUIWeb.CreateAlertLive.Helpers.PathTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias AlertsUIWeb.CreateAlertLive.Helpers.Path, as: PathHelper
  alias Phoenix.LiveView.Socket

  defp map_form(params), do: Phoenix.Component.to_form(params, as: :alert_data)

  describe "path/1" do
    test "returns the new path for :new" do
      assert PathHelper.path(%{live_action: :new, alert_id: nil}) == "/alerts/new/"
    end

    test "returns the edit path for :edit" do
      assert PathHelper.path(%{live_action: :edit, alert_id: "abc"}) == "/alerts/edit/abc"
    end

    test "returns the duplicate path for :duplicate" do
      assert PathHelper.path(%{live_action: :duplicate, alert_id: "abc"}) ==
               "/alerts/duplicate/abc"
    end
  end

  describe "path_with_route_type/2" do
    test ":new builds /alerts/new/<route_type>" do
      assigns = %{live_action: :new, alert_id: nil}

      assert PathHelper.path_with_route_type(assigns, "bus") == "/alerts/new/bus"
    end

    test ":edit builds /alerts/edit/<alert_id>/<route_type>" do
      assigns = %{live_action: :edit, alert_id: "abc"}

      assert PathHelper.path_with_route_type(assigns, "bus") == "/alerts/edit/abc/bus"
    end

    test ":duplicate builds /alerts/duplicate/<alert_id>/<route_type>" do
      assigns = %{live_action: :duplicate, alert_id: "abc"}

      assert PathHelper.path_with_route_type(assigns, "bus") == "/alerts/duplicate/abc/bus"
    end
  end

  describe "path_with_route_type_and_effect_name/2" do
    test ":new builds /alerts/new/<route_type>/<effect_name>" do
      assigns = %{live_action: :new, alert_id: nil, path_route_type: "bus"}

      assert PathHelper.path_with_route_type_and_effect_name(assigns, "detour") ==
               "/alerts/new/bus/detour"
    end

    test ":edit builds /alerts/edit/<alert_id>/<route_type>/<effect_name>" do
      assigns = %{live_action: :edit, alert_id: "abc", path_route_type: "bus"}

      assert PathHelper.path_with_route_type_and_effect_name(assigns, "detour") ==
               "/alerts/edit/abc/bus/detour"
    end

    test ":duplicate builds /alerts/duplicate/<alert_id>/<route_type>/<effect_name>" do
      assigns = %{live_action: :duplicate, alert_id: "abc", path_route_type: "bus"}

      assert PathHelper.path_with_route_type_and_effect_name(assigns, "detour") ==
               "/alerts/duplicate/abc/bus/detour"
    end
  end

  describe "path_route_type/2" do
    test "maps a known integer route_type to its symbolic name" do
      assert PathHelper.path_route_type(0, "delay") == :light_rail
      assert PathHelper.path_route_type(1, "delay") == :subway
      assert PathHelper.path_route_type(2, "delay") == :commuter_rail
      assert PathHelper.path_route_type(3, "delay") == :bus
      assert PathHelper.path_route_type(4, "delay") == :ferry
    end

    test "returns :facility when route_type is nil and effect is a facility path name" do
      assert PathHelper.path_route_type(nil, "elevator_closure") == :facility
    end

    test "returns :systemwide when route_type is nil and effect is not a facility path name" do
      assert PathHelper.path_route_type(nil, "delay") == :systemwide
    end

    test "returns :systemwide when route_type and effect are both nil" do
      assert PathHelper.path_route_type(nil, nil) == :systemwide
    end
  end

  describe "path_route_type_from_form/1" do
    test "resolves the route_type via the form's route_type value" do
      f = map_form(%{"route_type" => 3, "effect_name" => "delay"})

      assert PathHelper.path_route_type_from_form(f) == :bus
    end

    test "falls back to :facility when route_type is nil and effect is facility-typed" do
      f = map_form(%{"route_type" => nil, "effect_name" => "elevator_closure"})

      assert PathHelper.path_route_type_from_form(f) == :facility
    end

    test "falls back to :systemwide when route_type and effect are both empty" do
      f = map_form(%{"route_type" => nil, "effect_name" => nil})

      assert PathHelper.path_route_type_from_form(f) == :systemwide
    end
  end

  describe "path_route_type_from_socket/1" do
    test "pulls the form out of the socket's assigns" do
      f = map_form(%{"route_type" => 3, "effect_name" => "delay"})
      socket = %Socket{assigns: %{form: f, __changed__: nil}}

      assert PathHelper.path_route_type_from_socket(socket) == :bus
    end
  end

  describe "path_effect_name_from_socket/1" do
    test "returns the effect_name value from the socket's form" do
      f = map_form(%{"effect_name" => "detour"})
      socket = %Socket{assigns: %{form: f, __changed__: nil}}

      assert PathHelper.path_effect_name_from_socket(socket) == "detour"
    end
  end
end
