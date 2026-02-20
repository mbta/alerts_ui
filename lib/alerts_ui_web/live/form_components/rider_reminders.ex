defmodule AlertsUIWeb.FormComponents.RiderReminders do
  @moduledoc """
    Live Component for Rider Reminders section of form
  """
  use AlertsUIWeb, :live_component
  use AlertsUI.Schema
  import Ecto.Changeset

  alias AlertsUI.Helpers.ReminderTimes
  alias AlertsUIWeb.FormComponents.Helpers.DateTimeHelpers
  alias Phoenix.HTML.FormField

  @primary_key false
  embedded_schema do
    embeds_many :reminder_times, ReminderTimes, on_replace: :delete do
      field :reminder_time, :naive_datetime
      field :min_time, :naive_datetime
      field :max_time, :naive_datetime
    end
  end

  @reminder_time_fields ~w[id reminder_time min_time max_time]a

  @impl true
  def mount(socket) do
    current_time = DateTimeHelpers.current_time()
    form = %__MODULE__{} |> changeset(%{}) |> to_form()

    {:ok,
     assign(socket,
       form: form,
       current_time: current_time,
       edited: false,
       notification_start: "",
       notification_end: ""
     )}
  end

  @impl true

  def update(%{alert_data: alert_data} = assigns, socket) do
    notification_start =
      cond do
        Map.get(alert_data, :notification_specifier) == :now -> DateTime.now!("America/New_York")
        Map.get(alert_data, :notification_period_start) -> alert_data.notification_period_start
        Map.get(alert_data, :active_period_start) -> alert_data.active_period_start
        true -> nil
      end

    notification_end = calculate_notification_end(alert_data)

    processed_reminder_times =
      (Map.get(alert_data, :reminder_times, []) || [])
      |> Enum.with_index(fn element, index -> {element, Integer.to_string(index)} end)
      |> Enum.reduce(%{}, fn {%{id: id, time: time}, index}, acc ->
        Map.put(acc, index, %{
          "_persistent_id" => index,
          "id" => id,
          "reminder_time" => time && NaiveDateTime.to_iso8601(time),
          "min_time" => notification_start |> naive_datetime_to_iso8601(),
          "max_time" => notification_end |> naive_datetime_to_iso8601()
        })
      end)

    changeset =
      changeset(%__MODULE__{}, %{
        "reminder_times" => processed_reminder_times
      })

    validate(changeset)

    form =
      changeset
      |> Map.put(:action, :validate)
      |> to_form()

    assigns =
      assigns
      |> Map.merge(%{form: form, edited: true})
      |> Map.put(:notification_start, notification_start)
      |> Map.put(:notification_end, notification_end)

    {:ok, assign(socket, assigns)}
  end

  def changeset(changeset, params) do
    changeset
    |> cast(params, [])
    |> cast_embed(:reminder_times,
      sort_param: :reminder_sort,
      drop_param: :reminder_drop,
      with: &reminder_changeset/3
    )
  end

  defp calculate_notification_end(%{} = alert_data) do
    unbounded = Map.get(alert_data, :active_period_end_specifier) == :until_further_notice
    unspecified_notification_end = Map.get(alert_data, :notification_period_end) in ["", nil]
    unspecified_active_end = Map.get(alert_data, :active_period_end) in ["", nil]
    forever = ~N[9999-12-31 23:59:59]

    cond do
      unbounded -> forever
      unspecified_notification_end && unspecified_active_end -> forever
      unspecified_notification_end -> Map.get(alert_data, :active_period_end)
      true -> alert_data.notification_period_end
    end
  end

  def reminder_changeset(reminder_time, params, _cardinality) do
    existing_record = String.trim(params["id"] || "") != ""

    cast(reminder_time, params, @reminder_time_fields)
    |> validate_required(:reminder_time, message: "Select reminder time")
    |> validate_change(:reminder_time, fn :reminder_time, reminder_time ->
      {status, min_time} =
        params["min_time"] |> String.pad_trailing(19, ":00") |> NaiveDateTime.from_iso8601()

      if status == :ok and NaiveDateTime.diff(min_time, reminder_time, :minute) > 1 and
           not existing_record do
        [
          reminder_time:
            "Reminder time must be after notification period starts (#{min_time |> formatted_datetime})"
        ]
      else
        []
      end
    end)
    |> validate_change(:reminder_time, fn :reminder_time, reminder_time ->
      {result, max_time} =
        params["max_time"] |> String.pad_trailing(19, ":00") |> NaiveDateTime.from_iso8601()

      if result == :ok and NaiveDateTime.compare(max_time, reminder_time) === :lt do
        [
          reminder_time:
            "Reminder time must be before notification period ends (#{max_time |> formatted_datetime})"
        ]
      else
        []
      end
    end)
  end

  def validate(changeset) do
    case changeset
         |> apply_action(:validate) do
      {:ok, changes} ->
        clean_reminder_times =
          changes.reminder_times
          |> Enum.map(&%{id: &1.id, time: &1.reminder_time})

        changes =
          changes
          |> Map.put(:reminder_times, clean_reminder_times)

        send(self(), {:add_errors, [], __MODULE__})
        send(self(), {:section_completed, changes})

      {:error, changeset} ->
        send(self(), {:add_errors, parse_field_errors(changeset), __MODULE__})
    end
  end

  @impl true
  def handle_event("validate", %{"rider_reminders" => rider_reminders}, socket) do
    changeset = changeset(%__MODULE__{}, rider_reminders)

    validate(changeset)

    form =
      changeset
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, %{form: form})}
  end

  @impl true
  def handle_event("validate", _, socket) do
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-w-full flex flex-col mt-8" id="rider_reminder_view">
      <.h5 class="text-text-secondary mb-8 w-full text-center md:text-left">
        Rider Reminders
      </.h5>
      <.form
        for={@form}
        phx-target={@myself}
        phx-change="validate"
        class="form-control flex flex-col"
        id="rider_reminder_form"
      >
        <div>
          <.inputs_for :let={rt} field={@form[:reminder_times]}>
            <div class="flex flex-row mb-4" id={"reminder-time-component-#{rt.index}"}>
              <.reminder_input
                editable={ReminderTimes.editable?(rt[:id].value, rt[:reminder_time].value)}
                current_time={@current_time}
                field={rt[:reminder_time]}
                id={rt[:id].value}
                index={rt.index}
                notification_start={@notification_start}
                notification_end={@notification_end}
              />
            </div>
          </.inputs_for>
          <input type="hidden" name="rider _reminders[reminder_drop][]" />
        </div>
        <.button_secondary
          class="self-start mb-4"
          type="button"
          name="rider_reminders[reminder_sort][]"
          value="new"
          phx-click={JS.dispatch("change")}
        >
          Add reminder
        </.button_secondary>
      </.form>
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
    <input type="hidden" name="rider_reminders[reminder_sort][]" value={@index} />
    <input
      type="hidden"
      name={"rider_reminders[reminder_times][#{@index}][min_time]"}
      value={@current_time}
    />
    <input
      type="hidden"
      name={"rider_reminders[reminder_times][#{@index}][max_time]"}
      value={@notification_end |> naive_datetime_to_iso8601()}
    />
    <input type="hidden" name={"rider_reminders[reminder_times][#{@index}][id]"} value={@id} />
    <input
      :if={!@editable}
      type="hidden"
      name={"rider_reminders[reminder_times][#{@index}][reminder_time]"}
      value={@field.value}
    />
    <.datetime
      label="Reminder date and time"
      min={@notification_start |> naive_datetime_to_iso8601()}
      max={@notification_end |> naive_datetime_to_iso8601()}
      field={@field}
      value={@field.value}
      disabled={!@editable}
    >
      <button
        :if={@editable}
        class="flex max-h-[3.2rem] items-center"
        type="button"
        name="rider_reminders[reminder_drop][]"
        value={@index}
        phx-click={JS.dispatch("change")}
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
    traverse_errors(changeset, fn _changeset, _field, {msg, _opts} -> msg end)
    |> Enum.map(&traverse_inner_errors/1)
  end

  defp traverse_inner_errors({key, value}) do
    new_value =
      value
      |> Enum.uniq()
      |> Enum.reduce([], fn reminder_map, acc ->
        if is_list(Map.get(reminder_map, :reminder_time)) do
          [hd(reminder_map.reminder_time) | acc]
        else
          acc
        end
      end)
      |> List.flatten()
      |> Enum.join(";")

    {key, {new_value, []}}
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
