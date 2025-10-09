defmodule AlertsUI.Repo.Migrations.CreateIBIAlerts do
  use Ecto.Migration

  @migration_fields ~w[
    alert_version_id
    alert_id
    version_no
    alert_time_type
    effect_name
    cause_name
    severity_name
    effect_start
    effect_end
    recurrence_days
    recurrence_start_time
    recurrence_end_time
    recurrence_start
    recurrence_end
    notif_start
    notif_end
    last_modified_by
    last_modified_dt
    header
    send_via_paess
    paess
    url
    details
    affent_list
    informed_route_id
    informed_direction_id
    informed_trip_id
    informed_stop_id
    informed_facility_id
    gui_mode_name
    is_closed
    send_to_govd
    send_to_twitter
    set_as_website_banner
    banner_text
    reminders
    pcf
    send_bulletin_on_close
    send_bulletin_on_create
    tts_header_text
    tts_description_text
  ]a

  def change do
    create table(:ibi_alerts) do
      Enum.each(@migration_fields, fn field -> add field, :string end)
      timestamps()
    end
    create unique_index(:ibi_alerts, [:alert_id, :version_no])
  end
end
