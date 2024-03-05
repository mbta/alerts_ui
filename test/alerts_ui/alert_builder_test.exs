defmodule AlertsUI.AlertBuilderTest do
  @moduledoc false
  use AlertsUI.DataCase, async: true
  import AlertsUI.Support.Factory
  alias AlertsUI.AlertBuilder
  alias AlertsUI.Alerts

  describe "build_alert/1" do
    test "builds alert from map" do
      existing_alert = insert(:alert, alert_id: "0")

      alert_data = %{
        route_type: 1,
        description_text: "ok",
        header_text: "hello",
        effect_name: "Delay",
        route_ids: ["57"],
        direction: "default"
      }

      result = AlertBuilder.build_alert(alert_data, :R)

      assert result == %{
               effect: :SIGNIFICANT_DELAYS,
               description_text: "ok",
               header_text: "hello",
               informed_entity: [
                 %{route_type: 1, activities: ["BOARD", "EXIT", "RIDE"], route_id: "57"}
               ],
               effect_detail: "DELAY",
               draft: false
             }

      result |> Alerts.create_alert()
      [alert_1, alert_2] = Alerts.list_all()
      assert alert_1.alert_id == existing_alert.alert_id
      assert alert_2.alert_id |> String.to_integer() > alert_1.alert_id |> String.to_integer()
    end

    test "it correctly adds combo ids" do
      existing_alert = insert(:alert, alert_id: "0")

      alert_data = %{
        route_type: 1,
        description_text: "ok",
        header_text: "hello",
        effect_name: "Delay",
        route_ids: ["24", "27", "57"],
        direction: "default"
      }

      result = AlertBuilder.build_alert(alert_data, :R)

      assert result == %{
               effect: :SIGNIFICANT_DELAYS,
               description_text: "ok",
               header_text: "hello",
               informed_entity: [
                 %{activities: ["BOARD", "EXIT", "RIDE"], route_id: "2427", route_type: 1},
                 %{activities: ["BOARD", "EXIT", "RIDE"], route_id: "24", route_type: 1},
                 %{activities: ["BOARD", "EXIT", "RIDE"], route_id: "27", route_type: 1},
                 %{activities: ["BOARD", "EXIT", "RIDE"], route_id: "57", route_type: 1}
               ],
               effect_detail: "DELAY",
               draft: false
             }

      result |> Alerts.create_alert()
      [alert_1, alert_2] = Alerts.list_all()
      assert alert_1.alert_id == existing_alert.alert_id
      assert alert_2.alert_id |> String.to_integer() > alert_1.alert_id |> String.to_integer()
    end

    test "properly builds RDS all-stops informed entity with 1 route" do
      alert_data = %{
        route_type: 3,
        description_text: "ok",
        header_text: "hello",
        effect_name: "Delay",
        stop_ids: [],
        route_ids: ["57"],
        trip_ids: nil,
        direction: "default"
      }

      result = AlertBuilder.build_alert(alert_data, :RDS)

      assert result.informed_entity == [
               %{
                 activities: ["BOARD", "EXIT", "RIDE"],
                 route_id: "57",
                 route_type: 3
               }
             ]
    end

    test "properly builds RDS all-stops informed entity with multiple routes" do
      alert_data = %{
        route_type: 3,
        description_text: "ok",
        header_text: "hello",
        effect_name: "Delay",
        stop_ids: [],
        route_ids: ["57", "58"],
        trip_ids: nil,
        direction: "default"
      }

      result = AlertBuilder.build_alert(alert_data, :RDS)

      assert result.informed_entity == [
               %{
                 activities: ["BOARD", "EXIT", "RIDE"],
                 route_id: "57",
                 route_type: 3
               },
               %{
                 activities: ["BOARD", "EXIT", "RIDE"],
                 route_id: "58",
                 route_type: 3
               }
             ]
    end

    test "properly builds RDS all-stops informed entity with one route and direction" do
      alert_data = %{
        route_type: 3,
        description_text: "ok",
        header_text: "hello",
        effect_name: "Delay",
        stop_ids: [],
        route_ids: ["57"],
        trip_ids: nil,
        direction: "1"
      }

      result = AlertBuilder.build_alert(alert_data, :RDS)

      assert result.informed_entity == [
               %{
                 activities: ["BOARD", "EXIT", "RIDE"],
                 route_id: "57",
                 route_type: 3,
                 direction_id: 1
               }
             ]
    end

    test "properly builds RDS informed entity with one route, multiple stops and direction" do
      alert_data = %{
        route_type: 3,
        description_text: "ok",
        header_text: "hello",
        effect_name: "Delay",
        stop_ids: ["a", "b", "c"],
        route_ids: ["57"],
        trip_ids: nil,
        direction: "1"
      }

      result = AlertBuilder.build_alert(alert_data, :RDS)

      assert result.informed_entity == [
               %{
                 activities: ["BOARD", "EXIT", "RIDE"],
                 route_id: "57",
                 route_type: 3,
                 direction_id: 1,
                 stop_id: "a"
               },
               %{
                 activities: ["BOARD", "EXIT", "RIDE"],
                 route_id: "57",
                 route_type: 3,
                 direction_id: 1,
                 stop_id: "b"
               },
               %{
                 activities: ["BOARD", "EXIT", "RIDE"],
                 route_id: "57",
                 route_type: 3,
                 direction_id: 1,
                 stop_id: "c"
               }
             ]
    end

    test "properly builds RDS informed entity with multiple routes, multiple stops and direction" do
      alert_data = %{
        route_type: 3,
        description_text: "ok",
        header_text: "hello",
        effect_name: "Delay",
        stop_ids: ["a", "b"],
        route_ids: ["57", "58"],
        trip_ids: nil,
        direction: "1"
      }

      result = AlertBuilder.build_alert(alert_data, :RDS)

      assert result.informed_entity == [
               %{
                 activities: ["BOARD", "EXIT", "RIDE"],
                 route_id: "57",
                 route_type: 3,
                 direction_id: 1,
                 stop_id: "a"
               },
               %{
                 activities: ["BOARD", "EXIT", "RIDE"],
                 route_id: "58",
                 route_type: 3,
                 direction_id: 1,
                 stop_id: "a"
               },
               %{
                 activities: ["BOARD", "EXIT", "RIDE"],
                 route_id: "57",
                 route_type: 3,
                 direction_id: 1,
                 stop_id: "b"
               },
               %{
                 activities: ["BOARD", "EXIT", "RIDE"],
                 route_id: "58",
                 route_type: 3,
                 direction_id: 1,
                 stop_id: "b"
               }
             ]
    end

    test "properly builds R informed entity" do
      alert_data = %{
        route_type: 3,
        description_text: "ok",
        header_text: "hello",
        effect_name: "Delay",
        route_ids: ["57", "58"],
        direction: "default"
      }

      result = AlertBuilder.build_alert(alert_data, :R)

      assert result.informed_entity == [
               %{
                 activities: ["BOARD", "EXIT", "RIDE"],
                 route_id: "57",
                 route_type: 3
               },
               %{
                 activities: ["BOARD", "EXIT", "RIDE"],
                 route_id: "58",
                 route_type: 3
               }
             ]
    end

    test "properly builds R informed entity with direction" do
      alert_data = %{
        route_type: 3,
        description_text: "ok",
        header_text: "hello",
        effect_name: "Delay",
        route_ids: ["57", "58"],
        direction: "1"
      }

      result = AlertBuilder.build_alert(alert_data, :R)

      assert result.informed_entity == [
               %{
                 activities: ["BOARD", "EXIT", "RIDE"],
                 route_id: "57",
                 route_type: 3,
                 direction_id: 1
               },
               %{
                 activities: ["BOARD", "EXIT", "RIDE"],
                 route_id: "58",
                 route_type: 3,
                 direction_id: 1
               }
             ]
    end

    test "properly builds RDT informed entity" do
      alert_data = %{
        route_type: 3,
        description_text: "ok",
        header_text: "hello",
        effect_name: "Delay",
        route_ids: ["57"],
        trip_ids: ["123", "345", "456"],
        trip_information_by_id: %{
          "123" => %{direction_id: 0, route_id: "57"},
          "345" => %{direction_id: 0, route_id: "57"},
          "456" => %{direction_id: 0, route_id: "57"}
        }
      }

      result = AlertBuilder.build_alert(alert_data, :RDT)

      assert result.informed_entity == [
               %{
                 activities: ["BOARD", "EXIT", "RIDE"],
                 route_id: "57",
                 route_type: 3,
                 direction_id: 0,
                 trip: %{
                   trip_id: "123",
                   route_id: "57",
                   direction_id: 0
                 }
               },
               %{
                 activities: ["BOARD", "EXIT", "RIDE"],
                 route_id: "57",
                 route_type: 3,
                 direction_id: 0,
                 trip: %{
                   trip_id: "345",
                   route_id: "57",
                   direction_id: 0
                 }
               },
               %{
                 activities: ["BOARD", "EXIT", "RIDE"],
                 route_id: "57",
                 route_type: 3,
                 direction_id: 0,
                 trip: %{
                   trip_id: "456",
                   route_id: "57",
                   direction_id: 0
                 }
               }
             ]
    end

    test "properly builds RDT informed entity with multiple routes, multiple trips" do
      alert_data = %{
        route_type: 3,
        description_text: "ok",
        header_text: "hello",
        effect_name: "Delay",
        route_ids: ["57", "58"],
        trip_ids: ["123", "345", "456"],
        trip_information_by_id: %{
          "123" => %{direction_id: 0, route_id: "57"},
          "345" => %{direction_id: 0, route_id: "57"},
          "456" => %{direction_id: 0, route_id: "58"}
        }
      }

      result = AlertBuilder.build_alert(alert_data, :RDT)

      assert result.informed_entity == [
               %{
                 activities: ["BOARD", "EXIT", "RIDE"],
                 route_id: "57",
                 route_type: 3,
                 direction_id: 0,
                 trip: %{
                   trip_id: "123",
                   route_id: "57",
                   direction_id: 0
                 }
               },
               %{
                 activities: ["BOARD", "EXIT", "RIDE"],
                 route_id: "57",
                 route_type: 3,
                 direction_id: 0,
                 trip: %{
                   trip_id: "345",
                   route_id: "57",
                   direction_id: 0
                 }
               },
               %{
                 activities: ["BOARD", "EXIT", "RIDE"],
                 route_id: "58",
                 route_type: 3,
                 direction_id: 0,
                 trip: %{
                   trip_id: "456",
                   route_id: "58",
                   direction_id: 0
                 }
               }
             ]
    end

    test "properly builds RDT informed entity with 1 route, all trips" do
      alert_data = %{
        route_type: 3,
        description_text: "ok",
        header_text: "hello",
        effect_name: "Delay",
        route_ids: ["57"],
        trip_ids: [],
        direction: "default"
      }

      result = AlertBuilder.build_alert(alert_data, :RDT)

      assert result.informed_entity == [
               %{
                 activities: ["BOARD", "EXIT", "RIDE"],
                 route_id: "57",
                 route_type: 3
               }
             ]
    end

    test "RDTS informed entity with trips and no stops selected treated as RDT" do
      alert_data = %{
        route_type: 3,
        description_text: "ok",
        header_text: "hello",
        effect_name: "Delay",
        route_ids: ["57"],
        trip_ids: ["123", "345", "456"],
        trip_information_by_id: %{
          "123" => %{direction_id: 0, route_id: "57"},
          "345" => %{direction_id: 0, route_id: "57"},
          "456" => %{direction_id: 0, route_id: "57"}
        },
        stop_ids: [],
        direction: "default"
      }

      result = AlertBuilder.build_alert(alert_data, :RDTS)

      assert result.informed_entity == [
               %{
                 activities: ["BOARD", "EXIT", "RIDE"],
                 route_id: "57",
                 route_type: 3,
                 direction_id: 0,
                 trip: %{
                   trip_id: "123",
                   route_id: "57",
                   direction_id: 0
                 }
               },
               %{
                 activities: ["BOARD", "EXIT", "RIDE"],
                 route_id: "57",
                 route_type: 3,
                 direction_id: 0,
                 trip: %{
                   trip_id: "345",
                   route_id: "57",
                   direction_id: 0
                 }
               },
               %{
                 activities: ["BOARD", "EXIT", "RIDE"],
                 route_id: "57",
                 route_type: 3,
                 direction_id: 0,
                 trip: %{
                   trip_id: "456",
                   route_id: "57",
                   direction_id: 0
                 }
               }
             ]
    end

    test "RDTS informed entity with stops and no trips selected treated as RDS" do
      alert_data = %{
        route_type: 3,
        description_text: "ok",
        header_text: "hello",
        effect_name: "Delay",
        route_ids: ["57"],
        trip_ids: [],
        stop_ids: ["a", "b", "c"],
        direction: "0"
      }

      result = AlertBuilder.build_alert(alert_data, :RDTS)

      assert result.informed_entity == [
               %{
                 activities: ["BOARD", "EXIT", "RIDE"],
                 route_id: "57",
                 route_type: 3,
                 direction_id: 0,
                 stop_id: "a"
               },
               %{
                 activities: ["BOARD", "EXIT", "RIDE"],
                 route_id: "57",
                 route_type: 3,
                 direction_id: 0,
                 stop_id: "b"
               },
               %{
                 activities: ["BOARD", "EXIT", "RIDE"],
                 route_id: "57",
                 route_type: 3,
                 direction_id: 0,
                 stop_id: "c"
               }
             ]
    end

    test "RDTS informed entity with no stops and no trips selected treated as R" do
      alert_data = %{
        route_type: 3,
        description_text: "ok",
        header_text: "hello",
        effect_name: "Delay",
        route_ids: ["57", "58"],
        trip_ids: [],
        stop_ids: [],
        direction: "default"
      }

      result = AlertBuilder.build_alert(alert_data, :RDTS)

      assert result.informed_entity == [
               %{
                 activities: ["BOARD", "EXIT", "RIDE"],
                 route_id: "57",
                 route_type: 3
               },
               %{
                 activities: ["BOARD", "EXIT", "RIDE"],
                 route_id: "58",
                 route_type: 3
               }
             ]
    end

    test "RDTS informed entity with trips and stops is build properly" do
      alert_data = %{
        route_type: 3,
        description_text: "ok",
        header_text: "hello",
        effect_name: "Delay",
        route_ids: ["57"],
        trip_ids: ["123", "345", "456"],
        trip_information_by_id: %{
          "123" => %{direction_id: 0, route_id: "57"},
          "345" => %{direction_id: 0, route_id: "57"},
          "456" => %{direction_id: 0, route_id: "57"}
        },
        stop_ids: ["a", "b"],
        direction: "default"
      }

      result = AlertBuilder.build_alert(alert_data, :RDTS)

      assert result.informed_entity == [
               %{
                 activities: ["BOARD", "EXIT", "RIDE"],
                 route_id: "57",
                 route_type: 3,
                 direction_id: 0,
                 stop_id: "a",
                 trip: %{
                   trip_id: "123",
                   route_id: "57",
                   direction_id: 0
                 }
               },
               %{
                 activities: ["BOARD", "EXIT", "RIDE"],
                 route_id: "57",
                 route_type: 3,
                 direction_id: 0,
                 stop_id: "a",
                 trip: %{
                   trip_id: "345",
                   route_id: "57",
                   direction_id: 0
                 }
               },
               %{
                 activities: ["BOARD", "EXIT", "RIDE"],
                 route_id: "57",
                 route_type: 3,
                 direction_id: 0,
                 stop_id: "a",
                 trip: %{
                   trip_id: "456",
                   route_id: "57",
                   direction_id: 0
                 }
               },
               %{
                 activities: ["BOARD", "EXIT", "RIDE"],
                 route_id: "57",
                 route_type: 3,
                 direction_id: 0,
                 stop_id: "b",
                 trip: %{
                   trip_id: "123",
                   route_id: "57",
                   direction_id: 0
                 }
               },
               %{
                 activities: ["BOARD", "EXIT", "RIDE"],
                 route_id: "57",
                 route_type: 3,
                 direction_id: 0,
                 stop_id: "b",
                 trip: %{
                   trip_id: "345",
                   route_id: "57",
                   direction_id: 0
                 }
               },
               %{
                 activities: ["BOARD", "EXIT", "RIDE"],
                 route_id: "57",
                 route_type: 3,
                 direction_id: 0,
                 stop_id: "b",
                 trip: %{
                   trip_id: "456",
                   route_id: "57",
                   direction_id: 0
                 }
               }
             ]
    end

    test "SR informed entity routes and stops includes route type" do
      alert_data = %{
        route_type: 1,
        description_text: "ok",
        header_text: "hello",
        effect_name: "Delay",
        route_ids: ["56", "57", "58"],
        route_types_by_id: %{"56" => 1, "57" => 3, "58" => 1},
        stop_ids: ["a", "b"],
        direction: "default"
      }

      result = AlertBuilder.build_alert(alert_data, :SR)

      assert result.informed_entity == [
               %{
                 activities: ["BOARD", "EXIT", "RIDE"],
                 route_id: "56",
                 route_type: 1,
                 stop_id: "a"
               },
               %{
                 activities: ["BOARD", "EXIT", "RIDE"],
                 route_id: "56",
                 route_type: 1,
                 stop_id: "b"
               },
               %{
                 activities: ["BOARD", "EXIT", "RIDE"],
                 route_id: "57",
                 route_type: 3,
                 stop_id: "a"
               },
               %{
                 activities: ["BOARD", "EXIT", "RIDE"],
                 route_id: "57",
                 route_type: 3,
                 stop_id: "b"
               },
               %{
                 activities: ["BOARD", "EXIT", "RIDE"],
                 route_id: "58",
                 route_type: 1,
                 stop_id: "a"
               },
               %{
                 activities: ["BOARD", "EXIT", "RIDE"],
                 route_id: "58",
                 route_type: 1,
                 stop_id: "b"
               }
             ]
    end
  end
end
