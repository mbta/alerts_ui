defmodule AlertsUI.Models.IBIAlert do
  @moduledoc """
  A single export from IBI, corresponding to an alert or alert revision.
  """

  use AlertsUI.Schema

  @type t :: %__MODULE__{
          id: Ecto.UUID,
          alert_version_id: String.t(),
          alert_id: String.t(),
          version_no: String.t(),
          alert_time_type: String.t(),
          effect_name: String.t(),
          cause_name: String.t(),
          severity_name: String.t(),
          created_dt: String.t(),
          effect_start: String.t(),
          effect_end: String.t(),
          recurrence_days: String.t(),
          recurrence_start_time: String.t(),
          recurrence_end_time: String.t(),
          recurrence_start: String.t(),
          recurrence_end: String.t(),
          notif_start: String.t(),
          notif_end: String.t(),
          last_modified_by: String.t(),
          last_modified_dt: String.t(),
          header: String.t(),
          send_via_paess: String.t(),
          paess: String.t(),
          url: String.t(),
          details: String.t(),
          affent_list: String.t(),
          informed_route_id: String.t(),
          informed_direction_id: String.t(),
          informed_trip_id: String.t(),
          informed_stop_id: String.t(),
          informed_facility_id: String.t(),
          gui_mode_name: String.t(),
          is_closed: String.t(),
          send_to_govd: String.t(),
          send_to_twitter: String.t(),
          set_as_website_banner: String.t(),
          banner_text: String.t(),
          reminders: String.t(),
          pcf: String.t(),
          send_bulletin_on_close: String.t(),
          send_bulletin_on_create: String.t(),
          tts_header_text: String.t(),
          tts_description_text: String.t(),
          integer_version_no: integer()
        }

  @fields ~w[
    alert_version_id
    alert_id
    version_no
    alert_time_type
    effect_name
    cause_name
    severity_name
    created_dt
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

  schema "ibi_alerts" do
    Enum.each(@fields, fn field_name -> field field_name, :string end)
    field :integer_version_no, :integer
    timestamps()
  end

  def fields, do: @fields

  def changeset(%__MODULE__{} = imported_ibi_alert, params) do
    Ecto.Changeset.cast(imported_ibi_alert, params, @fields)
  end
end
