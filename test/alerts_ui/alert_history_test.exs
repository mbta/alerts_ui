defmodule AlertsUIWeb.AlertHistoryTest do
  @moduledoc false
  use AlertsUIWeb.ConnCase
  import AlertsUI.Support.Factory

  alias AlertsUI.{AlertHistory, Alerts}

  describe "alert_history/1" do
    test "returns mapped alert versions" do
      user = build(:user)

      original_alert_map =
        build(
          :alert_map,
          %{
            alert_id: "123",
            header_text: "old header text",
            user: user
          }
        )

      new_params_one =
        build(:alert_map, %{
          alert_id: "123",
          header_text: "middle header text",
          user: user
        })

      new_params_two =
        build(:alert_map, %{
          alert_id: "123",
          header_text: "new header text",
          user: user
        })

      Alerts.create_or_update_alert(original_alert_map, user)

      Alerts.create_or_update_alert(new_params_one, user, Alerts.get_by_alert_id("123"))

      Alerts.create_or_update_alert(new_params_two, user, Alerts.get_by_alert_id("123"))

      [result_1, result_2, result_3] = AlertHistory.alert_history("123")

      assert %{
               alert_id: "123",
               version: 1
             } = result_1
    end
  end
end
