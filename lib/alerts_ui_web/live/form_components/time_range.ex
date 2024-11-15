defmodule AlertsUIWeb.FormComponents.TimeRange do
  @moduledoc """
    Live Component for active period of form
  """
  use AlertsUIWeb, :live_component
  use AlertsUI.Schema
  import Ecto.Changeset

  alias AlertsUI.Models.ActivePeriod
  alias AlertsUIWeb.FormComponents.Helpers.{ErrorFormatter, TimeRangeValidators}

  @alert_timing_values [
    :"one-time",
    :recurring,
    :scheduled
  ]

  @start_values [
    :now,
    :start_of_service,
    :custom
  ]

  @end_values [
    :later_today,
    :end_of_service,
    :until_further_notice,
    :custom
  ]

  @primary_key false
  embedded_schema do
    field :alert_timing, Ecto.Enum,
      values: @alert_timing_values,
      default: :"one-time"

    field :active_period_start, :naive_datetime
    field :active_period_start_date, :date
    field :active_period_start_time, :time
    field :active_period_start_specifier, Ecto.Enum, values: @start_values, default: :now
    field :active_period_end_specifier, Ecto.Enum, values: @end_values, default: :later_today
    field :active_period_start_time_specifier, Ecto.Enum, values: @start_values, default: :now

    field :active_period_end_time_specifier, Ecto.Enum,
      values: @end_values,
      default: :end_of_service

    field :active_period_end, :naive_datetime
    field :active_period_end_date, :date
    field :active_period_end_time, :time

    field :recurrence_days, {:array, Ecto.Enum},
      values: ~w[sunday monday tuesday wednesday thursday friday saturday]a

    field :notification_period_start, :naive_datetime
  end

  @fields ~w[active_period_end active_period_end_specifier alert_timing active_period_start_specifier notification_period_start active_period_start active_period_start_date active_period_end_date active_period_end_time active_period_start_time recurrence_days active_period_start_time_specifier active_period_end_time_specifier]a

  @impl true
  def mount(socket) do
    current_time = current_time()

    alert_data = %{
      notification_period_start: "",
      active_period_start: current_time,
      active_period_start_date: current_time |> NaiveDateTime.to_date(),
      active_period_start_time: ActivePeriod.start_of_service_time(),
      active_period_start_specifier: "now",
      active_period_end:
        ActivePeriod.end_of_service_datetime(current_time)
        |> DateTime.to_naive()
        |> naive_datetime_to_iso8601,
      active_period_end_time: ActivePeriod.end_of_service_time(),
      active_period_end_date:
        current_time
        |> ActivePeriod.end_of_service_datetime()
        |> shifted_active_period_end()
        |> NaiveDateTime.to_date()
    }

    changeset = changeset(%__MODULE__{}, alert_data)

    changes =
      changeset
      |> apply_action!(:validate)

    send(self(), {:section_completed, changes})

    form = changeset |> to_form

    socket =
      assign(socket, %{
        form: form,
        current_time: current_time,
        edited: false,
        day_of_week_options: [
          Monday: :monday,
          Tuesday: :tuesday,
          Wednesday: :wednesday,
          Thursday: :thursday,
          Friday: :friday,
          Saturday: :saturday,
          Sunday: :sunday
        ]
      })

    {:ok, socket}
  end

  @impl true
  def update(%{editing: editing, alert_data: alert_data} = assigns, socket) do
    assigns =
      if editing == true and socket.assigns.edited === false do
        alert_data =
          if Map.get(alert_data, :notification_period_start) in [nil, ""] do
            alert_data
          else
            Map.put(alert_data, :alert_timing, "scheduled")
          end
          |> Enum.filter(fn {_k, v} -> !is_nil(v) end)
          |> Map.new(fn {k, v} -> {Atom.to_string(k), v} end)

        changeset = changeset(%__MODULE__{}, Map.merge(socket.assigns.form.params, alert_data))

        changes =
          changeset
          |> apply_action!(:validate)

        send(self(), {:section_completed, changes})
        form = changeset |> to_form

        Map.merge(assigns, %{form: form, edited: true})
      else
        assigns
      end

    {:ok, assign(socket, assigns)}
  end

  @impl true
  def update(%{submitted: submitted}, socket) do
    socket =
      if submitted do
        current_time = current_time()

        form_params = socket.assigns.form.params

        updated_start =
          if form_params["active_period_start_specifier"] == "now" do
            current_time
          else
            form_params["active_period_start"]
          end

        form_params = Map.put(form_params, "active_period_start", updated_start)

        changeset =
          %__MODULE__{}
          |> changeset(form_params)
          |> TimeRangeValidators.validate_required_fields(form_params)
          |> TimeRangeValidators.validate_relationships(
            form_params["alert_timing"],
            form_params
          )
          |> TimeRangeValidators.validate_notification(form_params)
          |> TimeRangeValidators.validate_start_is_after_now(current_time)

        errors =
          case changeset |> apply_action(:validate) do
            {:ok, _changeset} -> []
            {:error, changeset} -> ErrorFormatter.parse_field_errors(changeset)
          end

        form =
          changeset
          |> to_form()
          |> Map.put(:action, :validate)
          |> Map.put(:errors, errors)

        assign(socket, form: form, current_time: current_time)
      else
        socket
      end

    {:ok, socket}
  end

  @impl true
  def handle_event(
        "validate",
        %{"time_range" => time_range},
        socket
      ) do
    form_params = socket.assigns.form.params
    current_time = socket.assigns.current_time

    time_range =
      case time_range["alert_timing"] do
        "one-time" ->
          start_datetime =
            set_start_datetime(
              time_range,
              current_time,
              form_params["active_period_start_specifier"]
            )

          end_datetime =
            set_end_datetime(
              time_range,
              current_time,
              form_params["active_period_end_specifier"]
            )

          Map.merge(time_range, %{
            "active_period_start" => start_datetime,
            "active_period_end" => end_datetime
          })

        "recurring" ->
          start_time =
            set_start_time(
              time_range,
              current_time,
              form_params["active_period_start_time_specifier"]
            )

          end_time =
            set_end_time(
              time_range,
              current_time,
              form_params["active_period_end_time_specifier"]
            )

          start_date =
            set_start_date(
              time_range,
              current_time,
              form_params["active_period_start_specifier"]
            )

          end_date =
            set_end_date(
              time_range,
              current_time,
              form_params["active_period_end_specifier"]
            )

          Map.merge(time_range, %{
            "active_period_start_time" => start_time,
            "active_period_end_time" => end_time,
            "active_period_start_date" => start_date,
            "active_period_end_date" => end_date
          })

        "scheduled" ->
          time_range
      end

    changeset =
      changeset(%__MODULE__{}, time_range)

    changeset =
      if changeset.valid? do
        changeset
        |> TimeRangeValidators.validate_relationships(
          time_range["alert_timing"],
          time_range
        )
        |> TimeRangeValidators.validate_start_is_after_now(socket.assigns.current_time)
        |> TimeRangeValidators.validate_notification(time_range)
        |> TimeRangeValidators.validate_required_fields(time_range)
      else
        changeset
      end

    changeset
    |> apply_action(:validate)
    |> case do
      {:ok, changes} ->
        send(self(), {:add_errors, [], __MODULE__})
        send(self(), {:section_completed, changes})

      {:error, changeset} ->
        send(self(), {:add_errors, ErrorFormatter.parse_field_errors(changeset), __MODULE__})
    end

    form =
      changeset
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, %{form: form})}
  end

  def handle_event("alert_timing_change", %{"time_range" => time_range}, socket) do
    time_range =
      if time_range["alert_timing"] !== "scheduled" do
        Map.put(time_range, "notification_period_start", "")
      else
        time_range
      end

    time_range = Map.merge(socket.assigns.form.params, time_range)

    changeset = changeset(%__MODULE__{}, time_range)

    changeset
    |> TimeRangeValidators.validate_required_fields(time_range)
    |> apply_action(:validate)
    |> case do
      {:ok, changes} ->
        send(self(), {:add_errors, [], __MODULE__})
        send(self(), {:section_completed, changes})

      {:error, changeset} ->
        send(self(), {:add_errors, ErrorFormatter.parse_field_errors(changeset), __MODULE__})
    end

    form =
      changeset
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, %{form: form})}
  end

  defp set_start_datetime(time_range, current_time, previous_state) do
    case time_range["active_period_start_specifier"] do
      "now" ->
        current_time |> naive_datetime_to_iso8601()

      "start_of_service" ->
        if time_range["active_period_start_date"] in [nil, ""] do
          current_time
        else
          time_range["active_period_start_date"]
          |> Date.from_iso8601!()
          |> NaiveDateTime.new!(ActivePeriod.start_of_service_time())
        end
        |> naive_datetime_to_iso8601()

      "custom" ->
        if previous_state !== "custom" do
          current_time |> naive_datetime_to_iso8601()
        else
          time_range["active_period_start"]
        end
    end
  end

  defp set_start_time(time_range, current_time, previous_state) do
    case time_range["active_period_start_time_specifier"] do
      "start_of_service" ->
        ActivePeriod.start_of_service_time()

      "custom" ->
        if previous_state !== "custom" do
          current_time |> NaiveDateTime.to_time() |> time_to_iso8601()
        else
          time_range["active_period_start_time"]
        end
    end
  end

  defp set_end_time(time_range, current_time, previous_state) do
    case time_range["active_period_end_time_specifier"] do
      "end_of_service" ->
        ActivePeriod.end_of_service_time()

      "custom" ->
        if previous_state !== "custom" do
          current_time |> NaiveDateTime.to_time() |> time_to_iso8601()
        else
          time_range["active_period_end_time"]
        end
    end
  end

  defp set_start_date(time_range, current_time, previous_state) do
    case time_range["active_period_start_specifier"] do
      "now" ->
        current_time |> NaiveDateTime.to_date()

      "custom" ->
        if previous_state !== "custom" do
          current_time |> NaiveDateTime.to_date()
        else
          time_range["active_period_start_date"]
        end
    end
  end

  defp set_end_date(time_range, current_time, previous_state) do
    case time_range["active_period_end_specifier"] do
      "custom" ->
        if previous_state !== "custom" do
          shifted_active_period_end(current_time)
          |> NaiveDateTime.to_date()
        else
          time_range["active_period_end_date"]
        end

      "until_further_notice" ->
        ""

      _ ->
        time_range["active_period_end_date"]
    end
  end

  defp set_end_datetime(time_range, current_time, previous_state) do
    case time_range["active_period_end_specifier"] do
      "later_today" ->
        current_time
        |> ActivePeriod.end_of_service_datetime()
        |> DateTime.to_naive()

      "end_of_service" ->
        if previous_state !== "end_of_service" do
          shifted_active_period_end(current_time)
          |> naive_datetime_to_iso8601()
        else
          time_range["active_period_end_date"]
          |> Date.from_iso8601!()
          |> NaiveDateTime.new!(ActivePeriod.end_of_service_time())
        end

      "until_further_notice" ->
        ""

      "custom" ->
        if previous_state !== "custom" do
          current_time |> naive_datetime_to_iso8601()
        else
          time_range["active_period_end"]
        end
    end
  end

  defp changeset(changeset, params) do
    custom_errors = [
      active_period_start: "Enter a valid datetime",
      active_period_end: "Enter a valid datetime",
      active_period_start_date: "Enter a valid date",
      active_period_end_date: "Enter a valid date",
      notification_period_start: "Enter a valid datetime"
    ]

    changeset
    |> cast(params, @fields, message: fn field, _meta -> custom_errors[field] end)
  end

  @impl true
  def render(assigns) do
    assigns =
      assign(assigns,
        start_values: @start_values,
        end_values: @end_values,
        alert_timing_values: @alert_timing_values
      )

    ~H"""
    <div
      class={unless @progress.name == "details", do: "hidden", else: "min-w-full flex flex-col mt-4"}
      id="time_range_view"
    >
      <.h5 class="text-text-secondary mb-8 w-full text-center md:text-left">
        Timeframe
      </.h5>
      <.form
        for={@form}
        phx-target={@myself}
        phx-change="validate"
        class="form-control gap-4"
        id="time_range_form"
      >
        <.select
          label="Alert timing"
          field={@form[:alert_timing]}
          options={values_to_options(@alert_timing_values)}
          class="min-w-[16rem] max-w-[16rem]"
          phx-debounce={120}
          phx-change="alert_timing_change"
          phx-target={@myself}
        />
        <%= one_time_alert_component(assigns) %>
        <%= recurring_alert_component(assigns) %>
        <div
          :if={@form[:alert_timing].value === :scheduled}
          id="scheduled-selector-div"
          class="flex flex-row gap-8 my-8"
        >
          <.datetime
            label="Schedule alert for date and time"
            field={@form[:notification_period_start]}
            min={@form[:active_period_start].value}
            max={@form[:active_period_end].value}
            value={@form[:notification_period_start].value}
            class="min-w-[16rem] h-10"
            phx-debounce={120}
          />
        </div>
      </.form>
      <hr class="mt-8" />
    </div>
    """
  end

  defp one_time_alert_component(assigns) do
    # add error to end specifier dropdown if there's no date picker to show it on
    assigns =
      update_in(assigns.form.errors, fn errors ->
        if Keyword.has_key?(errors, :active_period_end) and
             assigns.form.params["active_period_end_specifier"] == "later_today" do
          Keyword.put_new(errors, :active_period_end_specifier, errors[:active_period_end])
        else
          errors
        end
      end)

    ~H"""
    <div
      :if={@form[:alert_timing].value in [:"one-time", "one-time"]}
      class="flex flex-row gap-8 my-8"
    >
      <div id="start-selector-div" class="flex flex-row gap-8">
        <.select
          label="Effect start"
          field={@form[:active_period_start_specifier]}
          options={values_to_options(@start_values)}
          class="min-w-[16rem] max-w-[16rem]"
          phx-debounce={120}
        />
        <.datetime
          field={@form[:active_period_start]}
          min={naive_datetime_to_iso8601(@current_time)}
          value={naive_datetime_to_iso8601(@form[:active_period_start].value)}
          label="Start datetime"
          class={"min-w-[16rem] h-10 " <> (if @form[:active_period_start_specifier].value === :custom, do: "", else: "hidden")}
          phx-debounce={120}
        />
        <.datetime
          type="date"
          field={@form[:active_period_start_date]}
          min={next_start_of_service_date(@current_time)}
          max={@form[:active_period_end].value |> naive_datetime_to_iso_date}
          value={@form[:active_period_start_date].value}
          label="Start date"
          class={"min-w-[16rem] h-10 " <> (if @form[:active_period_start_specifier].value === :start_of_service, do: "", else: "hidden")}
          phx-debounce={120}
        />
      </div>

      <div id="end-selector-div" class="flex flex-row gap-8">
        <.select
          label="Effect end"
          field={@form[:active_period_end_specifier]}
          options={values_to_options(@end_values)}
          class="min-w-[16rem] max-w-[16rem]"
          phx-debounce={120}
        />
        <.datetime
          field={@form[:active_period_end]}
          min={naive_datetime_to_iso8601(@form[:active_period_start].value)}
          value={naive_datetime_to_iso8601(@form[:active_period_end].value)}
          label="End datetime"
          class={"min-w-[16rem] h-10 " <> (if @form[:active_period_end_specifier].value === :custom, do: "", else: "hidden")}
          phx-debounce={120}
        />
        <.datetime
          type="date"
          field={@form[:active_period_end_date]}
          min={@form[:active_period_start].value |> naive_datetime_to_iso_date}
          value={@form[:active_period_end_date].value}
          label="End date"
          class={"min-w-[16rem] h-10 " <> (if @form[:active_period_end_specifier].value === :end_of_service, do: "", else: "hidden")}
          phx-debounce={120}
        />
      </div>
    </div>
    <div :if={@form[:alert_timing].value in [:"one-time", "one-time"]} class="flex flex-col">
      <div>
        <%= "start datetime: " <> (@form[:active_period_start].value |> formatted_datetime) %>
      </div>
      <div>
        <%= "end datetime: " <>
          if is_nil(@form[:active_period_end].value) or is_binary(@form[:active_period_end].value) do
            "-"
          else
            @form[:active_period_end].value
            |> NaiveDateTime.add(
              if(@form[:active_period_end_specifier].value == :end_of_service, do: 1, else: 0),
              :day
            )
            |> formatted_datetime
          end %>
      </div>
    </div>
    """
  end

  defp recurring_alert_component(assigns) do
    ~H"""
    <div :if={@form[:alert_timing].value === :recurring} class="flex flex-col gap-8 my-8">
      <div class="flex flex-row gap-8 my-4">
        <div id="start-selector-div" class="flex flex-row gap-8">
          <.select
            label="Effect start"
            field={@form[:active_period_start_time_specifier]}
            options={values_to_options([:start_of_service, :custom])}
            class="min-w-[16rem] max-w-[16rem]"
            phx-debounce={120}
          />
          <.datetime
            label="Effect start time"
            type="time"
            field={@form[:active_period_start_time]}
            value={time_to_iso8601(@form[:active_period_start_time].value)}
            class={"min-w-[16rem] h-10 " <> (if @form[:active_period_start_time_specifier].value === :custom, do: "", else: "hidden")}
            phx-debounce={120}
          />
        </div>

        <div id="end-selector-div" class="flex flex-row gap-8">
          <.select
            label="Effect end"
            field={@form[:active_period_end_time_specifier]}
            options={values_to_options([:end_of_service, :custom])}
            class="min-w-[16rem] max-w-[16rem]"
            phx-debounce={120}
          />
          <.datetime
            label="Effect end time"
            type="time"
            field={@form[:active_period_end_time]}
            value={time_to_iso8601(@form[:active_period_end_time].value)}
            class={"min-w-[16rem] h-10 " <> (if @form[:active_period_end_time_specifier].value === :custom, do: "", else: "hidden")}
            phx-debounce={120}
          />
        </div>
      </div>

      <div class="flex flex-row gap-8 my-4">
        <div id="start-selector-div" class="flex flex-row gap-8">
          <.select
            label="Recurring alert start"
            field={@form[:active_period_start_specifier]}
            options={values_to_options([:now, :custom])}
            class="min-w-[16rem] max-w-[16rem]"
            phx-debounce={120}
          />
          <.datetime
            label="Start date"
            type="date"
            field={@form[:active_period_start_date]}
            value={@form[:active_period_start_date].value}
            class={"min-w-[16rem] h-10 " <> (if @form[:active_period_start_specifier].value === :custom, do: "", else: "hidden")}
            phx-debounce={120}
          />
        </div>

        <div id="end-selector-div" class="flex flex-row gap-8">
          <.select
            label="Recurring alert end"
            field={@form[:active_period_end_specifier]}
            options={[{"When alert is closed", :until_further_notice}, {"Custom", :custom}]}
            class="min-w-[16rem] max-w-[16rem]"
            phx-debounce={120}
          />
          <.datetime
            label="End date"
            type="date"
            field={@form[:active_period_end_date]}
            value={@form[:active_period_end_date].value}
            class={"min-w-[16rem] h-10 " <> (if @form[:active_period_end_specifier].value === :custom, do: "", else: "hidden")}
            phx-debounce={120}
          />
        </div>
      </div>
    </div>
    <.toggle_checkgroup
      :if={@form[:alert_timing].value === :recurring}
      field={@form[:recurrence_days]}
      options={@day_of_week_options}
      class="max-w-[50%]"
      button_class="justify-center"
      column={false}
      use_outline_buttons={true}
      show_icons={false}
    />
    <div :if={@form[:alert_timing].value === :recurring} class="flex flex-col">
      <div>
        start time: <%= time_to_iso8601(@form[:active_period_start_time].value) %>
      </div>
      <div>
        end time: <%= time_to_iso8601(@form[:active_period_end_time].value) %>
      </div>
      <div>
        <%= "start date: " <>
          (@form[:active_period_start_date].value |> formatted_datetime("{0M}/{0D}/{YYYY}")) %>
      </div>
      <div>
        <%= "end date: " <>
          if @form[:active_period_end_specifier].value == :custom and
               @form[:active_period_end_date].value not in ["", nil] do
            @form[:active_period_end_date].value
            |> Date.add(
              if(
                @form[:active_period_end_time_specifier].value in [:end_of_service, "end_of_service"],
                do: 1,
                else: 0
              )
            )
            |> formatted_datetime("{0M}/{0D}/{YYYY}")
          else
            "-"
          end %>
      </div>
    </div>
    """
  end

  defp current_time,
    do:
      DateTime.now!("America/New_York") |> DateTime.to_naive() |> NaiveDateTime.truncate(:second)

  defp next_start_of_service_date(current_time) do
    ActivePeriod.next_start_of_service_date(current_time)
    |> Date.to_iso8601()
  end

  def naive_datetime_to_iso_date(%NaiveDateTime{} = datetime),
    do: datetime |> NaiveDateTime.to_date() |> Date.to_iso8601()

  def naive_datetime_to_iso_date(_), do: ""

  defp naive_datetime_to_iso8601(%NaiveDateTime{} = datetime),
    do:
      datetime
      |> NaiveDateTime.truncate(:second)
      |> NaiveDateTime.to_iso8601()
      |> String.slice(0..-4//1)

  defp naive_datetime_to_iso8601(_), do: ""

  defp time_to_iso8601(%Time{} = time) do
    time
    |> Time.to_iso8601()
    |> String.slice(0..-4//1)
  end

  defp time_to_iso8601(_), do: ""

  defp values_to_options(values) do
    Enum.map(values, fn value ->
      name = value |> Atom.to_string() |> String.replace("_", " ") |> String.capitalize()
      {name, value}
    end)
  end

  defp formatted_datetime(datetime, format_string \\ "{0M}/{0D}/{YYYY}, {0h12}:{0m} {AM}")
  defp formatted_datetime(nil, _), do: ""

  defp formatted_datetime(datetime, format_string) do
    case Timex.format(datetime, format_string) do
      {:ok, formatted_time} -> formatted_time
      {:error, _} -> "invalid datetime"
    end
  end

  defp shifted_active_period_end(datetime) do
    datetime
    |> ActivePeriod.end_of_service_datetime()
    |> DateTime.add(-1, :day)
    |> DateTime.to_naive()
  end
end
