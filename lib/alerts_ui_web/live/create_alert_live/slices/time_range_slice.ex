defmodule AlertsUIWeb.CreateAlertLive.Slices.TimeRangeSlice do
  @moduledoc """
  Slice that manages the alert active period (start/end datetimes, one-time vs.
  recurring timing, recurrence days, and automatic-close eligibility). Provides
  changeset transformation helpers and the timeframe section of the details form.
  """

  alias AlertsUI.Models.ActivePeriod

  import AlertsUIWeb.CreateAlertLive.Helpers.AlertDataHelpers,
    only: [put_over_nil: 3, values_to_options: 1]

  alias AlertsUIWeb.CreateAlertLive.Helpers.DurationText
  alias AlertsUIWeb.CreateAlertLive.Helpers.TimeRangeSliceGetters, as: TimeGetters
  alias AlertsUIWeb.CreateAlertLive.Slice
  alias AlertsUIWeb.FormComponents.Helpers.DateTimeHelpers
  alias AlertsUIWeb.TripEndWarningModal
  alias Phoenix.LiveView.AsyncResult

  alias Phoenix.HTML.Form

  import Ecto.Changeset

  use AlertsUIWeb, :html

  @responsive_class "flex flex-col md:gap-x-8 md:flex-row"
  defp responsive_class, do: @responsive_class

  defstruct [
    :form_type,
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
    active_period_end_specifier: nil,
    alert_timing: "one-time"
  ]

  defimpl Slice, for: __MODULE__ do
    alias AlertsUIWeb.CreateAlertLive.AlertData
    alias AlertsUIWeb.CreateAlertLive.Helpers.TimeRangeValidators
    alias AlertsUIWeb.CreateAlertLive.Slices.TimeRangeSlice

    def mount(_slice, socket, _params) do
      assign(socket, :current_time, DateTimeHelpers.current_time())
    end

    def extract(slice, %AlertData{} = alert, params) do
      now = DateTimeHelpers.current_time()

      end_specifier =
        if params["effect_name"] in ["elevator_closure", "escalator_closure"] do
          :when_work_order_is_closed
        else
          :later_today
        end

      slice
      |> put_over_nil(:alert_timing, :"one-time")
      |> put_over_nil(:active_period_start_specifier, :now)
      |> put_over_nil(:active_period_start_time_specifier, :start_of_service)
      |> put_over_nil(:active_period_start, now)
      |> put_over_nil(:active_period_start_date, NaiveDateTime.to_date(now))
      |> put_over_nil(:active_period_start_time, NaiveDateTime.to_time(now))
      |> put_over_nil(:active_period_end_specifier, end_specifier)
      |> put_over_nil(:active_period_end_time_specifier, :end_of_service)
      |> put_over_nil(:recurrence_days, [])
      |> update_times_if_duplicating(slice.form_type, now, alert)
      |> sync_can_close_automatically()
    end

    # Auto-close is derived from the end specifier. Keep it in sync when populating the
    # form so editing an auto-closable (Trapeze) alert doesn't drop the flag (mirrors the
    # transform/validate path's `ensure_end_values` and the old TimeRange component). Runs
    # after `update_times_if_duplicating`, which may itself change the end specifier.
    defp sync_can_close_automatically(slice) do
      %{
        slice
        | can_close_automatically:
            ensure_atom(slice.active_period_end_specifier) == :when_work_order_is_closed
      }
    end

    def transform(_slice, changeset, params, socket) do
      [_, target | _] = Map.get(params, "_target", [nil, nil])
      timing = params["alert_data"]["alert_timing"] |> ensure_atom()

      current_time = socket.assigns.current_time

      previous_start_specifier =
        Map.get(socket.assigns, :previous_start_specifier, nil) |> ensure_atom()

      previous_end_specifier =
        Map.get(socket.assigns, :previous_end_specifier, nil) |> ensure_atom()

      previous_start_time_specifier =
        Map.get(socket.assigns, :previous_start_time_specifier, nil) |> ensure_atom()

      previous_end_time_specifier =
        Map.get(socket.assigns, :previous_end_time_specifier, nil) |> ensure_atom()

      previous_recurrence_days = Map.get(socket.assigns, :previous_recurrence_days, [])

      changeset
      |> TimeRangeSlice.normalize_alert_timing()
      |> TimeRangeSlice.prevent_recurrence_day_deselection(previous_recurrence_days)
      |> TimeRangeSlice.ensure_start_values(
        previous_start_specifier,
        previous_start_time_specifier,
        current_time,
        timing
      )
      |> TimeRangeSlice.ensure_end_values(
        previous_end_specifier,
        previous_end_time_specifier,
        current_time,
        timing
      )
      |> TimeRangeSlice.set_values_from_detour(target, socket.assigns.skate_detours, current_time)
      |> TimeRangeSlice.set_start_end_from_trip_selection(
        target,
        socket.assigns.selections,
        get_field(changeset, :trip_ids, []),
        current_time
      )
    end

    def validate(slice, changeset, params, socket) do
      current_time = socket.assigns.current_time
      trip_ids = get_field(changeset, :trip_ids, [])

      trip_arrival_time =
        TimeRangeSlice.get_trip_arrival_time_for_validate(trip_ids, socket.assigns.selections)

      changeset
      |> TimeRangeValidators.validate_cast_datetimes(params)
      |> TimeRangeValidators.validate_required_fields()
      |> TimeRangeValidators.validate_not_dst_gap()
      |> TimeRangeValidators.validate_end_after_start()
      |> TimeRangeValidators.validate_start_is_after_now(current_time, slice.form_type)
      |> TimeRangeValidators.validate_at_least_one_recurrence()
      |> TimeRangeValidators.validate_start_date_matches_weekday()
      |> TimeRangeValidators.validate_start_is_before_trip(trip_arrival_time)
    end

    def assigns(_slice, socket, _params) do
      form = socket.assigns.form
      form_data = Map.merge(form.source.data, form.source.changes)

      trip_arrival_time =
        TimeRangeSlice.get_trip_arrival_time_for_validate(
          Map.get(form_data, :trip_ids, []),
          socket.assigns.selections
        )

      assign(socket, %{
        trip_arrival_time: trip_arrival_time,
        previous_start_specifier: form_data.active_period_start_specifier,
        previous_end_specifier: form_data.active_period_end_specifier,
        previous_start_time_specifier: form_data.active_period_start_time_specifier,
        previous_end_time_specifier: form_data.active_period_end_time_specifier,
        previous_recurrence_days: form_data.recurrence_days
      })
    end

    defp ensure_atom(potential_atom) when is_binary(potential_atom),
      do: String.to_existing_atom(potential_atom)

    defp ensure_atom(potential_atom), do: potential_atom

    def update_times_if_duplicating(%{active_period_end: nil} = slice, :duplicating, _, _) do
      slice
    end

    def update_times_if_duplicating(
          %{alert_timing: :recurring} = slice,
          :duplicating,
          now,
          _alert
        ) do
      if NaiveDateTime.compare(now, slice.active_period_end) in [:eq, :gt] do
        Map.merge(slice, %{
          active_period_start_specifier: :now,
          active_period_end_specifier: :until_further_notice,
          active_period_start_time_specifier: :custom,
          active_period_end_time_specifier: :custom,
          active_period_start: now,
          active_period_end: nil
        })
      else
        slice
      end
    end

    def update_times_if_duplicating(slice, :duplicating, now, alert) do
      if NaiveDateTime.compare(now, slice.active_period_end) in [:eq, :gt] do
        Map.merge(slice, %{
          active_period_start_specifier: :now,
          active_period_end_specifier: duplicate_end_specifier(alert),
          active_period_start: now
        })
      else
        slice
      end
    end

    def update_times_if_duplicating(slice, _, _, _), do: slice

    # Elevator/escalator alerts close when the work order closes, so duplicating a past
    # one mirrors the create flow's auto-selected end specifier instead of "later today".
    defp duplicate_end_specifier(alert) do
      if TimeRangeSlice.elevator_escalator_alert?(alert),
        do: :when_work_order_is_closed,
        else: :later_today
    end
  end

  def set_values_from_detour(
        changeset,
        "skate_detour_id",
        %AsyncResult{
          ok?: true,
          result: skate_detours
        },
        current_time
      ) do
    detour_id = get_field(changeset, :skate_detour_id)

    detour = Enum.find(skate_detours, &(&1.id == detour_id))

    end_changes =
      if is_nil(detour.autoclose_on) do
        %{
          active_period_end_specifier: :later_today,
          active_period_end: ActivePeriod.end_of_service_datetime_naive(current_time)
        }
      else
        detour_end = utc_datetime_to_naive(detour.autoclose_on)

        %{
          active_period_end_specifier: :custom,
          active_period_end: detour_end,
          active_period_end_time: NaiveDateTime.to_time(detour_end),
          active_period_end_date: Date.new!(detour_end.year, detour_end.month, detour_end.day)
        }
      end

    Map.merge(%{alert_timing: :"one-time", active_period_start_specifier: :now}, end_changes)
    |> Enum.reduce(changeset, fn {key, value}, changeset ->
      force_change(changeset, key, value)
    end)
  end

  def set_values_from_detour(changeset, _, _, _), do: changeset

  def ensure_start_values(
        changeset,
        previous_start_specifier,
        previous_start_time_specifier,
        current_time,
        :recurring
      ) do
    specifier = get_field(changeset, :active_period_start_specifier) |> ensure_atom
    time_specifier = get_field(changeset, :active_period_start_time_specifier) |> ensure_atom
    start_d = get_field(changeset, :active_period_start_date)
    start_t = get_field(changeset, :active_period_start_time)

    time_data = %{
      active_period_start_specifier: specifier,
      active_period_start_date: start_d,
      active_period_start_time_specifier: time_specifier,
      active_period_start_time: start_t
    }

    start_date =
      TimeGetters.get_recurring_start_date(
        time_data,
        current_time,
        previous_start_specifier
      )

    start_time =
      TimeGetters.get_recurring_start_time(
        time_data,
        current_time,
        previous_start_time_specifier
      )

    start_datetime =
      TimeGetters.get_recurring_start_datetime(start_date, start_time)

    changeset
    |> force_change(:active_period_start_specifier, specifier)
    |> force_change(:active_period_start_time, start_time)
    |> force_change(:active_period_start_date, start_date)
    |> force_change(:active_period_start, start_datetime)
  end

  def ensure_start_values(changeset, previous_start_specifier, _, current_time, _timing) do
    # one-time
    specifier = get_field(changeset, :active_period_start_specifier) |> ensure_atom
    start_dt = get_field(changeset, :active_period_start)
    start_d = get_field(changeset, :active_period_start_date)

    start_datetime =
      TimeGetters.get_onetime_start_datetime(
        %{
          active_period_start_specifier: specifier,
          active_period_start: start_dt,
          active_period_start_date: start_d
        },
        current_time,
        previous_start_specifier
      )

    start_date = TimeGetters.get_onetime_start_date(start_datetime)

    changeset
    |> force_change(:active_period_start_specifier, specifier)
    |> force_change(:active_period_start, start_datetime)
    |> force_change(:active_period_start_date, start_date)
  end

  def ensure_end_values(
        changeset,
        previous_end_specifier,
        previous_end_time_specifier,
        current_time,
        :recurring
      ) do
    specifier = get_field(changeset, :active_period_end_specifier) |> ensure_atom
    time_specifier = get_field(changeset, :active_period_end_time_specifier) |> ensure_atom
    end_d = get_field(changeset, :active_period_end_date)
    end_t = get_field(changeset, :active_period_end_time)

    time_data = %{
      active_period_end_specifier: specifier,
      active_period_end_date: end_d,
      active_period_end_time_specifier: time_specifier,
      active_period_end_time: end_t
    }

    end_date =
      TimeGetters.get_recurring_end_date(
        time_data,
        current_time,
        previous_end_specifier
      )

    end_time =
      TimeGetters.get_recurring_end_time(
        time_data,
        current_time,
        previous_end_time_specifier
      )

    end_datetime =
      TimeGetters.get_recurring_end_datetime(end_date, end_time)

    can_close_automatically = specifier == :when_work_order_is_closed

    changeset
    |> force_change(:active_period_end_specifier, specifier)
    |> force_change(:can_close_automatically, can_close_automatically)
    |> force_change(:active_period_end, end_datetime)
    |> force_change(:active_period_end_time, end_time)
    |> force_change(:active_period_end_date, end_date)
  end

  def ensure_end_values(changeset, previous_end_specifier, _, current_time, _timing) do
    # one-time
    specifier = get_field(changeset, :active_period_end_specifier) |> ensure_atom()
    end_dt = get_field(changeset, :active_period_end)
    end_d = get_field(changeset, :active_period_end_date)

    end_datetime =
      TimeGetters.get_onetime_end_datetime(
        %{
          active_period_end_specifier: specifier,
          active_period_end: end_dt,
          active_period_end_date: end_d
        },
        current_time,
        previous_end_specifier
      )

    end_date = TimeGetters.get_onetime_end_date(end_datetime)

    can_close_automatically = specifier == :when_work_order_is_closed

    changeset
    |> force_change(:active_period_end_specifier, specifier)
    |> force_change(:can_close_automatically, can_close_automatically)
    |> force_change(:active_period_end, end_datetime)
    |> force_change(:active_period_end_date, end_date)
  end

  def set_start_end_from_trip_selection(changeset, "trip_ids", _, [], now) do
    end_of_service = now |> ActivePeriod.end_of_service_datetime_naive()

    changeset
    |> force_change(:active_period_start_specifier, :now)
    |> force_change(:active_period_start, now)
    |> force_change(:active_period_start_date, now |> NaiveDateTime.to_date())
    |> force_change(:active_period_end_specifier, :later_today)
    |> force_change(:active_period_end, end_of_service)
    |> force_change(:active_period_end_date, end_of_service |> NaiveDateTime.to_date())
  end

  def set_start_end_from_trip_selection(
        changeset,
        "trip_ids",
        %{loading: loading} = selections,
        trip_ids,
        now
      )
      when loading != true do
    available_schedules = Map.get(selections, :available_schedules, [])
    selected_schedules = Enum.filter(available_schedules, &(&1.trip.id in trip_ids))
    departure = get_trip_departure_time(selected_schedules)
    arrival = get_trip_arrival_time(selected_schedules)

    {departure, start_specifier} =
      if NaiveDateTime.compare(now, departure) == :gt do
        {now, :now}
      else
        {departure, :custom}
      end

    changeset
    |> force_change(:active_period_start_specifier, start_specifier)
    |> force_change(:active_period_start, departure)
    |> force_change(:active_period_start_date, departure |> NaiveDateTime.to_date())
    |> force_change(:active_period_end_specifier, :custom)
    |> force_change(:active_period_end, NaiveDateTime.add(arrival, 1, :hour))
    |> force_change(:active_period_end_date, arrival |> NaiveDateTime.to_date())
  end

  def set_start_end_from_trip_selection(changeset, _, _, _, _) do
    changeset
  end

  defp get_trip_departure_time(selected_schedules) do
    selected_schedules
    |> Enum.map(& &1.departure_time)
    |> Enum.min(DateTime, fn -> nil end)
    |> utc_datetime_to_naive()
  end

  defp get_trip_arrival_time(selected_schedules) do
    selected_schedules
    |> Enum.map(& &1.time_of_last_trip_arrival)
    |> Enum.max(DateTime, fn -> nil end)
    |> utc_datetime_to_naive()
  end

  def normalize_alert_timing(changeset) do
    alert_timing = get_field(changeset, :alert_timing, :"one-time")
    change(changeset, %{alert_timing: ensure_atom(alert_timing)})
  end

  def prevent_recurrence_day_deselection(changeset, previous_recurrence_days) do
    current = get_field(changeset, :recurrence_days) || []
    recurring? = get_field(changeset, :alert_timing) in [:recurring, "recurring"]

    desired =
      if recurring? and current == [] and previous_recurrence_days not in [nil, []] do
        previous_recurrence_days
      else
        current
      end

    force_change(changeset, :recurrence_days, desired)
  end

  def get_trip_arrival_time_for_validate(trip_ids, %{
        loading: _loading,
        available_schedules: available_schedules
      }) do
    trip_arrival_time(trip_ids, available_schedules)
  end

  def get_trip_arrival_time_for_validate(trip_ids, %{
        ok?: true,
        result: %{available_schedules: available_schedules}
      }) do
    trip_arrival_time(trip_ids, available_schedules)
  end

  def get_trip_arrival_time_for_validate(_, _), do: nil

  defp trip_arrival_time(trip_ids, available_schedules) do
    available_schedules
    |> Enum.filter(&(&1.trip.id in trip_ids))
    |> Enum.map(& &1.time_of_last_trip_arrival)
    |> Enum.max(DateTime, fn -> nil end)
    |> utc_datetime_to_naive()
  end

  defp ensure_atom(potential_atom) when is_binary(potential_atom),
    do: String.to_existing_atom(potential_atom)

  defp ensure_atom(potential_atom), do: potential_atom

  defp alert_timing_values,
    do: [
      "one-time",
      "recurring"
    ]

  defp start_values,
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

  defp day_of_week_options,
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
  attr :current_time, NaiveDateTime
  attr :trip_arrival_time, NaiveDateTime
  attr :previous_start_specifier, :atom
  attr :previous_end_specifier, :atom
  attr :previous_start_time_specifier, :atom
  attr :previous_end_time_specifier, :atom
  attr :skate_detours, :map

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
        :if={@form[:alert_timing].value in [:"one-time", "one-time"]}
        class="flex-wrap md:mt-4"
        trip_arrival_time={@trip_arrival_time}
        current_time={@current_time}
        start_values={start_values()}
        end_values={end_values(@form)}
        form={@form}
      />
      <.recurring_alert
        :if={@form[:alert_timing].value in [:recurring, "recurring"]}
        class="flex-wrap md:mt-4"
        current_time={@current_time}
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
  attr :trip_arrival_time, NaiveDateTime

  defp one_time_alert(assigns) do
    show_trip_end_warning? =
      TripEndWarningModal.show_warning?(
        assigns.trip_arrival_time,
        assigns.form.data.active_period_start,
        assigns.form.data.modal_date
      ) and :active_period_start not in Keyword.keys(assigns.form.errors)

    assigns = assign(assigns, :show_trip_end_warning, show_trip_end_warning?)

    ~H"""
    <div class={[responsive_class(), @class]}>
      <div class={responsive_class()}>
        <div class={responsive_class()}>
          <.select
            label="Effect period"
            warning={
              @show_trip_end_warning && @form.data.active_period_start_specifier in [:now, "now"]
            }
            field={@form[:active_period_start_specifier]}
            options={values_to_options(@start_values)}
            class="md:min-w-64 md:max-w-64"
          />
          <.datetime
            field={@form[:active_period_start]}
            warning={@show_trip_end_warning}
            min={DateTimeHelpers.naive_datetime_to_iso8601(@current_time)}
            max="9999-12-31T23:59"
            value={DateTimeHelpers.naive_datetime_to_iso8601(@form[:active_period_start].value)}
            class={"md:min-w-64 md:max-w-64 " <> (if fv(@form, :active_period_start_specifier) in [:custom, "custom"], do: "", else: "hidden")}
          />
          <.datetime
            type="date"
            field={@form[:active_period_start_date]}
            min={next_start_of_service_date(@current_time)}
            max={
              [naive_datetime_to_iso_date(@form[:active_period_end].value), "9999-12-31"]
              |> Enum.max()
            }
            value={@form[:active_period_start_date].value}
            class={"md:min-w-64 md:max-w-64 " <> (if fv(@form, :active_period_start_specifier) in [:start_of_service, "start_of_service"], do: "", else: "hidden")}
          />
        </div>
        <p class="pt-5 md:pt-10">to</p>
      </div>
      <div class={responsive_class()}>
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
          class={"md:min-w-64 md:max-w-64 " <> (if fv(@form, :active_period_end_specifier) in [:end_of_service, "end_of_service"], do: "", else: "hidden")}
        />
        <.datetime
          field={@form[:active_period_end]}
          min={DateTimeHelpers.naive_datetime_to_iso8601(@form[:active_period_start].value)}
          max="9999-12-31T23:59"
          value={DateTimeHelpers.naive_datetime_to_iso8601(@form[:active_period_end].value)}
          class={"md:min-w-64 md:max-w-64 " <> (if fv(@form, :active_period_end_specifier) in [:custom, "custom"], do: "", else: "hidden")}
        />
      </div>
    </div>
    <div
      :if={Enum.empty?(@form.errors)}
      class="duration-explanation text-text-secondary"
      id="duration-text"
    >
      Effect duration: {DurationText.one_time_duration_text(@form)}
    </div>
    """
  end

  attr :form, Form
  attr :class, :string, default: ""
  attr :current_time, NaiveDateTime
  attr :day_of_week_options, :list, default: []

  defp recurring_alert(assigns) do
    ~H"""
    <div class={["flex flex-col gap-4", @class]}>
      <div class="flex flex-col gap-4">
        <div class={[responsive_class(), "flex-wrap gap-4"]}>
          <div class={[responsive_class(), "gap-4"]}>
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
              class={"md:min-w-64 md:max-w-64 " <> (if fv(@form, :active_period_start_time_specifier) in [:custom, "custom"], do: "", else: "hidden")}
              phx-debounce={120}
            />
            <p class="md:pt-[2rem]">to</p>
          </div>
          <div class={responsive_class()}>
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
              class={"md:min-w-64 md:max-w-64 " <> (if fv(@form, :active_period_end_time_specifier) in [:custom, "custom"], do: "", else: "hidden")}
              phx-debounce={120}
            />
          </div>
        </div>

        <div class={[responsive_class(), "gap-4 flex-wrap"]}>
          <div class={[responsive_class(), "gap-4"]}>
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
              class={"md:min-w-64 md:max-w-64 " <> (if fv(@form, :active_period_start_specifier) in [:custom, "custom"], do: "", else: "hidden")}
              phx-debounce={120}
            />
            <p class="md:pt-[2rem]">to</p>
          </div>
          <div class={responsive_class()}>
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
              class={"md:min-w-64 md:max-w-64 " <> (if fv(@form, :active_period_end_specifier) in [:custom, "custom"], do: "", else: "hidden")}
              phx-debounce={120}
            />
          </div>
        </div>
      </div>
      <div>
        <.toggle_checkgroup
          :if={fv(@form, :alert_timing) in [:recurring, "recurring"]}
          field={@form[:recurrence_days]}
          options={@day_of_week_options}
          class="md:max-w-[50%]"
          button_class="justify-center"
          column={false}
          show_icons={false}
          prevent_empty={true}
        />
        <div
          :if={Enum.empty?(@form.errors) and @form[:recurrence_days].value not in [[], nil]}
          class="duration-explanation text-text-secondary"
          id="duration-text-recurring"
        >
          Effect duration: {DurationText.recurring_duration_text(@form)}
        </div>
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

  defp utc_datetime_to_naive(nil), do: nil

  defp utc_datetime_to_naive(datetime),
    do: datetime |> DateTime.shift_zone!("America/New_York") |> DateTime.to_naive()

  def elevator_escalator_alert?(alert_data) do
    effect_name = Map.get(alert_data, :effect_name) || Map.get(alert_data, "effect_name")
    effect_name in ["elevator_closure", "escalator_closure"]
  end
end
