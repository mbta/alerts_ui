defmodule AlertsUI.AlertFromApiTest do
  use AlertsUI.DataCase, async: true
  alias AlertsUI.AlertFromApi

  describe "fill_in_alert/1" do
    test "fill in effect if only given detail" do
      incoming = %{
        header_text: "header",
        description_text: "description",
        effect_detail: "ACCESS_ISSUE",
        informed_entity: [
          %{route_id: "1"}
        ]
      }

      result = AlertFromApi.fill_in_alert(incoming)
      assert result.effect == :ACCESSIBILITY_ISSUE
    end

    test "does not replace effect if given" do
      incoming = %{
        header_text: "header",
        description_text: "description",
        effect: :OTHER_EFFECT,
        effect_detail: "ACCESS_ISSUE",
        informed_entity: [
          %{route_id: "1"}
        ]
      }

      result = AlertFromApi.fill_in_alert(incoming)
      assert result.effect == :OTHER_EFFECT
    end

    test "handles case if effect detail is not found" do
      incoming = %{
        header_text: "header",
        description_text: "description",
        effect: :OTHER_EFFECT,
        effect_detail: "ACCESSIBILITY_ISSUE",
        informed_entity: [
          %{route_id: "1"}
        ]
      }

      result = AlertFromApi.fill_in_alert(incoming)
      assert result.effect == :OTHER_EFFECT
    end

    test "adds activities to informed_entity if none given" do
      incoming = %{
        header_text: "header",
        description_text: "description",
        effect: "ACCESSIBILITY_ISSUE",
        effect_detail: "ACCESS_ISSUE",
        informed_entity: [
          %{route_id: "1"}
        ]
      }

      result = AlertFromApi.fill_in_alert(incoming)
      assert hd(result.informed_entity).activities == [:USING_WHEELCHAIR]
    end

    test "does not replace activities if provided" do
      incoming = %{
        header_text: "header",
        description_text: "description",
        effect: "DETOUR",
        effect_detail: "DETOUR",
        informed_entity: [
          %{route_id: "1", activities: ["BOARD", "RIDE"]}
        ]
      }

      result = AlertFromApi.fill_in_alert(incoming)
      assert hd(result.informed_entity).activities == [:BOARD, :RIDE]
    end

    test "fills in missing info in informed_entity from trip" do
      incoming = %{
        header_text: "header",
        description_text: "description",
        effect_detail: "DETOUR",
        informed_entity: [
          %{
            trip: %{
              route_id: "1",
              direction_id: "0"
            }
          }
        ]
      }

      result = AlertFromApi.fill_in_alert(incoming)

      assert result.informed_entity == [
               %{
                 route_id: "1",
                 direction_id: "0",
                 activities: [:BOARD, :EXIT],
                 trip: %{
                   route_id: "1",
                   direction_id: "0"
                 }
               }
             ]
    end

    test "does not overwrite informed_entity information" do
      incoming = %{
        header_text: "header",
        description_text: "description",
        effect_detail: "DETOUR",
        informed_entity: [
          %{
            route_id: "2",
            direction_id: "1",
            trip: %{
              route_id: "1",
              direction_id: "0"
            }
          }
        ]
      }

      result = AlertFromApi.fill_in_alert(incoming)

      assert result.informed_entity == [
               %{
                 route_id: "2",
                 direction_id: "1",
                 activities: [:BOARD, :EXIT],
                 trip: %{
                   route_id: "1",
                   direction_id: "0"
                 }
               }
             ]
    end

    test "does not change informed_entity if trip absent" do
      incoming = %{
        header_text: "header",
        description_text: "description",
        effect_detail: "DETOUR",
        informed_entity: [
          %{
            route_id: "2",
            direction_id: "1"
          }
        ]
      }

      result = AlertFromApi.fill_in_alert(incoming)

      assert result.informed_entity == [
               %{
                 route_id: "2",
                 direction_id: "1",
                 activities: [:BOARD, :EXIT]
               }
             ]
    end
  end
end
