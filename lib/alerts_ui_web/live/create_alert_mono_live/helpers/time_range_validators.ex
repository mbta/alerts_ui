defmodule AlertsUIWeb.CreateAlertMonoLive.Helpers.TimeRangeValidators do
  @moduledoc """
  Changeset validation helpers for alert time-range fields. Validates that
  datetimes are parseable, start/end ordering is correct, starts are not in
  the past, recurrence days are set, DST gaps are avoided, and notification
  period constraints are satisfied.
  """

  import Ecto.Changeset

  def validate_cast_datetimes(changeset, params) do
    alert_params = Map.get(params, "alert_data", %{})

    changeset
    |> maybe_validate_datetime(alert_params, "active_period_start", :active_period_start)
    |> maybe_validate_datetime(alert_params, "active_period_end", :active_period_end)
  end

  def validate_cast_notification_datetimes(changeset, params) do
    alert_params = Map.get(params, "alert_data", %{})

    maybe_validate_datetime(
      changeset,
      alert_params,
      "notification_period_start",
      :notification_period_start,
      "Enter a valid date and time"
    )
  end

  defp maybe_validate_datetime(changeset, params, key, field, message \\ "Enter a valid datetime") do
    case Map.get(params, key) do
      nil ->
        changeset

      "" ->
        changeset

      value ->
        case Ecto.Type.cast(:naive_datetime, value) do
          {:ok, _} -> changeset
          _ -> add_error(changeset, field, message)
        end
    end
  end

  def validate_required_fields(changeset) do
    timing = get_field(changeset, :alert_timing)

    cond do
      timing in [:"one-time", "one-time"] ->
        changeset
        |> validate_required(
          required_one_time_start_fields(get_field(changeset, :active_period_start_specifier)),
          message: "Enter a valid time range start"
        )
        |> validate_required(
          required_one_time_end_fields(get_field(changeset, :active_period_end_specifier)),
          message: "Enter a valid time range end"
        )

      timing in [:recurring, "recurring"] ->
        changeset
        |> validate_required(
          required_recurring_time_fields(
            get_field(changeset, :active_period_start_time_specifier),
            :active_period_start_time
          ),
          message: "Enter a valid time range start"
        )
        |> validate_required(
          required_recurring_time_fields(
            get_field(changeset, :active_period_end_time_specifier),
            :active_period_end_time
          ),
          message: "Enter a valid time range end"
        )
        |> validate_required([:active_period_start_date], message: "Enter a valid start date")
        |> validate_required(
          if(get_field(changeset, :active_period_end_specifier) == :custom,
            do: [:active_period_end_date],
            else: []
          ),
          message: "Enter a valid end date"
        )

      true ->
        changeset
    end
  end

  def validate_end_after_start(changeset) do
    timing = get_field(changeset, :alert_timing)

    cond do
      timing in [:"one-time", "one-time"] -> validate_one_time_end(changeset)
      timing in [:recurring, "recurring"] -> validate_recurring_end(changeset)
      true -> changeset
    end
  end

  defp validate_one_time_end(changeset) do
    case get_field(changeset, :active_period_start) do
      nil ->
        changeset

      active_period_start ->
        validate_change(changeset, :active_period_end, fn :active_period_end, end_dt ->
          one_time_end_errors(
            end_dt,
            active_period_start,
            get_field(changeset, :active_period_end_specifier)
          )
        end)
    end
  end

  defp one_time_end_errors(end_dt, start_dt, specifier) do
    if NaiveDateTime.compare(end_dt, start_dt) in [:lt, :eq] do
      end_error(specifier, start_dt)
    else
      []
    end
  end

  defp validate_recurring_end(changeset) do
    validate_change(changeset, :active_period_end_date, fn :active_period_end_date, end_date ->
      recurring_end_errors(end_date, changeset)
    end)
  end

  defp recurring_end_errors(end_date, changeset) do
    start_date = get_field(changeset, :active_period_start_date)
    start_time = get_field(changeset, :active_period_start_time)
    end_time = get_field(changeset, :active_period_end_time)
    naive_start = start_date && start_time && NaiveDateTime.new!(start_date, start_time)
    naive_end = end_time && NaiveDateTime.new!(end_date, end_time)

    if naive_start && naive_end && Date.compare(naive_end, naive_start) == :lt do
      [active_period_end_date: "Effect must end after #{formatted_datetime(naive_start)}"]
    else
      []
    end
  end

  def validate_start_is_after_now(changeset, editing \\ false)
  def validate_start_is_after_now(changeset, true), do: changeset

  def validate_start_is_after_now(changeset, _editing) do
    now = NaiveDateTime.local_now()
    specifier = get_field(changeset, :active_period_start_specifier)
    timing = get_field(changeset, :alert_timing)
    validate_start_by_timing(changeset, timing, specifier, now)
  end

  defp validate_start_by_timing(changeset, timing, specifier, now)
       when timing in [:"one-time", "one-time"] do
    changeset
    |> validate_change(:active_period_start, fn _, t -> custom_start_errors(t, specifier, now) end)
    |> validate_start_date_not_in_past(specifier, now)
  end

  defp validate_start_by_timing(changeset, timing, specifier, now)
       when timing in [:recurring, "recurring"] do
    validate_recurring_start_not_in_past(changeset, specifier, now)
  end

  defp validate_start_by_timing(changeset, _, _, _), do: changeset

  defp custom_start_errors(t, specifier, now) do
    if specifier == :custom,
      do: start_error(NaiveDateTime.diff(now, t, :minute) > 1, :"one-time", specifier),
      else: []
  end

  defp validate_start_date_not_in_past(changeset, specifier, now) do
    validate_change(changeset, :active_period_start_date, fn :active_period_start_date, date ->
      if specifier == :start_of_service do
        past? = NaiveDateTime.diff(now, NaiveDateTime.new!(date, ~T[03:00:00]), :minute) > 1
        start_error(past?, :"one-time", specifier)
      else
        []
      end
    end)
  end

  defp validate_recurring_start_not_in_past(changeset, specifier, now) do
    start_date = get_field(changeset, :active_period_start_date)
    start_time = get_field(changeset, :active_period_start_time)

    if start_date && start_time do
      naive_start = NaiveDateTime.new!(start_date, start_time)

      validate_change(changeset, :active_period_start_date, fn :active_period_start_date, _ ->
        start_error(NaiveDateTime.diff(now, naive_start, :minute) > 1, :recurring, specifier)
      end)
    else
      changeset
    end
  end

  def validate_at_least_one_recurrence(changeset) do
    timing = get_field(changeset, :alert_timing)

    if timing in [:recurring, "recurring"] do
      validate_length(changeset, :recurrence_days,
        min: 1,
        message: "Select one or more days for alert to recur"
      )
    else
      changeset
    end
  end

  def validate_start_date_matches_weekday(changeset) do
    timing = get_field(changeset, :alert_timing)

    if timing in [:recurring, "recurring"] do
      validate_change(
        changeset,
        :recurrence_days,
        fn :recurrence_days, recurrence_days ->
          start_date = get_field(changeset, :active_period_start_date)
          specifier = get_field(changeset, :active_period_start_specifier)
          validate_start_date_matches_weekday(start_date, recurrence_days, specifier)
        end
      )
    else
      changeset
    end
  end

  def validate_not_dst_gap(changeset) do
    changeset
    |> validate_change(:active_period_start, fn :active_period_start, active_period_start ->
      validate_not_in_dst_gap(active_period_start, :active_period_start)
    end)
    |> validate_change(:active_period_end, fn :active_period_end, active_period_end ->
      validate_not_in_dst_gap(active_period_end, :active_period_end)
    end)
  end

  def validate_start_is_before_trip(changeset, trip_arrival_time \\ nil)
  def validate_start_is_before_trip(changeset, nil), do: changeset

  def validate_start_is_before_trip(changeset, trip_arrival_time) do
    validate_change(
      changeset,
      :active_period_start,
      fn :active_period_start, active_period_start ->
        if get_field(changeset, :alert_timing) != :recurring and
             NaiveDateTime.diff(active_period_start, trip_arrival_time, :minute) > 60 do
          deadline = NaiveDateTime.add(trip_arrival_time, 1, :hour)

          [
            active_period_start: "Effect must start before #{formatted_datetime(deadline)}",
            active_period_start_date: "Effect must start before #{formatted_datetime(deadline)}"
          ]
        else
          []
        end
      end
    )
  end

  def validate_notification(changeset) do
    current_time = NaiveDateTime.local_now()

    naive_start =
      if get_field(changeset, :alert_timing) in [:"one-time", "one-time"] do
        get_field(changeset, :active_period_start)
      else
        start_date = get_field(changeset, :active_period_start_date)
        start_time = get_field(changeset, :active_period_start_time)

        if start_date && start_time,
          do: NaiveDateTime.new!(start_date, start_time),
          else: nil
      end

    if naive_start do
      validate_change(changeset, :notification_period_start, fn :notification_period_start, t ->
        notification_period_errors(t, naive_start, current_time)
      end)
    else
      changeset
    end
  end

  defp notification_period_errors(notification_period_start, naive_start, current_time) do
    cond do
      NaiveDateTime.diff(current_time, notification_period_start, :minute) > 1 ->
        [
          notification_period_start: {"Notifications can't be set in the past", []},
          notification_period_start_date: {"Notifications can't be set in the past", []}
        ]

      NaiveDateTime.diff(notification_period_start, naive_start, :minute) > 1 ->
        msg = "Notification period must start on or before #{formatted_datetime(naive_start)}"
        [notification_period_start: {msg, []}, notification_period_start_date: {msg, []}]

      true ->
        []
    end
  end

  def validate_required_notification_fields(changeset) do
    validate_required(
      changeset,
      case get_field(changeset, :notification_specifier) do
        :same_as_effect_period -> []
        :start_of_service -> [:notification_period_start_date]
        :now -> [:notification_period_start]
        :custom -> [:notification_period_start]
      end,
      message: "Enter a valid date and/or time"
    )
  end

  defp required_one_time_start_fields(:custom), do: [:active_period_start]
  defp required_one_time_start_fields(:start_of_service), do: [:active_period_start_date]
  defp required_one_time_start_fields(_), do: []

  defp required_one_time_end_fields(:custom), do: [:active_period_end]
  defp required_one_time_end_fields(:end_of_service), do: [:active_period_end_date]
  defp required_one_time_end_fields(_), do: []

  defp required_recurring_time_fields(:custom, field), do: [field]
  defp required_recurring_time_fields(_, _), do: []

  defp start_error(false, _, _), do: []

  defp start_error(true, :"one-time", :custom),
    do: [active_period_start: "Effect can't start in the past"]

  defp start_error(true, :"one-time", _),
    do: [active_period_start_date: "Effect can't start in the past"]

  defp start_error(true, :recurring, :now),
    do: [active_period_start_specifier: "Effect can't start in the past"]

  defp start_error(true, :recurring, _),
    do: [active_period_start_date: "Effect can't start in the past"]

  defp end_error(:later_today, ap_start),
    do: [active_period_end_specifier: "Effect must end after #{formatted_datetime(ap_start)}"]

  defp end_error(:end_of_service, ap_start),
    do: [active_period_end_date: "Effect must end after #{formatted_datetime(ap_start)}"]

  defp end_error(_, ap_start),
    do: [active_period_end: "Effect must end after #{formatted_datetime(ap_start)}"]

  defp validate_start_date_matches_weekday(_start_date, recurrence_days, _specifier)
       when recurrence_days in [[], nil],
       do: []

  defp validate_start_date_matches_weekday(start_date, recurrence_days, :now) do
    if day_num_to_atom(Date.day_of_week(start_date)) in recurrence_days do
      []
    else
      [
        recurrence_days: {"Alert start day must match a selected day of the week.", []}
      ]
    end
  end

  defp validate_start_date_matches_weekday(start_date, recurrence_days, :custom) do
    if day_num_to_atom(Date.day_of_week(start_date)) in recurrence_days do
      []
    else
      [recurrence_days: {"Alert start day must match a selected day of the week.", []}]
    end
  end

  defp validate_start_date_matches_weekday(_, _, _), do: []

  defp day_num_to_atom(1), do: :monday
  defp day_num_to_atom(2), do: :tuesday
  defp day_num_to_atom(3), do: :wednesday
  defp day_num_to_atom(4), do: :thursday
  defp day_num_to_atom(5), do: :friday
  defp day_num_to_atom(6), do: :saturday
  defp day_num_to_atom(7), do: :sunday

  defp validate_not_in_dst_gap(naive_datetime, field) do
    case DateTime.from_naive(naive_datetime, "America/New_York") do
      {:ok, _} ->
        []

      {:gap, _, _} ->
        [
          {field,
           "Effect periods cannot start or end during a skipped daylight savings time hour"}
        ]
    end
  end

  defp formatted_datetime(datetime), do: Calendar.strftime(datetime, "%m/%d/%Y, %I:%M %p")
end
