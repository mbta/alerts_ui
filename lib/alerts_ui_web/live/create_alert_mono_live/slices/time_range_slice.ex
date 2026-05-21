defmodule AlertsUIWeb.CreateAlertMonoLive.Slices.TimeRangeSlice do
  alias AlertsUI.Models.ActivePeriod

  alias AlertsUIWeb.CreateAlertMonoLive.Helpers.Time, as: DTHelpers
  alias AlertsUIWeb.CreateAlertMonoLive.Slice

  alias AlertsUIWeb.FormComponents.Helpers.{
    DateTimeHelpers,
    TimeRangeDurationText,
    RecurringDurationText
  }

  alias Phoenix.HTML.Form

  import Ecto.Changeset

  import AlertsUIWeb.CreateAlertMonoLive.Helpers.AlertData,
    only: [put_over_nil: 3, values_to_options: 1]

  use AlertsUIWeb, :html

  defstruct [
    :active_period_start,
    :active_period_start_time_specifier,
    :active_period_start_date,
    :active_period_start_time,
    :active_period_end,
    :active_period_end_time_specifier,
    :active_period_end_date,
    :active_period_end_time,
    :recurrence_days,
    :can_close_automatically,
    active_period_start_specifier: :now,
    active_period_end_specifier: :later_today,
    alert_timing: "one-time"
  ]

  defimpl Slice, for: __MODULE__ do
    alias AlertsUIWeb.CreateAlertMonoLive.AlertData
    alias AlertsUIWeb.CreateAlertMonoLive.Helpers.TimeRangeValidators
    alias AlertsUIWeb.CreateAlertMonoLive.Slices.TimeRangeSlice

    def mount(_slice, socket, _params) do
      socket
    end

    def extract(slice, %AlertData{} = _alert, _params) do
      now = NaiveDateTime.local_now()

      slice
      # |> Map.from_struct()
      |> put_over_nil(:alert_timing, "one-time")
      |> put_over_nil(:active_period_start_specifier, :now_and_again)
      |> put_over_nil(:active_period_start, now)
      |> put_over_nil(:active_period_start_date, NaiveDateTime.to_date(now))
      |> put_over_nil(:active_period_start_time, NaiveDateTime.to_time(now))
      |> put_over_nil(:active_period_end_specifier, :later_today)
      |> put_over_nil(:active_period_end, now)
      |> put_over_nil(:active_period_end_date, NaiveDateTime.to_date(now))
      |> put_over_nil(:active_period_end_time, NaiveDateTime.to_time(now))
      |> put_over_nil(:can_close_automatically, nil)
    end

    def transform(_slice, changeset, _params, _socket) do
      changeset
      |> TimeRangeSlice.normalize_alert_timing()
      |> TimeRangeSlice.ensure_start_date_values()
      |> TimeRangeSlice.ensure_end_date_values()
    end

    def validate(_slice, changeset, _params, _socket) do
      changeset
      |> TimeRangeValidators.validate_required_fields()
      |> TimeRangeValidators.validate_end_after_start()
      |> TimeRangeValidators.validate_start_is_after_now()
      |> TimeRangeValidators.validate_at_least_one_recurrence()
      |> TimeRangeValidators.validate_recurs_on_today()
      |> TimeRangeValidators.validate_not_dst_gap()
    end

    def assigns(_slice, socket, _params) do
      socket
    end
  end

  def ensure_start_date_values(changeset) do
    specifier = get_field(changeset, :active_period_start_specifier)
    start_dt = get_field(changeset, :active_period_start, :unspecified)
    start_d = get_field(changeset, :active_period_start_date, :unspecified)
    ensure_start_date_values_for_specifier(changeset, specifier, start_dt, start_d)
  end

  def ensure_start_date_values_for_specifier(changeset, _, dt, d) when is_nil(dt) or is_nil(d) do
    change(changeset, %{
      active_period_start: nil,
      active_period_start_date: nil
    })
  end

  def ensure_start_date_values_for_specifier(changeset, :now, _, _) do
    now = NaiveDateTime.local_now()

    change(changeset, %{
      active_period_start: now,
      active_period_start_date: now |> NaiveDateTime.to_date()
    })
  end

  def ensure_start_date_values_for_specifier(changeset, :start_of_service, _, d) do
    change(changeset, %{
      active_period_start: NaiveDateTime.new!(d, ~T[03:00:00])
    })
  end

  def ensure_start_date_values_for_specifier(changeset, :custom, dt, _) do
    change(changeset, %{
      active_period_start_date: NaiveDateTime.to_date(dt)
    })
  end

  def ensure_start_date_values_for_specifier(changeset, _, _, _), do: changeset

  def ensure_end_date_values(changeset) do
    specifier = get_field(changeset, :active_period_end_specifier)
    end_dt = get_field(changeset, :active_period_end)
    end_d = get_field(changeset, :active_period_end_date)
    ensure_end_date_values_for_specifier(changeset, specifier, end_dt, end_d)
  end

  def ensure_end_date_values_for_specifier(changeset, _, dt, d) when is_nil(dt) or is_nil(d) do
    change(changeset, %{
      active_period_end: nil,
      active_period_end_date: nil
    })
  end

  def ensure_end_date_values_for_specifier(changeset, :later_today, _, _) do
    now = NaiveDateTime.local_now()

    change(changeset, %{
      active_period_end: now,
      active_period_end_date: now |> NaiveDateTime.to_date()
    })
  end

  def ensure_end_date_values_for_specifier(changeset, :end_of_service, _, d) do
    change(changeset, %{
      active_period_end: NaiveDateTime.new!(d, ~T[23:59:59])
    })
  end

  def ensure_end_date_values_for_specifier(changeset, :until_further_notice, _, _) do
    now = NaiveDateTime.local_now()

    change(changeset, %{
      active_period_end: DTHelpers.replace_time(now, ~T[23:59:59]),
      active_period_end_date: now |> NaiveDateTime.to_date()
    })
  end

  def ensure_end_date_values_for_specifier(changeset, :when_work_order_is_closed, _, _) do
    now = NaiveDateTime.local_now()

    change(changeset, %{
      active_period_end: DTHelpers.replace_time(now, ~T[23:59:59]),
      active_period_end_date: now |> NaiveDateTime.to_date()
    })
  end

  def ensure_end_date_values_for_specifier(changeset, :custom, dt, _) do
    change(changeset, %{
      active_period_end_date: NaiveDateTime.to_date(dt)
    })
  end

  def ensure_end_date_values_for_specifier(changeset, _, _, _), do: changeset

  def normalize_alert_timing(changeset) do
    alert_timing = get_field(changeset, :alert_timing, "one-time")
    put_change(changeset, :alert_timing, normalize_alert_timing_field(alert_timing))
  end

  def normalize_alert_timing_field(:"one-time"), do: "one-time"
  def normalize_alert_timing_field("one-time"), do: "one-time"
  def normalize_alert_timing_field(:recurring), do: "recurring"
  def normalize_alert_timing_field("recurring"), do: "recurring"
  def normalize_alert_timing_field(_), do: "one-time"

  defp current_time, do: NaiveDateTime.local_now()

  defp alert_timing_values(),
    do: [
      "one-time",
      "recurring"
    ]

  defp start_values(),
    do: [
      :now,
      :start_of_service,
      :custom
    ]

  defp end_values(form) do
    if elevator_escalator_alert?(form.data) do
      [
        :later_today,
        :end_of_service,
        :until_further_notice,
        :when_work_order_is_closed,
        :custom
      ]
    else
      [
        :later_today,
        :end_of_service,
        :until_further_notice,
        :custom
      ]
    end
  end

  defp day_of_week_options(),
    do: [
      [key: :Monday, value: :monday, id: "monday"],
      [key: :Tuesday, value: :tuesday, id: "tuesday"],
      [key: :Wednesday, value: :wednesday, id: "wednesday"],
      [key: :Thursday, value: :thursday, id: "thursday"],
      [key: :Friday, value: :friday, id: "friday"],
      [key: :Saturday, value: :saturday, id: "saturday"],
      [key: :Sunday, value: :sunday, id: "sunday"]
    ]

  attr :form, Form

  def render(assigns) do
    ~H"""
    <div class="min-w-full flex flex-col mt-4" id="time_range_view">
      <.h5 class="text-text-secondary mb-8 w-full text-center md:text-left">
        Timeframe
      </.h5>
      <.select
        label="Alert timing"
        field={@form[:alert_timing]}
        options={values_to_options(alert_timing_values())}
        class="md:min-w-64 md:max-w-64"
        phx-debounce={120}
      />
      <.one_time_alert
        :if={@form[:alert_timing].value == "one-time"}
        class="flex flex-col md:flex-row md:flex-wrap md:gap-8 md:mt-4"
        current_time={current_time()}
        start_values={start_values()}
        end_values={end_values(@form)}
        form={@form}
      />
      <.recurring_alert
        :if={@form[:alert_timing].value == "recurring"}
        class="flex flex-col md:gap-8 md:mt-4"
        current_time={current_time()}
        day_of_week_options={day_of_week_options()}
        form={@form}
      />
    </div>
    """
  end

  attr :form, Form
  attr :class, :string, default: ""
  attr :current_time, NaiveDateTime
  attr :start_values, :list, default: []
  attr :end_values, :list, default: []

  defp one_time_alert(assigns) do
    ~H"""
    <div class={@class}>
      <.select
        label="Effect period"
        field={@form[:active_period_start_specifier]}
        options={values_to_options(@start_values)}
        class="md:min-w-64 md:max-w-64"
      />
      <.datetime
        field={@form[:active_period_start]}
        min={DateTimeHelpers.naive_datetime_to_iso8601(@current_time)}
        max="9999-12-31T23:59"
        value={DateTimeHelpers.naive_datetime_to_iso8601(@form[:active_period_start].value)}
        class={"md:min-w-64 md:max-w-64 " <> (if fv(@form, :active_period_start_specifier) === :custom, do: "", else: "hidden")}
      />
      <.datetime
        type="date"
        field={@form[:active_period_start_date]}
        min={next_start_of_service_date(@current_time)}
        max={
          [naive_datetime_to_iso_date(@form[:active_period_end].value), "9999-12-31"] |> Enum.max()
        }
        value={@form[:active_period_start_date].value}
        class={"md:min-w-64 md:max-w-64 " <> (if fv(@form, :active_period_start_specifier) === :start_of_service, do: "", else: "hidden")}
      />
      <p class="pt-5 md:pt-10">to</p>
      <.select
        field={@form[:active_period_end_specifier]}
        options={values_to_options(@end_values)}
        class="md:min-w-64 md:max-w-64"
        select_class="mt-[28.8px]"
      />
      <.datetime
        type="date"
        field={@form[:active_period_end_date]}
        min={@form[:active_period_start].value |> naive_datetime_to_iso_date}
        max="9999-12-31"
        value={@form[:active_period_end_date].value}
        class={"md:min-w-64 md:max-w-64 " <> (if fv(@form, :active_period_end_specifier) === :end_of_service, do: "", else: "hidden")}
      />
      <.datetime
        field={@form[:active_period_end]}
        min={DateTimeHelpers.naive_datetime_to_iso8601(@form[:active_period_start].value)}
        max="9999-12-31T23:59"
        value={DateTimeHelpers.naive_datetime_to_iso8601(@form[:active_period_end].value)}
        class={"md:min-w-64 md:max-w-64 " <> (if fv(@form, :active_period_end_specifier) === :custom, do: "", else: "hidden")}
      />
    </div>
    <div :if={Enum.empty?(@form.errors)} class="duration-explanation text-text-secondary">
      Effect duration: {TimeRangeDurationText.one_time_duration_text(paramify_form(@form))}
    </div>
    """
  end

  defp paramify_form(form) do
    form.data
    |> Map.from_struct()
    |> Map.new(fn {key, value} -> {Atom.to_string(key), value} end)
  end

  attr :form, Form
  attr :class, :string, default: ""
  attr :current_time, NaiveDateTime
  attr :day_of_week_options, :list, default: []

  defp recurring_alert(assigns) do
    ~H"""
    <div class={["flex flex-col", @class]}>
      <div>
        <div class="flex flex-col md:flex-row gap-8 md:my-4">
          <div class="flex flex-col md:flex-row gap-4 md:gap-8">
            <.select
              label="Effect start"
              field={@form[:active_period_start_time_specifier]}
              options={values_to_options([:start_of_service, :custom])}
              class="md:min-w-64 md:max-w-64"
              phx-debounce={120}
            />
            <.datetime
              label="Effect start time"
              type="time"
              field={@form[:active_period_start_time]}
              value={DateTimeHelpers.time_to_iso8601(@form[:active_period_start_time].value)}
              class={"md:min-w-64 md:max-w-64 h-10 " <> (if fv(@form, :active_period_start_time_specifier) === :custom, do: "", else: "hidden")}
              phx-debounce={120}
            />
          </div>
          <p class="md:pt-[2rem]">to</p>
          <div class="flex flex-col md:flex-row gap-4 md:gap-8">
            <.select
              label="Effect end"
              field={@form[:active_period_end_time_specifier]}
              options={values_to_options([:end_of_service, :custom])}
              class="md:min-w-64 md:max-w-64"
              phx-debounce={120}
            />
            <.datetime
              label="Effect end time"
              type="time"
              field={@form[:active_period_end_time]}
              value={DateTimeHelpers.time_to_iso8601(@form[:active_period_end_time].value)}
              class={"md:min-w-64 md:max-w-64 h-10 " <> (if fv(@form, :active_period_end_time_specifier) === :custom, do: "", else: "hidden")}
              phx-debounce={120}
            />
          </div>
        </div>

        <div class="flex flex-col md:flex-row gap-8 md:mb-8">
          <div class="flex flex-col md:flex-row gap-8">
            <.select
              label="Recurring alert start"
              field={@form[:active_period_start_specifier]}
              options={values_to_options([:now, :custom])}
              class="md:min-w-64 md:max-w-64"
              phx-debounce={120}
            />
            <.datetime
              label="Start date"
              type="date"
              max="9999-12-31"
              field={@form[:active_period_start_date]}
              value={@form[:active_period_start_date].value}
              class={"md:min-w-64 md:max-w-64 h-10 " <> (if fv(@form, :active_period_start_specifier) === :custom, do: "", else: "hidden")}
              phx-debounce={120}
            />
          </div>
          <p class="md:pt-[2rem]">to</p>
          <div class="flex flex-col md:flex-row gap-8">
            <.select
              label="Recurring alert end"
              field={@form[:active_period_end_specifier]}
              options={[{"When alert is closed", :until_further_notice}, {"Custom", :custom}]}
              class="md:min-w-64 md:max-w-64"
              phx-debounce={120}
            />
            <.datetime
              label="End date"
              type="date"
              max="9999-12-31"
              field={@form[:active_period_end_date]}
              value={@form[:active_period_end_date].value}
              class={"md:min-w-64 md:max-w-64 h-10 " <> (if fv(@form, :active_period_end_specifier) === :custom, do: "", else: "hidden")}
              phx-debounce={120}
            />
          </div>
        </div>
      </div>
      <.toggle_checkgroup
        :if={fv(@form, :alert_timing) === "recurring"}
        field={@form[:recurrence_days]}
        options={@day_of_week_options}
        class="md:max-w-[50%]"
        button_class="justify-center"
        column={false}
        show_icons={false}
      />
      <div
        :if={Enum.empty?(@form.errors) and @form[:recurrence_days].value not in [[], nil]}
        class="duration-explanation text-text-secondary"
      >
        Effect duration: {RecurringDurationText.recurring_duration_text(assigns)}
      </div>
    </div>
    """
  end

  defp next_start_of_service_date(current_time) do
    ActivePeriod.next_start_of_service_date(current_time)
    |> Date.to_iso8601()
  end

  def naive_datetime_to_iso_date(%NaiveDateTime{} = datetime),
    do: datetime |> NaiveDateTime.to_date() |> Date.to_iso8601()

  def naive_datetime_to_iso_date(_), do: ""

  defp fv(form, field), do: Ecto.Changeset.get_field(form.source, field)

  def elevator_escalator_alert?(alert_data) do
    combination = Map.get(alert_data, :combination) || Map.get(alert_data, "combination")
    effect_name = Map.get(alert_data, :effect_name) || Map.get(alert_data, "effect_name")
    combination == :ACCESS && effect_name in ["Elevator Closure", "Escalator Closure"]
  end
end
