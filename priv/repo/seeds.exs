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
    activities: [:PARK_CAR, :STORE_BIKE],
    trip: trip
  })

informed_entity_2 =
  Repo.insert!(%InformedEntity{
    agency_id: "555",
    route_id: "666",
    route_type: 2,
    direction_id: 4,
    stop_id: "777",
    activities: [:BOARD, :EXIT]
  })

reminder_time = Repo.insert!(%ReminderTime{reminder_time: ~U[2024-09-25 00:03:00Z]})

# current alerts
Enum.each(1..20, fn i ->
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

  Repo.insert!(%Alert{
    alert_id: "1#{i}",
    effect: :NO_SERVICE,
    effect_detail: "Current #{i}",
    effect_name: "Cancellation",
    cause: :UNKNOWN_CAUSE,
    cause_detail: "UNKNOWN_CAUSE",
    header_text: "Test Alert",
    description_text: "There's no service! Due to an unknown cause!",
    severity_level: :UNKNOWN_SEVERITY,
    url: "https://example.com",
    service_effect_text: "The service is: none",
    short_header_text: "Current #{i}",
    severity: 3,
    last_push_notification_timestamp: ~U[2023-10-12 00:03:00Z],
    closed_timestamp: ~U[2023-10-13 00:03:00Z],
    timeframe_text: "ongoing",
    recurrence_text: "weekdays",
    alert_lifecycle: :NEW,
    duration_certainty: :UNKNOWN,
    active_period: [active_period_1, active_period_2],
    active_period_start: active_period_1.start,
    active_period_end: nil,
    image_url: "https://example.com/image1.png",
    image_alternative_text: "an alert image",
    informed_entity: [informed_entity_1, informed_entity_2],
    reminder_times: [reminder_time],
    original_route_selections: [],
    notification_period_start: nil,
    notification_period_end: nil
  })
end)

# current alerts with open notifications
Enum.each(1..20, fn i ->
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

  Repo.insert!(%Alert{
    alert_id: "2#{i}",
    effect: :NO_SERVICE,
    effect_detail: "Current w/ open notification #{i}",
    effect_name: "Cancellation",
    cause: :UNKNOWN_CAUSE,
    cause_detail: "UNKNOWN_CAUSE",
    header_text: "Test Alert",
    description_text: "There's no service! Due to an unknown cause!",
    severity_level: :UNKNOWN_SEVERITY,
    url: "https://example.com",
    service_effect_text: "The service is: none",
    short_header_text: "Current w/ open notification #{i}",
    severity: 3,
    last_push_notification_timestamp: ~U[2023-10-12 00:03:00Z],
    closed_timestamp: ~U[2023-10-13 00:03:00Z],
    timeframe_text: "ongoing",
    recurrence_text: "weekdays",
    alert_lifecycle: :NEW,
    duration_certainty: :UNKNOWN,
    active_period: [active_period_1, active_period_2],
    active_period_start: active_period_1.start,
    active_period_end: nil,
    image_url: "https://example.com/image1.png",
    image_alternative_text: "an alert image",
    informed_entity: [informed_entity_1, informed_entity_2],
    reminder_times: [reminder_time],
    original_route_selections: [],
    notification_period_start: ~U[2023-10-12 00:04:00Z],
    notification_period_end: nil
  })
end)

# current alerts with one active period that has a nil end
Enum.each(1..20, fn i ->
  active_period_1 =
    Repo.insert!(%ActivePeriod{
      start: ~U[2023-10-12 00:01:00Z],
      end: nil
    })

  Repo.insert!(%Alert{
    alert_id: "3#{i}",
    effect: :NO_SERVICE,
    effect_detail: "Current w/ closed notification #{i}",
    effect_name: "Cancellation",
    cause: :UNKNOWN_CAUSE,
    cause_detail: "UNKNOWN_CAUSE",
    header_text: "Test Alert",
    description_text: "There's no service! Due to an unknown cause!",
    severity_level: :UNKNOWN_SEVERITY,
    url: "https://example.com",
    service_effect_text: "The service is: none",
    short_header_text: "Current w/ closed notification #{i}",
    severity: 3,
    last_push_notification_timestamp: ~U[2023-10-12 00:03:00Z],
    closed_timestamp: ~U[2023-10-13 00:03:00Z],
    timeframe_text: "ongoing",
    recurrence_text: "weekdays",
    alert_lifecycle: :NEW,
    duration_certainty: :UNKNOWN,
    active_period: [active_period_1],
    active_period_start: active_period_1.start,
    active_period_end: nil,
    image_url: "https://example.com/image1.png",
    image_alternative_text: "an alert image",
    informed_entity: [informed_entity_1, informed_entity_2],
    reminder_times: [reminder_time],
    original_route_selections: [],
    notification_period_start: ~U[2023-10-12 00:04:00Z],
    notification_period_end: nil
  })
end)

# past alerts
Enum.each(1..20, fn i ->
  Repo.insert!(%Alert{
    alert_id: "4#{i}",
    effect: :NO_SERVICE,
    effect_detail: "Past #{i}",
    effect_name: "Cancellation",
    cause: :UNKNOWN_CAUSE,
    cause_detail: "UNKNOWN_CAUSE",
    header_text: "Test Alert",
    description_text: "There's no service! Due to an unknown cause!",
    severity_level: :UNKNOWN_SEVERITY,
    url: "https://example.com",
    service_effect_text: "The service is: none",
    short_header_text: "Past #{i}",
    severity: 3,
    last_push_notification_timestamp: ~U[2023-10-12 00:03:00Z],
    closed_timestamp: ~U[2023-10-13 00:03:00Z],
    active_period_end: ~U[2023-10-13 00:03:00Z],
    timeframe_text: "ongoing",
    recurrence_text: "weekdays",
    alert_lifecycle: :NEW,
    duration_certainty: :KNOWN,
    active_period: [],
    active_period_start: ~U[2023-10-12 00:03:00Z],
    image_url: "https://example.com/image1.png",
    image_alternative_text: "an alert image",
    informed_entity: [informed_entity_1, informed_entity_2],
    reminder_times: [reminder_time],
    original_route_selections: [],
    notification_period_end: nil
  })
end)
