defmodule AlertsUIWeb.FormComponents.TimeRange do
  @moduledoc """
    Live Component for active period of form
  """
  use AlertsUIWeb, :live_component
  use AlertsUI.Schema
  import Ecto.Changeset

  alias AlertsUI.Models.ActivePeriod

  alias AlertsUIWeb.FormComponents.Helpers.{
    ErrorFormatter,
    RecurringDurationText,
    TimeRangeDurationText,
    TimeRangeValidators
  }

  @alert_timing_values [
    :"one-time",
    :recurring
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
  end

  @fields ~w[active_period_end active_period_end_specifier alert_timing active_period_start_specifier active_period_start active_period_start_date active_period_end_date active_period_end_time active_period_start_time recurrence_days active_period_start_time_specifier active_period_end_time_specifier]a

  @impl true
  def mount(socket) do
    current_time = current_time()

    alert_data = %{
      alert_timing: "one-time",
      active_period_start: current_time,
      active_period_start_date: current_time |> NaiveDateTime.to_date(),
      active_period_start_time: ActivePeriod.start_of_service_time(),
      active_period_start_specifier: "now",
      active_period_end_specifier: "later_today",
      recurrence_days: [],
      active_period_end:
        ActivePeriod.end_of_service_datetime_naive(current_time)
        |> naive_datetime_to_iso8601,
      active_period_end_time: ActivePeriod.end_of_service_time(),
      active_period_end_date:
        current_time
        |> ActivePeriod.end_of_service_datetime_naive()
        |> shifted_active_period_end()
        |> NaiveDateTime.to_date(),
      active_period_start_time_specifier: "start_of_service",
      active_period_end_time_specifier: "end_of_service",
      edited: false
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
  def update(
        %{alert_data: alert_data, editing: true} =
          assigns,
        %{assigns: %{edited: false}} = socket
      ) do
    alert_data =
      alert_data
      |> Enum.filter(fn {_k, v} -> !is_nil(v) end)
      |> Map.new(fn {k, v} -> {Atom.to_string(k), v} end)

    assigns =
      assigns
      |> Map.put(:alert_data, Map.merge(socket.assigns.form.params, alert_data))

    changeset =
      %__MODULE__{}
      |> changeset(assigns.alert_data)
      |> TimeRangeValidators.validate_required_fields(assigns.alert_data)
      |> TimeRangeValidators.validate_relationships(
        assigns.alert_data["alert_timing"],
        assigns.alert_data
      )

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
      |> to_form()
      |> Map.put(:action, :validate)

    assigns = assigns |> Map.merge(%{form: form, edited: true})

    {:ok, assign(socket, assigns)}
  end

  @impl true
  def update(
        %{selected_trips: []} = assigns,
        socket
      ) do
    new_params = %{
      "active_period_start" => socket.assigns.current_time,
      "active_period_start_specifier" => "now",
      "active_period_end" =>
        socket.assigns.current_time |> ActivePeriod.end_of_service_datetime_naive(),
      "active_period_end_specifier" => "later_today"
    }

    form_params = Map.merge(socket.assigns.form.params, new_params)

    form =
      %__MODULE__{}
      |> changeset(form_params)
      |> to_form()
      |> Map.put(:action, :validate)

    assigns = assigns |> Map.put(:form, form)
    {:ok, assign(socket, assigns)}
  end

  @impl true
  def update(
        %{selected_trips: selected_trips} = assigns,
        socket
      )
      when not is_nil(selected_trips) do
    trip_departure_time = get_trip_departure_time(selected_trips)
    trip_arrival_time = get_trip_arrival_time(selected_trips)

    form_params =
      if trip_departure_time && trip_arrival_time do
        start_params =
          if NaiveDateTime.compare(trip_departure_time, socket.assigns.current_time) == :gt do
            %{
              "active_period_start" => trip_departure_time,
              "active_period_start_specifier" => "custom"
            }
          else
            %{
              "active_period_start" => socket.assigns.current_time,
              "active_period_start_specifier" => "now"
            }
          end

        end_params = %{
          "active_period_end" => NaiveDateTime.add(trip_arrival_time, 1, :hour),
          "active_period_end_specifier" => "custom"
        }

        new_params = Map.merge(start_params, end_params)

        Map.merge(socket.assigns.form.params, new_params)
      else
        socket.assigns.form.params
      end

    form =
      %__MODULE__{}
      |> changeset(form_params)
      |> to_form()
      |> Map.put(:action, :validate)

    assigns = assigns |> Map.put(:trip_arrival_time, trip_arrival_time) |> Map.put(:form, form)
    {:ok, assign(socket, assigns)}
  end

  @impl true
  def update(%{submitted: true}, socket) do
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
      |> TimeRangeValidators.validate_start_is_before_trip(
        Map.get(socket.assigns, :trip_arrival_time)
      )

    changeset =
      if socket.assigns.editing do
        changeset
      else
        TimeRangeValidators.validate_start_is_after_now(
          changeset,
          current_time,
          form_params
        )
      end

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

    form_params = Map.put(form_params, "active_period_start", updated_start)

    changeset =
      %__MODULE__{}
      |> changeset(form_params)
      |> TimeRangeValidators.validate_required_fields(form_params)
      |> TimeRangeValidators.validate_relationships(
        form_params["alert_timing"],
        form_params
      )
      |> TimeRangeValidators.validate_start_is_before_trip(
        Map.get(socket.assigns, :trip_arrival_time)
      )
      |> TimeRangeValidators.validate_start_is_after_now(
        current_time,
        form_params
      )

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

    socket = assign(socket, form: form, current_time: current_time)

    {:ok, socket}
  end

  @impl true
  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  defp get_trip_departure_time(selected_trips) do
    selected_trips
    |> Enum.map(& &1.departure_time)
    |> Enum.min(DateTime, fn -> nil end)
    |> utc_datetime_to_naive()
  end

  defp get_trip_arrival_time(selected_trips) do
    selected_trips
    |> Enum.map(& &1.arrival_time)
    |> Enum.max(DateTime, fn -> nil end)
    |> utc_datetime_to_naive()
  end

  @impl true
  def handle_event(
        "validate",
        %{"time_range" => time_range},
        socket
      ) do
    form_params = socket.assigns.form.params

    time_range = Map.put_new(time_range, "recurrence_days", [])
    time_range = Map.merge(socket.assigns.form.params, time_range)

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
        |> TimeRangeValidators.validate_start_is_after_now(
          socket.assigns.current_time,
          time_range
        )
        |> TimeRangeValidators.validate_start_is_before_trip(
          Map.get(socket.assigns, :trip_arrival_time)
        )
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

  defp set_start_datetime(time_range, current_time, previous_state) do
    case time_range["active_period_start_specifier"] do
      "now" ->
        current_time |> naive_datetime_to_iso8601()

      "start_of_service" ->
        {validity, date} = Date.from_iso8601(time_range["active_period_start_date"])

        if validity === :ok do
          NaiveDateTime.new!(date, ActivePeriod.start_of_service_time())
        else
          current_time
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
      :start_of_service ->
        ActivePeriod.start_of_service_time()

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
      :end_of_service ->
        ActivePeriod.end_of_service_time()

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

      _ ->
        time_range["active_period_start_date"]
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
        |> ActivePeriod.end_of_service_datetime_naive()

      "end_of_service" ->
        cond do
          previous_state !== "end_of_service" ->
            shifted_active_period_end(current_time) |> naive_datetime_to_iso8601()

          time_range["active_period_end_date"] in ["", nil] ->
            ""

          true ->
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
      active_period_end_date: "Enter a valid date"
    ]

    changeset
    |> cast(params, @fields, message: fn field, _meta -> custom_errors[field] end)
  end

  @impl true
  def render(assigns) do
    one_time_duration_text = TimeRangeDurationText.one_time_duration_text(assigns.form.params)

    assigns =
      assign(assigns,
        start_values: @start_values,
        end_values: @end_values,
        alert_timing_values: @alert_timing_values,
        one_time_duration_text: one_time_duration_text
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
        />
        {one_time_alert_component(assigns)}
        <div
          :if={@form[:alert_timing].value in [:"one-time", "one-time"] and Enum.empty?(@form.errors)}
          class="text-text-secondary"
        >
          Effect duration: {@one_time_duration_text}
        </div>
        {recurring_alert_component(assigns)}
        <div
          :if={
            @form[:alert_timing].value in [:recurring, "recurring"] and Enum.empty?(@form.errors) and
              @form[:recurrence_days].value not in [[], nil]
          }
          class="text-text-secondary"
        >
          Effect duration: {RecurringDurationText.recurring_duration_text(assigns)}
        </div>
      </.form>
    </div>
    """
  end

  defp one_time_alert_component(assigns) do
    ~H"""
    <div
      :if={@form[:alert_timing].value in [:"one-time", "one-time"]}
      class="flex flex-row gap-8 mt-8"
    >
      <.select
        label="Effect period"
        field={@form[:active_period_start_specifier]}
        options={values_to_options(@start_values)}
        class="min-w-[16rem] max-w-[16rem]"
        phx-debounce={120}
      />
      <.datetime
        field={@form[:active_period_start]}
        min={naive_datetime_to_iso8601(@current_time)}
        max="9999-12-31T23:59"
        value={naive_datetime_to_iso8601(@form[:active_period_start].value)}
        class={"min-w-[16rem] max-w-[16rem] " <> (if @form[:active_period_start_specifier].value === :custom, do: "", else: "hidden")}
        phx-debounce={120}
      />
      <.datetime
        type="date"
        field={@form[:active_period_start_date]}
        min={next_start_of_service_date(@current_time)}
        max={
          [naive_datetime_to_iso_date(@form[:active_period_end].value), "9999-12-31"] |> Enum.max()
        }
        value={@form[:active_period_start_date].value}
        class={"min-w-[16rem] max-w-[16rem] " <> (if @form[:active_period_start_specifier].value === :start_of_service, do: "", else: "hidden")}
        phx-debounce={120}
      />
      <p class="pt-[2.5rem]">to</p>
      <.select
        field={@form[:active_period_end_specifier]}
        options={values_to_options(@end_values)}
        class="min-w-[16rem] max-w-[16rem]"
        select_class="mt-[28.8px]"
        phx-debounce={120}
      />
      <.datetime
        type="date"
        field={@form[:active_period_end_date]}
        min={@form[:active_period_start].value |> naive_datetime_to_iso_date}
        max="9999-12-31"
        value={@form[:active_period_end_date].value}
        class={"min-w-[16rem] max-w-[16rem] " <> (if @form[:active_period_end_specifier].value === :end_of_service, do: "", else: "hidden")}
        phx-debounce={120}
      />
      <.datetime
        field={@form[:active_period_end]}
        min={naive_datetime_to_iso8601(@form[:active_period_start].value)}
        max="9999-12-31T23:59"
        value={naive_datetime_to_iso8601(@form[:active_period_end].value)}
        class={"min-w-[16rem] max-w-[16rem] " <> (if @form[:active_period_end_specifier].value === :custom, do: "", else: "hidden")}
        phx-debounce={120}
      />
    </div>
    """
  end

  defp recurring_alert_component(assigns) do
    ~H"""
    <div :if={@form[:alert_timing].value === :recurring} class="flex flex-col gap-8 my-8">
      <div class="flex flex-row gap-8 my-4">
        <div class="flex flex-row gap-8">
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
            class={"min-w-[16rem] max-w-[16rem] h-10 " <> (if @form[:active_period_start_time_specifier].value === :custom, do: "", else: "hidden")}
            phx-debounce={120}
          />
        </div>
        <p class="pt-[2rem]">to</p>
        <div class="flex flex-row gap-8">
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
            class={"min-w-[16rem] max-w-[16rem] h-10 " <> (if @form[:active_period_end_time_specifier].value === :custom, do: "", else: "hidden")}
            phx-debounce={120}
          />
        </div>
      </div>

      <div class="flex flex-row gap-8 my-4">
        <div class="flex flex-row gap-8">
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
            max="9999-12-31"
            field={@form[:active_period_start_date]}
            value={@form[:active_period_start_date].value}
            class={"min-w-[16rem] max-w-[16rem] h-10 " <> (if @form[:active_period_start_specifier].value === :custom, do: "", else: "hidden")}
            phx-debounce={120}
          />
        </div>
        <p class="pt-[2rem]">to</p>
        <div class="flex flex-row gap-8">
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
            max="9999-12-31"
            field={@form[:active_period_end_date]}
            value={@form[:active_period_end_date].value}
            class={"min-w-[16rem] max-w-[16rem] h-10 " <> (if @form[:active_period_end_specifier].value === :custom, do: "", else: "hidden")}
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

  defp shifted_active_period_end(datetime) do
    datetime
    |> ActivePeriod.end_of_service_datetime_naive()
    |> NaiveDateTime.add(-1, :day)
  end

  defp utc_datetime_to_naive(nil), do: nil
  defp utc_datetime_to_naive(datetime), do: DateTime.to_naive(datetime)
end
