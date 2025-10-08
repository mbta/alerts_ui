defmodule AlertsUI.Models.IBIAlert do
  use AlertsUI.Schema

  @fields ~w[
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
    timestamps()
  end

  def changeset(%__MODULE__{} = imported_ibi_alert, params) do
    Ecto.Changeset.cast(imported_ibi_alert, params, @fields)
  end

  def row_to_changeset(row = [], existing = %{}) do
    alert = existing[row_to_alert_id(row)] || %__MODULE__{}
    changeset(alert, row_to_params(row))
  end

  def row_to_alert_id(row), do: row[1]

  def row_to_params(row = []) do
    row
    |> Enum.with_index()
    |> Enum.reduce(%{}, fn {value, index}, params ->
      case @fields[index] do
        nil -> raise "no field name at index #{index}"
        field_name -> Map.put(params, %{field_name => value})
      end
    end)
  end
end
