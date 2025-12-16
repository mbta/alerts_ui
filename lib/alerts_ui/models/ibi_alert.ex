defmodule AlertsUI.Models.IBIAlert do
  @moduledoc """
  A single export from IBI, corresponding to an alert or alert revision.
  """

  use AlertsUI.Schema

  @type t :: %__MODULE__{
          id: Ecto.UUID,
          alert_version_id: String.t() | nil,
          alert_id: String.t() | nil,
          version_no: String.t() | nil,
          alert_time_type: String.t() | nil,
          effect_name: String.t() | nil,
          cause_name: String.t() | nil,
          severity_name: String.t() | nil,
          created_dt: String.t() | nil,
          effect_start: String.t() | nil,
          effect_end: String.t() | nil,
          recurrence_days: String.t() | nil,
          recurrence_start_time: String.t() | nil,
          recurrence_end_time: String.t() | nil,
          recurrence_start: String.t() | nil,
          recurrence_end: String.t() | nil,
          notif_start: String.t() | nil,
          notif_end: String.t() | nil,
          last_modified_by: String.t() | nil,
          last_modified_dt: String.t() | nil,
          header: String.t() | nil,
          send_via_paess: String.t() | nil,
          paess: String.t() | nil,
          url: String.t() | nil,
          details: String.t() | nil,
          affent_list: String.t() | nil,
          informed_route_id: String.t() | nil,
          informed_direction_id: String.t() | nil,
          informed_trip_id: String.t() | nil,
          informed_stop_id: String.t() | nil,
          informed_facility_id: String.t() | nil,
          gui_mode_name: String.t() | nil,
          is_closed: String.t() | nil,
          send_to_govd: String.t() | nil,
          send_to_twitter: String.t() | nil,
          set_as_website_banner: String.t() | nil,
          banner_text: String.t() | nil,
          reminders: String.t() | nil,
          pcf: String.t() | nil,
          send_bulletin_on_close: String.t() | nil,
          send_bulletin_on_create: String.t() | nil,
          tts_header_text: String.t() | nil,
          tts_description_text: String.t() | nil,
          alert_image_url: String.t() | nil,
          alert_image_description: String.t() | nil,
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
    alert_image_url
    alert_image_description
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
