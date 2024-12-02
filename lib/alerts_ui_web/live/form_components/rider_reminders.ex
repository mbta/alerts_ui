defmodule AlertsUIWeb.FormComponents.RiderReminders do
  @moduledoc """
    Live Component for Rider Reminders section of form
  """
  use AlertsUIWeb, :live_component
  use AlertsUI.Schema
  import Ecto.Changeset

  @reminder_time_specifiers [:select, :now, :custom]

  @primary_key false
  embedded_schema do
    embeds_many :reminder_times, ReminderTimes, on_replace: :delete do
      field :reminder_time_specifier, Ecto.Enum,
        values: [:select, :now, :custom],
        default: :select

      field :reminder_time, :naive_datetime
      field :min_time, :naive_datetime
      field :max_time, :naive_datetime
    end
  end

  @reminder_time_fields ~w[reminder_time_specifier reminder_time min_time max_time]a

  @impl true
  def mount(socket) do
    current_time = current_time()
    form = %__MODULE__{} |> changeset(%{}) |> to_form()

    {:ok,
     assign(socket,
       form: form,
       current_time: current_time,
       reminder_time_specifiers: @reminder_time_specifiers,
       edited: false
     )}
  end

  @impl true
  @spec update(%{:alert_data => any(), :editing => boolean(), optional(any()) => any()}, any()) ::
          {:ok, any()}
  def update(%{editing: editing, alert_data: alert_data} = assigns, socket) do
    assigns =
      if editing and not socket.assigns.edited and not is_nil(alert_data.reminder_times) do
        processed_reminder_times =
          alert_data.reminder_times
          |> Enum.with_index(fn element, index -> {element, Integer.to_string(index)} end)
          |> Enum.reduce(%{}, fn {element, index}, acc ->
            Map.put(acc, index, %{
              "_persistent_id" => index,
              "reminder_time" => NaiveDateTime.to_iso8601(element),
              "min_time" => socket.assigns.current_time |> naive_datetime_to_iso8601(),
              "max_time" =>
                Map.get(alert_data, :active_period_end) |> naive_datetime_to_iso8601(),
              "reminder_time_specifier" => "custom"
            })
          end)

        changeset =
          changeset(%__MODULE__{}, %{
            "reminder_times" => processed_reminder_times
          })

        form = changeset |> to_form
        Map.merge(assigns, %{form: form, edited: true})
      else
        assigns
      end

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
    new_reminder_time =
      case Map.get(params, "reminder_time_specifier") do
        "now" -> params["min_time"]
        "custom" -> Map.get(params, "reminder_time", "")
        _ -> nil
      end

    params = Map.put(params, "reminder_time", new_reminder_time)

    cast(reminder_time, params, @reminder_time_fields)
    |> validate_required(:reminder_time, message: "Enter a valid reminder datetime")
    |> validate_change(:reminder_time, fn :reminder_time, reminder_time ->
      min_time =
        params["min_time"] |> String.pad_trailing(19, ":00") |> NaiveDateTime.from_iso8601!()

      if NaiveDateTime.diff(min_time, reminder_time, :minute) > 1 do
        [reminder_time: "Reminder can't be set in the past"]
      else
        []
      end
    end)
    |> validate_change(:reminder_time, fn :reminder_time, reminder_time ->
      {result, max_time} =
        params["max_time"] |> String.pad_trailing(19, ":00") |> NaiveDateTime.from_iso8601()

      if result == :ok and NaiveDateTime.compare(max_time, reminder_time) === :lt do
        [reminder_time: "Reminder must be before effect end"]
      else
        []
      end
    end)
  end

  @impl true
  def handle_event("validate", %{"rider_reminders" => rider_reminders}, socket) do
    changeset = changeset(%__MODULE__{}, rider_reminders)

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

    form =
      changeset
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, %{form: form})}
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
              <.select
                label="Scheduled reminder"
                field={rt[:reminder_time_specifier]}
                options={values_to_options(@reminder_time_specifiers)}
                class="min-w-[16rem] max-w-[16rem] mr-8"
                phx-debounce={120}
              />
              <.datetime
                label="Reminder date and time"
                min={@current_time |> naive_datetime_to_iso8601()}
                max={@active_period_end}
                field={rt[:reminder_time]}
                value={rt[:reminder_time].value}
                class={
                  if rt[:reminder_time_specifier].value in [:custom, "custom"], do: "", else: "hidden"
                }
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

  defp naive_datetime_to_iso8601(datetime) do
    datetime
    |> NaiveDateTime.truncate(:second)
    |> NaiveDateTime.to_iso8601()
    |> String.slice(0..-4//1)
  end

  defp values_to_options(values) do
    Enum.map(values, fn value ->
      name = value |> Atom.to_string() |> String.replace("_", " ") |> String.capitalize()
      {name, value}
    end)
  end
end
