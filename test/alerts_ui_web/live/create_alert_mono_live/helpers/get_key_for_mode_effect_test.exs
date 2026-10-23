defmodule AlertsUIWeb.CreateAlertLive.Helpers.GetKeyForModeEffectTest do
  @moduledoc false
  use AlertsUIWeb.ConnCase
  import Mock
  alias AlertsUI.Configs.ModeEffect
  alias AlertsUIWeb.CreateAlertLive.Helpers.GetKeyForModeEffect

  @fake_mode_effect_table %{
    subway: %{
      "Single Tracking" => %{
        combination: :RDS,
        default_severity: 1,
        default_cause: "SINGLE_TRACKING",
        send_push_notification_on_edit: false
      }
    },
    commuter_rail: %{
      "Cancellation" => %{
        combination: :RDT,
        default_severity: 5,
        default_cause: nil,
        send_push_notification_on_edit: true
      },
      "Delay" => %{
        combination: :RDTS,
        default_severity: 3,
        default_cause: nil,
        send_push_notification_on_edit: true
      }
    },
    bus: %{
      "Multi-Route Detour" => %{
        combination: :SR,
        default_severity: 7,
        default_cause: nil,
        send_push_notification_on_edit: false
      }
    },
    ferry: %{
      "Cancellation" => %{
        combination: :RDT,
        default_severity: 5,
        default_cause: nil,
        send_push_notification_on_edit: false
      }
    },
    facility: %{
      "Elevator Closure" => %{
        combination: :ACCESS,
        default_severity: 3,
        default_cause: nil,
        send_push_notification_on_edit: false
      }
    },
    systemwide: %{
      "Delay" => %{
        combination: nil,
        default_severity: 5,
        default_cause: nil,
        send_push_notification_on_edit: false
      }
    }
  }
  describe "getting values from the mode effect table" do
    test "if effect name is nil" do
      assert GetKeyForModeEffect.get_value_of_key(:combination, "access", nil) == nil
    end

    test "if service type is nil and effect is systemwide, gets systemwide values" do
      assert GetKeyForModeEffect.get_value_of_key(:default_severity, nil, "Delay") == 5
    end

    test "if service type is nil and effect is a facility effect, gets facility values" do
      with_mock(ModeEffect,
        mode_effect: fn -> @fake_mode_effect_table end
      ) do
        assert GetKeyForModeEffect.get_value_of_key(:combination, nil, "Elevator Closure") ==
                 :ACCESS
      end
    end

    test "if key is string" do
      with_mock(ModeEffect,
        mode_effect: fn -> @fake_mode_effect_table end
      ) do
        assert GetKeyForModeEffect.get_value_of_key(:combination, "access", "Elevator Closure") ==
                 :ACCESS
      end
    end

    test "if given light rail route type, get subway values" do
      with_mock(ModeEffect,
        mode_effect: fn -> @fake_mode_effect_table end
      ) do
        assert GetKeyForModeEffect.get_value_of_key(:combination, 0, "Single Tracking") == :RDS
      end
    end

    test "if key is not found" do
      with_mock(ModeEffect,
        mode_effect: fn -> @fake_mode_effect_table end
      ) do
        assert GetKeyForModeEffect.get_value_of_key(:combination, :ferry, "Single Tracking") ==
                 nil
      end
    end

    test "if service type is not found" do
      with_mock(ModeEffect,
        mode_effect: fn -> @fake_mode_effect_table end
      ) do
        assert GetKeyForModeEffect.get_value_of_key(:combination, :bad_type, "Single Tracking") ==
                 nil
      end
    end
  end
end
