defmodule AlertsUI.Support.Factory do
  @moduledoc false
  use ExMachina.Ecto, repo: AlertsUI.Repo

  alias AlertsUI.Models.{
    ActivePeriod,
    Alert,
    ExtendedTime,
    InformedEntity,
    ReminderTime,
    TripDescriptor,
    User
  }

  def extended_time_factory, do: %ExtendedTime{relative_day: 1, time: ~T[12:12:12]}

  def informed_entity_factory, do: %InformedEntity{route_id: "1"}

  def trip_descriptor_factory, do: %TripDescriptor{trip_id: "1"}

  @spec informed_entity_with_trip_factory() :: AlertsUI.Models.InformedEntity.t()
  def informed_entity_with_trip_factory do
    %InformedEntity{route_id: "1", trip: build(:trip_descriptor)}
  end

  @spec reminder_time_factory() :: AlertsUI.Models.ReminderTime.t()
  def reminder_time_factory do
    %ReminderTime{reminder_time: ~U[2024-09-25 00:01:00Z]}
  end

  @spec active_period_factory() :: AlertsUI.Models.ActivePeriod.t()
  def active_period_factory do
    %ActivePeriod{start: ~U[2023-10-12 00:01:00Z], end: ~U[2023-10-13 00:01:00Z]}
  end

  def alert_factory do
    %Alert{
      alert_id: "123",
      header_text: "a",
      description_text: "b",
      active_period: [
        build(:active_period)
      ],
      informed_entity: [build(:informed_entity_with_trip)],
      reminder_times: [build(:reminder_time)],
      active_period_start: ~U[2023-10-12 00:01:00Z],
      last_modified_timestamp: ~U[2023-10-12 00:01:00Z],
      primary_service_type: "1"
    }
  end

  def alert_map_factory do
    %{
      active_period: [
        %{
          start: ~U[2023-10-20 16:15:00Z],
          end: ~U[2023-10-20 18:45:38Z]
        }
      ],
      active_period_start: ~U[2023-10-20 00:01:00Z],
      alert_id: "123",
      description_text: "b",
      header_text: "a",
      informed_entity: [%{route_id: "1", trip: %{trip_id: "2"}, route_type: 1}],
      severity: 3,
      user: build(:user),
      primary_service_type: "1"
    }
  end

  def alert_entity_data_factory do
    %{
      "alert" => %{
        "active_period" => [%{"start" => 1_681_419_933}],
        "alert_lifecycle" => "ONGOING",
        "cause" => "UNKNOWN_CAUSE",
        "cause_detail" => "UNKNOWN_CAUSE",
        "created_timestamp" => 1_681_419_934,
        "description_text" => %{
          "translation" => [
            %{"language" => "en", "text" => "Affected routes:\r\n62\r\n76"}
          ]
        },
        "duration_certainty" => "UNKNOWN",
        "reminder_times" => [
          1_692_910_800,
          1_692_982_800,
          1_693_038_600,
          1_693_125_000,
          1_693_211_400
        ],
        "effect" => "STOP_MOVED",
        "effect_detail" => "STOP_MOVE",
        "header_text" => %{
          "translation" => [
            %{
              "language" => "en",
              "text" => "Massachusetts Ave @ Percy Rd (outbound) stop moving until 3:30 PM"
            }
          ]
        },
        "informed_entity" => [
          %{
            "activities" => ["BOARD"],
            "agency_id" => "1",
            "route_id" => "627",
            "facility_id" => "park-qamnl-garage",
            "route_type" => 3,
            "stop_id" => "8597"
          },
          %{
            "activities" => ["BOARD"],
            "agency_id" => "1",
            "route_id" => "62",
            "route_type" => 3,
            "stop_id" => "8597"
          },
          %{
            "activities" => ["BOARD"],
            "agency_id" => "1",
            "route_id" => "76",
            "route_type" => 3,
            "stop_id" => "8597"
          }
        ],
        "service_effect_text" => %{
          "translation" => [
            %{
              "language" => "en",
              "text" => "Massachusetts Ave @ Percy Rd stop moved"
            }
          ]
        },
        "severity" => 1,
        "severity_level" => "INFO",
        "short_header_text" => %{
          "translation" => [
            %{
              "language" => "en",
              "text" => "Massachusetts Ave @ Percy Rd (outbound) stop moving until 3:30 PM"
            }
          ]
        },
        "timeframe_text" => %{
          "translation" => [%{"language" => "en", "text" => "ongoing"}]
        },
        "recurrence_text" => %{
          "translation" => [%{"language" => "en", "text" => "weekdays"}]
        }
      },
      "id" => "123456"
    }
  end

  def last_modified(alert_entity_data, unix_time),
    do: put_in(alert_entity_data, ["alert", "last_modified_timestamp"], unix_time)

  def with_header_text(alert_entity_data, text),
    do:
      put_in(alert_entity_data, ["alert", "header_text", "translation"], [
        %{
          "language" => "en",
          "text" => text
        }
      ])

  def user_map_factory do
    %{
      keycloak_id: "123-456",
      email: "fake@example.com",
      first_name: "Firstname",
      last_name: "Lastname",
      role: :user
    }
  end

  def user_factory do
    struct(User, user_map_factory())
  end
end
