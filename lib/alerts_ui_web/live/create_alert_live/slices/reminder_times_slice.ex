defmodule AlertsUIWeb.CreateAlertLive.Slices.ReminderTimesSlice do
  @moduledoc """
  Slice that manages rider reminder datetimes embedded in an alert. Provides
  changeset helpers for casting/dropping reminder entries and renders the
  rider-reminders section of the alert form.
  """

  alias AlertsUI.Helpers.ReminderTimes
  alias AlertsUIWeb.CreateAlertLive.AlertData
  alias AlertsUIWeb.CreateAlertLive.Slice
  alias Phoenix.HTML.FormField

  import Ecto.Changeset

  use AlertsUIWeb, :html

  defstruct [:form_type, reminder_times: []]

  defimpl Slice, for: __MODULE__ do
    alias AlertsUIWeb.CreateAlertLive.Slices.ReminderTimesSlice

    def mount(_slice, socket, _base_params), do: socket

    def extract(slice, %AlertData{reminder_times: reminder_times} = _alert_data, _params) do
      converted =
        Enum.map(reminder_times || [], fn
          %{id: id, time: time} -> %AlertData.ReminderTime{id: id, reminder_time: time}
          %AlertData.ReminderTime{} = rt -> rt
        end)

      converted =
        if slice.form_type == :duplicating do
          # Filter to only future reminders when duplicating
          converted
          |> Enum.filter(fn %AlertData.ReminderTime{id: id, reminder_time: time} ->
            ReminderTimes.editable?(id, time)
          end)
        else
          converted
        end

      %{slice | reminder_times: converted}
    end

    def transform(_slice, changeset, params, _socket) do
      case params do
        %{"alert_data" => _alert_data_params} ->
          # NotificationPeriodSlice definitely runs first, so these are accurate
          min_time = get_field(changeset, :notification_period_start)
          max_time = get_field(changeset, :notification_period_end)

          changeset
          |> cast(params, [])
          |> ReminderTimesSlice.materialize_reminder_times()
          |> cast_embed(:reminder_times,
            sort_param: :reminder_sort,
            drop_param: :reminder_drop,
            with: &ReminderTimesSlice.reminder_time_changeset(&1, &2, min_time, max_time)
          )

        _ ->
          changeset
      end
    end

    def validate(_reminder_data, changeset, _params, _socket) do
      has_nested_error =
        get_embed(changeset, :reminder_times)
        |> Enum.find(fn rt -> is_list(rt.errors) and rt.errors != [] end)

      if has_nested_error do
        changeset |> add_error(:reminder_times, "Invalid entry in reminder times")
      else
        changeset
      end
    end

    def assigns(_slice, socket, _params), do: socket
  end

  def materialize_reminder_times(changeset) do
    current = get_field(changeset, :reminder_times, [])
    new_data = %{changeset.data | reminder_times: current}
    %{changeset | data: new_data, changes: Map.delete(changeset.changes, :reminder_times)}
  end

  def reminder_time_changeset(source, params, min_time, max_time) do
    id = if source.id, do: source.id, else: "new-#{Ecto.UUID.generate()}"
    source = %{source | id: id}

    source
    |> cast(params, [:reminder_time, :id])
    |> validate_required(:reminder_time, message: "Select reminder time")
    |> validate_after_notification_start(min_time)
    |> validate_before_notification_end(max_time)
  end

  defp validate_after_notification_start(changeset, %NaiveDateTime{} = min_time) do
    id = get_field(changeset, :id)
    exists? = not String.starts_with?(id, "new-")
    time = get_field(changeset, :reminder_time)

    if not exists? and match?(%NaiveDateTime{}, time) and
         NaiveDateTime.compare(min_time, time) == :gt do
      add_error(
        changeset,
        :reminder_time,
        "Reminder time must be after notification period starts (#{min_time |> formatted_datetime})"
      )
    else
      changeset
    end
  end

  defp validate_after_notification_start(changeset, _min_time), do: changeset

  defp validate_before_notification_end(changeset, %NaiveDateTime{} = max_time) do
    time = get_field(changeset, :reminder_time)

    if match?(%NaiveDateTime{}, time) and NaiveDateTime.compare(max_time, time) == :lt do
      add_error(
        changeset,
        :reminder_time,
        "Reminder time must be before notification period ends (#{max_time |> formatted_datetime})"
      )
    else
      changeset
    end
  end

  defp validate_before_notification_end(changeset, _max_time), do: changeset

  def render(assigns) do
    ~H"""
    <div class="min-w-full flex flex-col mt-8" id="reminder_times_form">
      <.h5 class="text-text-secondary mb-8 w-full text-center md:text-left">
        Rider reminders
      </.h5>
      <div>
        <.inputs_for :let={rt} field={@form[:reminder_times]}>
          <div class="flex flex-row mb-4" id={"reminder-time-component-#{rt.index}"}>
            <.reminder_input
              editable={ReminderTimes.editable?(rt[:id].value, rt[:reminder_time].value)}
              field={rt[:reminder_time]}
              id={rt[:id].value}
              index={rt.index}
              notification_start={@form[:notification_period_start].value}
              notification_end={@form[:notification_period_end].value}
            />
          </div>
        </.inputs_for>
      </div>
      <.button_secondary
        class="self-start mb-4"
        type="button"
        name="alert_data[reminder_sort][]"
        value="new"
        phx-click={JS.dispatch("change")}
      >
        Add reminder
      </.button_secondary>
    </div>
    """
  end

  attr :field, FormField, required: true
  attr :index, :any
  attr :id, :string
  attr :editable, :any, default: true
  attr :notification_start, DateTime
  attr :notification_end, DateTime

  def reminder_input(assigns) do
    # the reminder_time id is prevented from showing if it's nil because of a
    # subtle bug where "" and nil are treated both the same and different in
    # different parts of Ecto, which means a new Reminder would appear as a
    # duplicate of an old one if the field were allowed to exist.
    ~H"""
    <input
      type="hidden"
      name="alert_data[reminder_sort][]"
      value={@index}
      id={"reminder_times-sort-#{@index}"}
    />
    <input :if={@id} type="hidden" name={"alert_data[reminder_times][#{@index}][id]"} value={@id} />
    <input
      type="hidden"
      name={"alert_data[reminder_times][#{@index}][_persistent_id]"}
      value={@index}
    />
    <input
      :if={!@editable}
      type="hidden"
      name={"alert_data[reminder_times][#{@index}][reminder_time]"}
      value={@field.value}
      id={"reminder_times-#{@index}-reminder_time"}
    />
    <.datetime
      label="Reminder date and time"
      min={@notification_start |> naive_datetime_to_iso8601()}
      max={@notification_end |> naive_datetime_to_iso8601()}
      field={@field}
      value={@field.value}
      disabled={!@editable}
      id={"reminder_times--#{@index}-reminder_datetime"}
    >
      <.input type="hidden" name="alert_data[reminder_drop][]" value="" />
      <button
        :if={@editable}
        class="flex max-h-[3.2rem] items-center"
        type="button"
        name="alert_data[reminder_drop][]"
        value={@index}
        phx-click={JS.dispatch("change")}
        id={"reminder_times-#{@index}-reminder-drop"}
      >
        <.icon name="hero-x-mark" class="w-6 h-6" />
      </button>
      <span :if={!@editable} class="flex flex-row text-sm items-center">
        <.icon name="hero-check-circle-solid" class="w-6 h-6 text-mbta-green mr-1" /> Sent
      </span>
    </.datetime>
    """
  end

  defp naive_datetime_to_iso8601(nil), do: ""

  defp naive_datetime_to_iso8601(iso_datetime) when is_binary(iso_datetime), do: iso_datetime

  defp naive_datetime_to_iso8601(datetime) do
    datetime
    |> NaiveDateTime.truncate(:second)
    |> NaiveDateTime.to_iso8601()
    |> String.slice(0..-4//1)
  end

  defp formatted_datetime(datetime) do
    Timex.format!(datetime, "{0M}/{0D}/{YYYY}, {0h12}:{0m} {AM}")
  end
end
