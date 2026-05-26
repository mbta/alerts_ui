defmodule AlertsUIWeb.CreateAlertMonoLive.Slices.ReminderTimesSlice do
  alias AlertsUI.Helpers.ReminderTimes
  alias AlertsUIWeb.CreateAlertMonoLive.AlertData.ReminderTime
  alias AlertsUIWeb.CreateAlertMonoLive.AlertData
  alias AlertsUIWeb.CreateAlertMonoLive.Slice
  alias AlertsUIWeb.FormComponents.Helpers.DateTimeHelpers
  alias Phoenix.HTML.FormField

  import Ecto.Changeset

  use AlertsUIWeb, :html

  defstruct reminder_times: []

  defimpl Slice, for: __MODULE__ do
    alias AlertsUIWeb.CreateAlertMonoLive.Slices.ReminderTimesSlice

    def mount(_slice, socket, _base_params), do: socket

    def extract(slice, %AlertData{} = _alert_data, _params) do
      slice
    end

    def transform(_slice, changeset, params, _socket) do
      case params do
        %{"alert_data" => _alert_data_params} ->
          changeset
          |> ReminderTimesSlice.materialize_reminder_times()
          |> cast_embed(:reminder_times,
            sort_param: :reminder_sort,
            drop_param: :reminder_drop,
            with: &ReminderTimesSlice.reminder_time_changeset/2
          )

        _ ->
          changeset
      end
    end

    def validate(_slice, changeset, _params, _socket) do
      changeset
    end

    def assigns(_slice, socket, _params) do
      Phoenix.Component.assign(socket, %{
        current_time: DateTimeHelpers.current_time(),
        notification_start: Map.get(%{}, :notification_period_start),
        notification_end: Map.get(%{}, :notification_period_end)
      })
    end
  end

  def materialize_reminder_times(changeset) do
    current = get_field(changeset, :reminder_times, [])
    new_data = %{changeset.data | reminder_times: current}
    %{changeset | data: new_data, changes: Map.delete(changeset.changes, :reminder_times)}
  end

  def reminder_time_changeset(source, params) do
    cast(source, params, [:reminder_time, :max_time, :min_time, :id])
    |> validate_change(:reminder_time, fn :reminder_time, time ->
      exists? = String.trim(params["id"] || "") != ""
      min_time_string = params["min_time"] |> String.pad_trailing(19, ":00")

      with {:ok, min_time} <- NaiveDateTime.from_iso8601(min_time_string),
           false <- exists?,
           :gt <- NaiveDateTime.compare(min_time, time) do
        message =
          "Reminder time must be after notification period starts (#{min_time |> formatted_datetime})"

        [reminder_time: message]
      else
        _ -> []
      end
    end)
    |> validate_change(:reminder_time, fn :reminder_time, time ->
      max_time_string = params["max_time"] |> String.pad_trailing(19, ":00")

      with {:ok, max_time} <- NaiveDateTime.from_iso8601(max_time_string),
           :lt <- NaiveDateTime.compare(max_time, time) do
        message =
          "Reminder time must be before notification period ends (#{max_time |> formatted_datetime})"

        [reminder_time: message]
      else
        _ -> []
      end
    end)
  end

  def add_new_time(changeset, %{"reminder_times" => %{"new" => "new"}}) do
    existing = get_field(changeset, :reminder_times, [])
    put_embed(changeset, :reminder_times, existing ++ [%{}])
  end

  def add_new_time(changeset, _), do: changeset

  def drop_times(changeset, %{"reminder_drop" => indices}) do
    indices = Enum.filter(indices, &(&1 != ""))
    reminder_times = get_field(changeset, :reminder_times, [])

    # This is blowing away the errors byb pulling them out and readding them.
    filtered =
      Enum.reduce(indices, reminder_times, fn index, rts ->
        List.pop_at(rts, String.to_integer(index)) |> elem(1)
      end)

    put_embed(changeset, :reminder_times, filtered)
  end

  def drop_times(changeset, _), do: changeset

  def render(assigns) do
    assigns =
      assign(assigns, %{
        current_time: DateTimeHelpers.current_time()
      })

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
              current_time={@current_time}
              field={rt[:reminder_time]}
              id={rt[:id].value}
              index={rt.index}
              notification_start={
                # @notification_start
                nil
              }
              notification_end={
                # @notification_end
                nil
              }
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
  attr :current_time, DateTime

  def reminder_input(assigns) do
    ~H"""
    <input
      type="hidden"
      name="alert_data[reminder_sort][]"
      value={@index}
      id={"reminder_times-sort-#{@index}"}
    />
    <input
      type="hidden"
      name={"alert_data[reminder_times][#{@index}][min_time]"}
      value={@current_time}
      id={"reminder_times-#{@index}-min_time"}
    />
    <input
      type="hidden"
      name={"alert_data[reminder_times][#{@index}][max_time]"}
      value={@notification_end |> naive_datetime_to_iso8601()}
      id={"reminder_times-#{@index}-max_time"}
    />
    <input type="hidden" name={"alert_data[reminder_times][#{@index}][id]"} value={@id} />
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

  def parse_field_errors(%Ecto.Changeset{} = changeset) do
    changeset
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
