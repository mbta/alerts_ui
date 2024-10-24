# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     AlertsUI.Repo.insert!(%AlertsUI.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias AlertsUI.Repo

alias AlertsUI.Models.{
  ActivePeriod,
  Alert,
  ExtendedTime,
  InformedEntity,
  ReminderTime,
  TripDescriptor
}

trip =
  Repo.insert!(%TripDescriptor{
    trip_id: "001",
    route_id: "222",
    direction_id: 3,
    start_time: %ExtendedTime{relative_day: 2, time: ~T[01:30:30]},
    start_date: ~D[2023-10-01],
    schedule_relationship: :SCHEDULED
  })

informed_entity_1 =
  Repo.insert!(%InformedEntity{
    agency_id: "111",
    route_id: "222",
    facility_id: "park-qamnl-garage",
    route_type: 1,
    direction_id: 3,
    stop_id: "333",
    activities: [:BOARD, :EXIT],
    trip: trip
  })

informed_entity_2 =
  Repo.insert!(%InformedEntity{
    agency_id: "555",
    route_id: "666",
    route_type: 2,
    direction_id: 4,
    stop_id: "777",
    activities: [:PARK_CAR, :STORE_BIKE]
  })

active_period_1 =
  Repo.insert!(%ActivePeriod{
    start: ~U[2023-10-12 00:01:00Z],
    end: ~U[2023-10-12 00:02:00Z]
  })

active_period_2 =
  Repo.insert!(%ActivePeriod{
    start: ~U[2023-10-12 00:03:00Z],
    end: ~U[2023-10-12 00:04:00Z]
  })

reminder_time = Repo.insert!(%ReminderTime{reminder_time: ~U[2024-09-25 00:03:00Z]})

Repo.insert!(%Alert{
  alert_id: "12345",
  effect: :NO_SERVICE,
  effect_detail: "No Service",
  cause: :UNKNOWN_CAUSE,
  cause_detail: "Unknown Cause",
  header_text: "Test Alert",
  description_text: "There's no service! Due to an unknown cause!",
  severity_level: :UNKNOWN_SEVERITY,
  url: "https://example.com",
  service_effect_text: "The service is: none",
  short_header_text: "no Service",
  severity: 3,
  last_push_notification_timestamp: ~U[2023-10-12 00:03:00Z],
  closed_timestamp: ~U[2023-10-13 00:03:00Z],
  timeframe_text: "ongoing",
  recurrence_text: "weekdays",
  alert_lifecycle: :NEW,
  duration_certainty: :UNKNOWN,
  active_period: [active_period_1, active_period_2],
  image_url: "https://example.com/image1.png",
  image_alternative_text: "an alert image",
  informed_entity: [informed_entity_1, informed_entity_2],
  reminder_times: [reminder_time]
})
