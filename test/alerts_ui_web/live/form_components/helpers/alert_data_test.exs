defmodule AlertsUIWeb.FormComponents.Helpers.AlertDataTest do
  @moduledoc false
  use AlertsUIWeb.ConnCase
  import AlertsUI.Support.Factory

  alias AlertsUI.Alerts
  alias AlertsUI.Models.ActivePeriod
  alias AlertsUIWeb.FormComponents.Helpers.AlertData

  describe "build_alert_data/1" do
    test "it returns empty map given nil" do
      assert AlertData.build_alert_data(nil) == %AlertData{}
    end

    test "works if given alert instead of alert id" do
      alert =
        insert(:alert, %{
          alert_id: "1",
          effect: :ACCESSIBILITY_ISSUE,
          effect_detail: "ACCESS_ISSUE",
          header_text: "cool header text",
          description_text: "description text",
          informed_entity: [],
          primary_service_type: "access",
          original_route_selections: []
        })

      assert %AlertData{
               combination: :ACCESS,
               direction: "default",
               effect_name: "Access Issue",
               route_type: nil,
               route_ids: [],
               stop_ids: [],
               trip_ids: [],
               facility_id: nil,
               header_text: "cool header text",
               description_text: "description text",
               service_types: [],
               reminder_times: [~N[2024-09-24 20:01:00]],
               notification_specifier: :same_as_effect_period,
               alert_timing: :"one-time"
             } = AlertData.build_alert_data(alert)
    end

    test "correctly fills in route_types_by_id for stop-route" do
      insert(:alert, %{
        alert_id: "1",
        effect: :NO_SERVICE,
        effect_detail: "DOCK_CLOSURE",
        header_text: "cool header text",
        description_text: "description text",
        informed_entity: [%{route_type: 4, route_id: "1", direction_id: 0, stop_id: "2"}],
        primary_service_type: "4",
        original_route_selections: ["1"]
      })

      assert %AlertData{
               combination: :SR,
               effect_name: "Dock Closure",
               direction: "0",
               route_type: 4,
               route_types_by_id: %{"1" => 4},
               route_ids: ["1"],
               stop_ids: ["2"],
               trip_ids: [],
               facility_id: nil,
               header_text: "cool header text",
               description_text: "description text",
               service_types: [],
               reminder_times: [~N[2024-09-24 20:01:00]],
               notification_specifier: :same_as_effect_period,
               alert_timing: :"one-time"
             } = AlertData.build_alert_data("1")
    end

    test "works if informed entities empty" do
      insert(:alert, %{
        alert_id: "1",
        effect: :ACCESSIBILITY_ISSUE,
        effect_detail: "ACCESS_ISSUE",
        header_text: "cool header text",
        description_text: "description text",
        informed_entity: [],
        primary_service_type: "access",
        original_route_selections: []
      })

      assert %AlertData{
               combination: :ACCESS,
               direction: "default",
               effect_name: "Access Issue",
               route_type: nil,
               route_ids: [],
               stop_ids: [],
               trip_ids: [],
               facility_id: nil,
               header_text: "cool header text",
               description_text: "description text",
               service_types: [],
               reminder_times: [~N[2024-09-24 20:01:00]],
               notification_specifier: :same_as_effect_period,
               alert_timing: :"one-time"
             } = AlertData.build_alert_data("1")
    end

    test "handles directions correctly" do
      insert(:alert, %{
        alert_id: "1",
        effect: :SIGNIFICANT_DELAYS,
        effect_detail: "DELAY",
        header_text: "cool header text",
        description_text: "description text",
        informed_entity: [
          %{route_type: 1, route_id: "1", direction_id: 0},
          %{route_type: 1, route_id: "2", stop_id: "a2", direction_id: 0},
          %{route_type: 1, route_id: "3", stop_id: "a3", direction_id: 1},
          %{route_type: 1, route_id: "4", trip: build(:trip_descriptor, %{trip_id: "b1"})}
        ],
        primary_service_type: "1",
        original_route_selections: ["1", "2", "3", "4"]
      })

      assert %AlertData{
               combination: :RDS,
               direction: "default",
               effect_name: "Delay",
               facility_id: nil,
               route_type: 1,
               route_ids: ["1", "2", "3", "4"],
               stop_ids: ["a2", "a3"],
               trip_ids: ["b1"],
               header_text: "cool header text",
               description_text: "description text",
               service_types: [],
               reminder_times: [~N[2024-09-24 20:01:00]],
               notification_specifier: :same_as_effect_period,
               alert_timing: :"one-time"
             } = AlertData.build_alert_data("1")
    end

    test "gets facility id correctly" do
      insert(:alert, %{
        alert_id: "1",
        effect: :OTHER_EFFECT,
        effect_detail: "BIKE_ISSUE",
        header_text: "cool header text",
        description_text: "description text",
        informed_entity: [
          %{facility_id: "example-facility"}
        ],
        primary_service_type: "access"
      })

      assert %AlertData{
               combination: :ACCESS,
               direction: "default",
               effect_name: "Bike Issue",
               facility_id: "example-facility",
               stop_ids: [],
               route_ids: [],
               trip_ids: [],
               service_types: [nil],
               header_text: "cool header text",
               description_text: "description text",
               reminder_times: [~N[2024-09-24 20:01:00]],
               alert_timing: :"one-time",
               notification_specifier: :same_as_effect_period
             } = AlertData.build_alert_data("1")
    end

    test "builds alert data from alert" do
      insert(:alert, %{
        alert_id: "1",
        effect: :SIGNIFICANT_DELAYS,
        effect_detail: "DELAY",
        header_text: "cool header text",
        description_text: "description text",
        url: "http://www.example.com",
        image_url: "http://www.example.com/example.jpg",
        image_alternative_text: "An example image",
        active_period_start: ~U[2024-05-02 16:09:34.007545Z],
        active_period_end: ~U[2024-05-04 01:09:34.007545Z],
        active_period: [
          %{start: ~U[2024-05-02 16:09:34.007545Z], end: ~U[2024-05-04 01:09:34.007545Z]}
        ],
        notification_period_start: ~U[2024-05-02 16:09:34.007545Z],
        duration_certainty: :KNOWN,
        cause_detail: "HAZMAT_CONDITION",
        severity: 3,
        severity_level: :WARNING,
        reminder_times: [
          build(:reminder_time, %{reminder_time: ~U[2024-05-02 16:10:34.007545Z]}),
          build(:reminder_time, %{reminder_time: ~U[2024-05-02 16:11:34.007545Z]})
        ],
        informed_entity: [
          %{route_type: 3, route_id: "1"},
          %{route_type: 3, route_id: "2", stop_id: "a2"},
          %{route_type: 3, route_id: "3", stop_id: "a3"},
          %{route_type: 3, route_id: "4", trip: build(:trip_descriptor, %{trip_id: "b1"})}
        ],
        primary_service_type: "3",
        original_route_selections: ["1", "2", "3", "4"]
      })

      assert %AlertData{
               combination: :RDS,
               direction: "default",
               effect_name: "Delay",
               url: "http://www.example.com",
               image_url: "http://www.example.com/example.jpg",
               image_alternative_text: "An example image",
               route_type: 3,
               facility_id: nil,
               route_ids: ["1", "2", "3", "4"],
               stop_ids: ["a2", "a3"],
               trip_ids: ["b1"],
               header_text: "cool header text",
               description_text: "description text",
               active_period_start_specifier: "custom",
               active_period_end_specifier: "custom",
               active_period_end: ~N[2024-05-03 21:09:34],
               active_period_start: ~N[2024-05-02 12:09:34],
               notification_period_start: ~N[2024-05-02 12:09:34],
               notification_specifier: :custom,
               active_period_start_date: ~D[2024-05-02],
               active_period_end_date: ~D[2024-05-03],
               service_types: [],
               cause_detail: "HAZMAT_CONDITION",
               severity: 3,
               reminder_times: [~N[2024-05-02 12:10:34], ~N[2024-05-02 12:11:34]],
               alert_timing: :"one-time"
             } = AlertData.build_alert_data("1")
    end

    test "handles detour alert with one route" do
      insert(:alert, %{
        alert_id: "1",
        effect: :DETOUR,
        effect_detail: "DETOUR",
        effect_name: "Detour",
        header_text: "cool header text",
        description_text: "description text",
        duration_certainty: :KNOWN,
        active_period_start: ~U[2024-05-02 16:09:34.007545Z],
        active_period_end: ~U[2024-05-04 01:09:34.007545Z],
        active_period: [
          %{start: ~U[2024-05-02 16:09:34.007545Z], end: ~U[2024-05-04 01:09:34.007545Z]}
        ],
        notification_period_start: ~U[2024-05-02 16:09:34.007545Z],
        original_route_selections: ["1"],
        informed_entity: [
          %{route_type: 3, route_id: "1"}
        ],
        primary_service_type: "3"
      })

      result = AlertData.build_alert_data("1")
      assert result.single_route_id == "1"
    end

    test "handles multi-route detour alert" do
      insert(:alert, %{
        alert_id: "1",
        effect: :DETOUR,
        effect_detail: "DETOUR",
        effect_name: "Multi-Route Detour",
        header_text: "cool header text",
        description_text: "description text",
        duration_certainty: :KNOWN,
        active_period_start: ~U[2024-05-02 16:09:34.007545Z],
        active_period_end: ~U[2024-05-04 01:09:34.007545Z],
        active_period: [
          %{start: ~U[2024-05-02 16:09:34.007545Z], end: ~U[2024-05-04 01:09:34.007545Z]}
        ],
        notification_period_start: ~U[2024-05-02 16:09:34.007545Z],
        original_route_selections: ["1"],
        informed_entity: [
          %{route_type: 3, route_id: "1"}
        ],
        primary_service_type: "access"
      })

      result = AlertData.build_alert_data("1")
      assert result.single_route_id == nil
    end

    test "gets route ids from original_route_selections field" do
      insert(:alert, %{
        alert_id: "1",
        effect: :SIGNIFICANT_DELAYS,
        effect_detail: "DELAY",
        header_text: "cool header text",
        description_text: "description text",
        active_period_start: ~U[2024-05-02 16:09:34.007545Z],
        active_period_end: ~U[2024-05-04 01:09:34.007545Z],
        active_period: [
          %{start: ~U[2024-05-02 16:09:34.007545Z], end: ~U[2024-05-04 01:09:34.007545Z]}
        ],
        notification_period_start: ~U[2024-05-02 16:09:34.007545Z],
        duration_certainty: :KNOWN,
        cause_detail: "HAZMAT_CONDITION",
        severity: 3,
        severity_level: :WARNING,
        informed_entity: [
          %{route_type: 1, route_id: "Green-B"},
          %{route_type: 1, route_id: "Green-C", stop_id: "a2"},
          %{route_type: 1, route_id: "Green-E", stop_id: "a3"},
          %{route_type: 1, route_id: "Blue", trip: build(:trip_descriptor, %{trip_id: "b1"})}
        ],
        original_route_selections: ["Green", "Blue"]
      })

      result = AlertData.build_alert_data("1")
      assert result.route_ids == ["Green", "Blue"]
    end

    test "builds data for a systemwide alert" do
      insert(:alert, %{
        alert_id: "1",
        effect: :SIGNIFICANT_DELAYS,
        effect_detail: "DELAY",
        header_text: "cool header text",
        description_text: "description text",
        informed_entity: [
          %{route_type: 3}
        ],
        primary_service_type: "systemwide"
      })

      assert %AlertData{
               combination: nil,
               effect_name: "Delay",
               service_types: [3],
               route_ids: [],
               stop_ids: [],
               trip_ids: [],
               direction: "default",
               facility_id: nil,
               header_text: "cool header text",
               description_text: "description text",
               reminder_times: [~N[2024-09-24 20:01:00]],
               notification_specifier: :same_as_effect_period,
               alert_timing: :"one-time"
             } = AlertData.build_alert_data("1")
    end

    test "builds data for a systemwide alert affecting the subway" do
      insert(:alert, %{
        alert_id: "1",
        effect: :SIGNIFICANT_DELAYS,
        effect_detail: "DELAY",
        header_text: "cool header text",
        description_text: "description text",
        informed_entity: [
          %{route_type: 0},
          %{route_type: 1},
          %{route_type: 3}
        ],
        primary_service_type: "systemwide"
      })

      assert %AlertData{
               combination: nil,
               effect_name: "Delay",
               service_types: [1, 3],
               route_ids: [],
               stop_ids: [],
               trip_ids: [],
               direction: "default",
               facility_id: nil,
               header_text: "cool header text",
               description_text: "description text",
               reminder_times: [~N[2024-09-24 20:01:00]],
               alert_timing: :"one-time",
               notification_specifier: :same_as_effect_period
             } = AlertData.build_alert_data("1")
    end

    test "handles unknown duration" do
      insert(:alert, %{
        alert_id: "1",
        effect: :ACCESSIBILITY_ISSUE,
        effect_detail: "ACCESS_ISSUE",
        header_text: "cool header text",
        description_text: "description text",
        informed_entity: [],
        primary_service_type: "access",
        active_period_start: ~U[2024-05-02 16:09:34.007545Z],
        active_period_end: nil,
        active_period: [%{start: ~U[2024-05-02 16:09:34.007545Z], end: nil}],
        duration_certainty: :UNKNOWN
      })

      assert AlertData.build_alert_data("1").active_period_end_specifier == "until_further_notice"
    end

    test "handles estimated duration" do
      insert(:alert, %{
        alert_id: "1",
        effect: :ACCESSIBILITY_ISSUE,
        effect_detail: "ACCESS_ISSUE",
        header_text: "cool header text",
        description_text: "description text",
        informed_entity: [],
        primary_service_type: "access",
        active_period_start: ~U[2024-05-02 16:09:34.007545Z],
        active_period_end: ~U[2024-05-02 18:09:34.007545Z],
        notification_period_end: ~U[2024-05-03 06:00:00Z],
        active_period: [
          %{start: ~U[2024-05-02 16:09:34.007545Z], end: ~U[2024-05-02 18:09:34.007545Z]}
        ],
        duration_certainty: :ESTIMATED,
        reminder_times: []
      })

      result = AlertData.build_alert_data("1")
      assert result.active_period_end_specifier == "later_today"
      assert result.active_period_end == ~N[2024-05-03 02:00:00]
      assert result.active_period_end_date == ~D[2024-05-02]
    end

    test "handles known duration at an end-of-service-time" do
      insert(:alert, %{
        alert_id: "1",
        effect: :ACCESSIBILITY_ISSUE,
        effect_detail: "ACCESS_ISSUE",
        header_text: "cool header text",
        description_text: "description text",
        informed_entity: [],
        primary_service_type: "access",
        active_period_start: ~U[2024-05-02 16:09:34.007545Z],
        active_period_end:
          utc_datetime_from_local(~D[2024-05-03], ActivePeriod.end_of_service_time()),
        active_period: [
          %{
            start: ~U[2024-05-02 16:09:34.007545Z],
            end: utc_datetime_from_local(~D[2024-05-03], ActivePeriod.end_of_service_time())
          }
        ],
        duration_certainty: :KNOWN,
        reminder_times: []
      })

      alert_data = AlertData.build_alert_data("1")
      assert alert_data.active_period_end_specifier == "end_of_service"
      assert alert_data.active_period_end_date == ~D[2024-05-02]
    end

    test "handles known duration at other time" do
      insert(:alert, %{
        alert_id: "1",
        effect: :ACCESSIBILITY_ISSUE,
        effect_detail: "ACCESS_ISSUE",
        header_text: "cool header text",
        description_text: "description text",
        informed_entity: [],
        primary_service_type: "access",
        active_period_start: ~U[2024-05-02 16:09:34.007545Z],
        active_period_end: ~U[2024-05-02 17:09:34.007545Z],
        active_period: [
          %{
            start: ~U[2024-05-02 16:09:34.007545Z],
            end: ~U[2024-05-02 17:09:34.007545Z]
          }
        ],
        duration_certainty: :KNOWN
      })

      result = AlertData.build_alert_data("1")
      assert result.active_period_end_specifier == "custom"
      assert result.active_period_end == local_naive_from_utc(~U[2024-05-02 17:09:34Z])
    end

    test "handles start specifier at start-of-service time" do
      insert(:alert, %{
        alert_id: "1",
        effect: :ACCESSIBILITY_ISSUE,
        effect_detail: "ACCESS_ISSUE",
        header_text: "cool header text",
        description_text: "description text",
        informed_entity: [],
        primary_service_type: nil,
        active_period_start:
          utc_datetime_from_local(~D[2024-05-02], ActivePeriod.start_of_service_time()),
        active_period_end: ~U[2024-05-02 16:09:34.007545Z],
        active_period: [
          %{
            start: utc_datetime_from_local(~D[2024-05-02], ActivePeriod.start_of_service_time()),
            end: ~U[2024-05-02 16:09:34.007545Z]
          }
        ],
        duration_certainty: :KNOWN
      })

      assert AlertData.build_alert_data("1").active_period_start_specifier == "start_of_service"
    end

    test "handles start specifier at other time" do
      insert(:alert, %{
        alert_id: "1",
        effect: :ACCESSIBILITY_ISSUE,
        effect_detail: "ACCESS_ISSUE",
        header_text: "cool header text",
        description_text: "description text",
        informed_entity: [],
        primary_service_type: nil,
        active_period_start: ~U[2024-05-02 16:09:34.007545Z],
        active_period_end: ~U[2024-05-02 17:09:34.007545Z],
        active_period: [
          %{
            start: ~U[2024-05-02 16:09:34.007545Z],
            end: ~U[2024-05-02 17:09:34.007545Z]
          }
        ],
        duration_certainty: :KNOWN
      })

      assert AlertData.build_alert_data("1").active_period_start_specifier == "custom"
    end

    test "handles recurring alert" do
      insert(:alert, %{
        alert_id: "1",
        effect: :ACCESSIBILITY_ISSUE,
        effect_detail: "ACCESS_ISSUE",
        header_text: "cool header text",
        description_text: "description text",
        informed_entity: [],
        primary_service_type: nil,
        active_period_start: ~U[2024-05-02 16:09:34.007545Z],
        active_period_end: ~U[2024-05-04 17:09:34.007545Z],
        active_period: [
          %{
            start: ~U[2024-05-02 16:09:34.007545Z],
            end: ~U[2024-05-02 17:09:34.007545Z]
          },
          %{
            start: ~U[2024-05-03 16:09:34.007545Z],
            end: ~U[2024-05-03 17:09:34.007545Z]
          },
          %{
            start: ~U[2024-05-04 16:09:34.007545Z],
            end: ~U[2024-05-04 17:09:34.007545Z]
          }
        ],
        duration_certainty: :KNOWN,
        recurrence_days: [:thursday, :friday, :saturday],
        recurrence_start_time: ~T[12:09:34],
        recurrence_end_time: ~T[13:09:34]
      })

      alert = AlertData.build_alert_data("1")
      assert alert.alert_timing == :recurring
      assert alert.recurrence_days == ["thursday", "friday", "saturday"]
      assert alert.active_period_start_specifier == "custom"
      assert alert.active_period_end_specifier == "custom"
      assert alert.active_period_start_time == ~T[12:09:34]
      assert alert.active_period_end_time == ~T[13:09:34]
      assert alert.active_period_start_date == ~D[2024-05-02]
      assert alert.active_period_end_date == ~D[2024-05-04]
    end

    test "handles recurring alert with end time after midnight" do
      insert(:alert, %{
        alert_id: "1",
        effect: :ACCESSIBILITY_ISSUE,
        effect_detail: "ACCESS_ISSUE",
        header_text: "cool header text",
        description_text: "description text",
        informed_entity: [],
        primary_service_type: nil,
        active_period_start: ~U[2024-05-02 16:09:34.007545Z],
        active_period_end: ~U[2024-05-05 06:09:34.007545Z],
        active_period: [
          %{
            start: ~U[2024-05-02 16:09:34.007545Z],
            end: ~U[2024-05-03 06:09:34.007545Z]
          },
          %{
            start: ~U[2024-05-03 16:09:34.007545Z],
            end: ~U[2024-05-04 06:09:34.007545Z]
          },
          %{
            start: ~U[2024-05-04 16:09:34.007545Z],
            end: ~U[2024-05-05 06:09:34.007545Z]
          }
        ],
        duration_certainty: :KNOWN,
        recurrence_days: [:thursday, :friday, :saturday],
        recurrence_start_time: ~T[16:09:34],
        recurrence_end_time: ~T[06:09:34]
      })

      alert = AlertData.build_alert_data("1")
      assert alert.alert_timing == :recurring
      assert alert.active_period_end_date == ~D[2024-05-04]
    end

    test "handles recurring alert with no set end" do
      insert(:alert, %{
        alert_id: "1",
        effect: :ACCESSIBILITY_ISSUE,
        effect_detail: "ACCESS_ISSUE",
        header_text: "cool header text",
        description_text: "description text",
        informed_entity: [],
        primary_service_type: nil,
        active_period_start: ~U[2024-05-02 16:09:34.007545Z],
        active_period_end: nil,
        active_period: [
          %{
            start: ~U[2024-05-02 16:09:34.007545Z],
            end: ~U[2024-05-03 07:00:00Z]
          },
          %{
            start: ~U[2024-05-04 16:09:34.007545Z],
            end: ~U[2024-05-03 07:00:00Z]
          },
          %{
            start: ~U[2024-05-09 16:09:34.007545Z],
            end: ~U[2024-05-10 07:00:00Z]
          },
          %{
            start: ~U[2024-05-11 16:09:34.007545Z],
            end: ~U[2024-05-12 07:00:00Z]
          }
        ],
        duration_certainty: :KNOWN,
        recurrence_days: ["thursday", "saturday"]
      })

      alert = AlertData.build_alert_data("1")
      assert alert.alert_timing == :recurring
      assert alert.recurrence_days == ["thursday", "saturday"]
      assert alert.active_period_start_specifier == "custom"
      assert alert.active_period_end_specifier == "until_further_notice"
      assert alert.active_period_start_time == ~T[12:09:34]
      assert alert.active_period_end_time == ~T[03:00:00]
      assert alert.active_period_start_date == ~D[2024-05-02]
      assert alert.active_period_end_date == nil
    end

    test "returns correct creation info and edited info if edited by user" do
      user = insert(:user)

      seconduser =
        insert(:user, %{
          role: :user,
          email: "secondfake@example.com",
          last_name: "Secondlast",
          first_name: "Secondfirst",
          keycloak_id: "456-789"
        })

      original_alert_map =
        build(
          :alert_map,
          %{
            alert_id: "123",
            header_text: "old header text",
            user: user
          }
        )

      new_params =
        build(:alert_map, %{
          alert_id: "123",
          header_text: "new header text",
          active_period: [%{start: ~U[2023-10-12 00:01:00Z], end: ~U[2023-10-13 00:03:00Z]}],
          user: seconduser
        })

      Alerts.create_or_update_alert(original_alert_map, user)

      existing_alert = Alerts.get_by_alert_id("123")
      :timer.sleep(1000)
      Alerts.create_or_update_alert(new_params, seconduser, existing_alert)

      alert = AlertData.build_alert_data("123")

      assert DateTime.to_date(alert.created_at) == Date.utc_today()

      assert "#{user.first_name} #{user.last_name}" == alert.created_by

      assert "#{seconduser.first_name} #{seconduser.last_name}" == alert.last_edited_by
    end

    test "returns correct creation info and edited info if edited by computer" do
      user = insert(:user)

      original_alert_map =
        build(
          :alert_map,
          %{
            alert_id: "123",
            header_text: "old header text",
            user: user
          }
        )

      Alerts.create_or_update_alert(original_alert_map, user)

      existing_alert = Alerts.get_by_alert_id("123")

      :timer.sleep(1000)
      Alerts.close(existing_alert, "closed automatically", false)

      alert = AlertData.build_alert_data("123")

      assert DateTime.to_date(alert.created_at) == Date.utc_today()

      assert "#{user.first_name} #{user.last_name}" == alert.created_by

      assert "closed automatically" == alert.last_edited_by
    end
  end

  defp utc_datetime_from_local(date, time) do
    DateTime.new!(date, time, "America/New_York") |> DateTime.shift_zone!("Etc/UTC")
  end

  defp local_naive_from_utc(datetime) do
    datetime |> DateTime.shift_zone!("America/New_York") |> DateTime.to_naive()
  end
end
