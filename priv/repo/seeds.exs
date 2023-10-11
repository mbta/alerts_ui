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
AlertsUI.Repo.insert!(%AlertsUI.Models.Alert{
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
  created_timestamp: ~U[2023-10-12 00:01:00Z],
  last_modified_timestamp: ~U[2023-10-12 00:02:00Z],
  last_push_notification_timestamp: ~U[2023-10-12 00:03:00Z],
  timeframe_text: "recently?",
  alert_lifecycle: :NEW,
  duration_certainty: :UNKNOWN,
  active_period: [
    %{start_time: ~U[2023-10-12 00:01:00Z], end_time: ~U[2023-10-12 00:02:00Z]},
    %{start_time: ~U[2023-10-12 00:03:00Z], end_time: ~U[2023-10-12 00:04:00Z]}
  ],
  image_url: "https://example.com/image1.png",
  image_alternative_text: "an alert image"
})
