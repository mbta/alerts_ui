defmodule AlertsUIWeb.FormComponents.RiderReminders do
  @moduledoc """
    Live Component for Rider Reminders section of form
  """
  use AlertsUIWeb, :live_component
  use AlertsUI.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    embeds_many :reminder_times, ReminderTimes, on_replace: :delete do
      field :reminder_time, :naive_datetime
      field :min_time, :naive_datetime
      field :max_time, :naive_datetime
    end
  end

  @reminder_time_fields ~w[reminder_time min_time max_time]a

  @impl true
  def mount(socket) do
    current_time = current_time()
    form = %__MODULE__{} |> changeset(%{}) |> to_form()

    {:ok,
     assign(socket,
       form: form,
       current_time: current_time,
       edited: false,
       notification_start: "",
       effect_end: ""
     )}
  end

  @impl true

  def update(%{alert_data: alert_data} = assigns, socket) do
    notification_start =
      cond do
        Map.get(alert_data, :notification_period_start) -> alert_data.notification_period_start
        Map.get(alert_data, :active_period_start) -> alert_data.active_period_start
        true -> nil
      end

    effect_end =
      cond do
        Map.get(alert_data, :active_period_end) in ["", nil] ->
          ~N[9999-12-31 23:59:59]

        Map.get(alert_data, :active_period_end_specifier) in [:end_of_service, "end_of_service"] ->
          NaiveDateTime.add(alert_data.active_period_end, 1, :day)

        true ->
          alert_data.active_period_end
      end

    processed_reminder_times =
      (Map.get(alert_data, :reminder_times, []) || [])
      |> Enum.with_index(fn element, index -> {element, Integer.to_string(index)} end)
      |> Enum.reduce(%{}, fn {element, index}, acc ->
        Map.put(acc, index, %{
          "_persistent_id" => index,
          "reminder_time" => NaiveDateTime.to_iso8601(element),
          "min_time" => notification_start |> naive_datetime_to_iso8601(),
          "max_time" => effect_end |> naive_datetime_to_iso8601()
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
      |> Map.put(:effect_end, effect_end)

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

  def reminder_changeset(reminder_time, params, _cardinality) do
    cast(reminder_time, params, @reminder_time_fields)
    |> validate_required(:reminder_time, message: "Enter a valid date and time")
    |> validate_change(:reminder_time, fn :reminder_time, reminder_time ->
      {status, min_time} =
        params["min_time"] |> String.pad_trailing(19, ":00") |> NaiveDateTime.from_iso8601()

      if status == :ok and NaiveDateTime.diff(min_time, reminder_time, :minute) > 1 do
        [
          reminder_time:
            "Reminder time must be after notifications start #{min_time |> formatted_datetime}"
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
            "Reminder time must be before the end of the effect period #{max_time |> formatted_datetime}"
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
          |> Enum.map(& &1.reminder_time)

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
    active_period_end = Map.get(assigns.alert_data, :active_period_end)
    assigns = Map.put(assigns, :active_period_end, naive_datetime_to_iso8601(active_period_end))

    ~H"""
    <div class="min-w-full flex flex-col mt-8" id="rider_reminder_view">
      <.h5 class="text-text-secondary mb-8 w-full text-center md:text-left">
        Rider Reminders
      </.h5>
      <.form
        for={@form}
        phx-target={@myself}
        phx-change="validate"
        class="form-control gap-12 flex flex-col-reverse"
        id="rider_reminder_form"
      >
        <div>
          <.inputs_for :let={rt} field={@form[:reminder_times]}>
            <div class="flex flex-row w-[50%] mb-4" id={"reminder-time-component-#{rt.index}"}>
              <input type="hidden" name="rider_reminders[reminder_sort][]" value={rt.index} />
              <.datetime
                label="Reminder date and time"
                min={@notification_start |> naive_datetime_to_iso8601()}
                max={@effect_end |> naive_datetime_to_iso8601()}
                field={rt[:reminder_time]}
                value={rt[:reminder_time].value}
              />
              <input
                type="hidden"
                name={"rider_reminders[reminder_times][#{rt.index}][min_time]"}
                value={@current_time}
              />
              <input
                type="hidden"
                name={"rider_reminders[reminder_times][#{rt.index}][max_time]"}
                value={@active_period_end}
              />
              <button
                class="ml-2"
                type="button"
                name="rider_reminders[reminder_drop][]"
                value={rt.index}
                phx-click={JS.dispatch("change")}
              >
                <.icon name="hero-x-mark" class="w-6 h-6 relative top-2" />
              </button>
            </div>
          </.inputs_for>

          <input type="hidden" name="rider _reminders[reminder_drop][]" />
        </div>
        <.button_secondary
          class="w-32"
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

  defp current_time,
    do:
      DateTime.now!("America/New_York") |> DateTime.to_naive() |> NaiveDateTime.truncate(:second)

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
