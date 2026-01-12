defmodule AlertsUIWeb.FormComponents.Helpers.GetKeyForModeEffectTest do
  @moduledoc false
  use AlertsUIWeb.ConnCase
  import Mock
  alias AlertsUI.Configs.ModeEffect
  alias AlertsUIWeb.FormComponents.Helpers.GetKeyForModeEffect

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
    # TODO
    test "getting combinations" do
      with_mock(ModeEffect,
        mode_effect: fn -> @fake_mode_effect_table end
      ) do
        assert true
      end
    end
  end
end

er
