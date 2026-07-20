defmodule AlertsUIWeb.FormComponents.Helpers.TimeRangeValidators do
  @moduledoc """
    Validators for time range component
  """
  import Ecto.Changeset

  @spec validate_relationships(Ecto.Changeset.t(), String.t(), map()) :: Ecto.Changeset.t()
  def validate_relationships(changeset, "one-time", %{"active_period_start" => ""}), do: changeset
  def validate_relationships(changeset, "one-time", %{"active_period_end" => ""}), do: changeset

  def validate_relationships(changeset, "one-time", time_range) do
    naive_start = ensure_naive_datetime_format(time_range["active_period_start"])

    validate_change(changeset, :active_period_end, fn :active_period_end, active_period_end ->
      validate_active_period_end(
        active_period_end,
        naive_start,
        time_range["active_period_end_specifier"]
      )
    end)
  end

  def validate_relationships(changeset, "recurring", time_range) do
    changeset
    |> validate_change(:active_period_end_date, fn :active_period_end_date,
                                                   active_period_end_date ->
      validate_active_period_end_date(
        active_period_end_date,
        time_range
      )
    end)
    |> validate_change(:active_period_start_date, fn :active_period_start_date,
                                                     active_period_start_date ->
      validate_start_date_matches_weekday(
        active_period_start_date,
        time_range["recurrence_days"],
        time_range["active_period_start_specifier"]
      )
    end)
  end

  def validate_relationships(changeset, _, _), do: changeset

  defp validate_active_period_end(active_period_end, active_period_start, specifier) do
    if NaiveDateTime.compare(
         active_period_end,
         active_period_start
       ) in [:lt, :eq] do
      end_error(specifier, active_period_start)
    else
      []
    end
  end

  defp end_error("later_today", ap_start),
    do: [active_period_end_specifier: "Effect must end after #{formatted_datetime(ap_start)}"]

  defp end_error("end_of_service", ap_start),
    do: [active_period_end_date: "Effect must end after #{formatted_datetime(ap_start)}"]

  defp end_error(_, ap_start),
    do: [active_period_end: "Effect must end after #{formatted_datetime(ap_start)}"]

  defp validate_active_period_end_date(active_period_end_date, time_range) do
    start_date = Map.get(time_range, "active_period_start_date") |> ensure_date_format
    start_time = Map.get(time_range, "active_period_start_time") |> ensure_time_format

    naive_start =
      if is_nil(start_time) or is_nil(start_date) do
        nil
      else
        NaiveDateTime.new!(start_date, start_time)
      end

    end_date = active_period_end_date
    end_time = Map.get(time_range, "active_period_end_time") |> ensure_time_format

    naive_end =
      if is_nil(end_time) or is_nil(end_date) do
        nil
      else
        NaiveDateTime.new!(end_date, end_time)
      end

    if naive_start && naive_end &&
         Date.compare(
           naive_end,
           naive_start
         ) in [:lt] do
      [
        active_period_end_date: "Effect must end after #{formatted_datetime(naive_start)}"
      ]
    else
      []
    end
  end

  def validate_notification(changeset, time_range, current_time, editing \\ false) do
    naive_start =
      if Map.get(time_range, :alert_timing) == :"one-time" do
        ensure_naive_datetime_format(time_range.active_period_start)
      else
        start_date = Map.get(time_range, :active_period_start_date) |> ensure_date_format
        start_time = Map.get(time_range, :active_period_start_time) |> ensure_time_format

        if is_nil(start_time) or is_nil(start_date) do
          nil
        else
          NaiveDateTime.new!(start_date, start_time)
        end
      end

    if naive_start do
      changeset
      |> validate_change(:notification_period_start, fn :notification_period_start,
                                                        notification_period_start ->
        validate_notification_period_start(
          notification_period_start,
          current_time,
          naive_start,
          editing
        )
      end)
    else
      changeset
    end
  end

  defp validate_notification_period_start(
         notification_period_start,
         current_time,
         naive_start,
         editing
       ) do
    cond do
      NaiveDateTime.diff(current_time, notification_period_start, :minute) > 1 and not editing ->
        [
          notification_period_start: {"Notifications can’t be set in the past", []},
          notification_period_start_date: {"Notifications can’t be set in the past", []}
        ]

      naive_start &&
          NaiveDateTime.diff(notification_period_start, naive_start, :minute) > 1 ->
        [
          notification_period_start:
            {"Notification period must start on or before #{formatted_datetime(naive_start)}", []},
          notification_period_start_date:
            {"Notification period must start on or before #{formatted_datetime(naive_start)}", []}
        ]

      true ->
        []
    end
  end

  @spec validate_required_notification_fields(Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def validate_required_notification_fields(changeset, params) do
    changeset
    |> validate_required(
      case params["notification_specifier"] do
        "same_as_effect_period" -> []
        "start_of_service" -> [:notification_period_start_date]
        "now" -> [:notification_period_start]
        "custom" -> [:notification_period_start]
      end,
      message: "Enter a valid date and/or time"
    )
  end

  defp validate_start_date_matches_weekday(start_date, recurrence_days, "now") do
    cond do
      recurrence_days in [[], nil] ->
        []

      Timex.weekday(start_date) in Enum.map(recurrence_days, &Timex.day_to_num/1) ->
        []

      true ->
        [
          active_period_start_specifier:
            {"Alert start day must match a selected day of the week.", []}
        ]
    end
  end

  defp validate_start_date_matches_weekday(start_date, recurrence_days, "custom") do
    cond do
      recurrence_days in [[], nil] ->
        []

      Timex.weekday(start_date) in Enum.map(recurrence_days, &Timex.day_to_num/1) ->
        []

      true ->
        [active_period_start_date: {"Alert start day must match a selected day of the week.", []}]
    end
  end

  defp validate_start_date_matches_weekday(_, _, _), do: []

  @spec validate_required_fields(Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def validate_required_fields(changeset, params) do
    required_fields_by_specifier(params["alert_timing"], changeset, params)
  end

  defp required_fields_by_specifier(:"one-time", changeset, params),
    do: required_fields_by_specifier("one-time", changeset, params)

  defp required_fields_by_specifier("one-time", changeset, params) do
    changeset
    |> validate_required(
      required_one_time_start_field_by_specifier(params["active_period_start_specifier"]),
      message: "Enter a valid time range start"
    )
    |> validate_required(
      required_one_time_end_field_by_specifier(params["active_period_end_specifier"]),
      message: "Enter a valid time range end"
    )
  end

  defp required_fields_by_specifier(:recurring, changeset, params),
    do: required_fields_by_specifier("recurring", changeset, params)

  defp required_fields_by_specifier("recurring", changeset, params) do
    changeset
    |> validate_length(:recurrence_days,
      min: 1,
      message: "Select one or more days for alert to recur"
    )
    |> validate_required(
      required_recurring_time_field_by_specifier(
        params["active_period_start_time_specifier"],
        :active_period_start_time
      ),
      message: "Enter a valid time range start"
    )
    |> validate_required(
      required_recurring_time_field_by_specifier(
        params["active_period_end_time_specifier"],
        :active_period_end_time
      ),
      message: "Enter a valid time range end"
    )
    |> validate_required([:active_period_start_date], message: "Enter a valid start date")
    |> validate_required(
      if(params["active_period_end_specifier"] == "custom",
        do: [:active_period_end_date],
        else: []
      ),
      message: "Enter a valid end date"
    )
  end

  defp required_fields_by_specifier(nil, changeset, _), do: changeset

  defp required_one_time_start_field_by_specifier(specifier) do
    case specifier do
      "custom" -> [:active_period_start]
      "start_of_service" -> [:active_period_start_date]
      _ -> []
    end
  end

  defp required_recurring_time_field_by_specifier(specifier, field) do
    if specifier == "custom" do
      [field]
    else
      []
    end
  end

  defp required_one_time_end_field_by_specifier(specifier) do
    case specifier do
      "custom" -> [:active_period_end]
      "end_of_service" -> [:active_period_end_date]
      _ -> []
    end
  end

  @spec validate_start_is_after_now(Ecto.Changeset.t(), any(), any(), boolean()) ::
          Ecto.Changeset.t()
  def validate_start_is_after_now(
        changeset,
        _current_time,
        _time_range,
        true
      ) do
    # this validation shouldn't run if we're editing
    changeset
  end

  def validate_start_is_after_now(
        changeset,
        current_time,
        %{"alert_timing" => :"one-time"} = time_range,
        editing
      ) do
    validate_start_is_after_now(
      changeset,
      current_time,
      %{time_range | "alert_timing" => "one-time"},
      editing
    )
  end

  def validate_start_is_after_now(
        changeset,
        current_time,
        %{"alert_timing" => "one-time"} = time_range,
        _editing
      ) do
    changeset
    |> validate_change(:active_period_start, fn :active_period_start, active_period_start ->
      time_in_past = NaiveDateTime.diff(current_time, active_period_start, :minute) > 1

      start_error(
        time_in_past,
        time_range["alert_timing"],
        time_range["active_period_start_specifier"]
      )
    end)
  end

  def validate_start_is_after_now(
        changeset,
        current_time,
        %{"alert_timing" => "recurring"} = time_range,
        _editing
      ) do
    start_date = Map.get(time_range, "active_period_start_date") |> ensure_date_format
    start_time = Map.get(time_range, "active_period_start_time") |> ensure_time_format

    naive_start =
      if is_nil(start_time) or is_nil(start_date) do
        nil
      else
        NaiveDateTime.new!(start_date, start_time)
      end

    if naive_start do
      changeset
      |> validate_change(:active_period_start_date, fn :active_period_start_date,
                                                       _active_period_start_date ->
        time_in_past = NaiveDateTime.diff(current_time, naive_start, :minute) > 1

        start_error(
          time_in_past,
          time_range["alert_timing"],
          time_range["active_period_start_specifier"]
        )
      end)
    else
      changeset
    end
  end

  def validate_start_is_after_now(
        changeset,
        _current_time,
        _time_range,
        _editing
      ) do
    changeset
  end

  defp start_error(false, _, _), do: []

  defp start_error(true, "one-time", "custom"),
    do: [active_period_start: "Effect can't start in the past"]

  defp start_error(true, "one-time", _),
    do: [active_period_start_date: "Effect can't start in the past"]

  defp start_error(true, "recurring", "now"),
    do: [active_period_start_specifier: "Effect can't start in the past"]

  defp start_error(true, "recurring", _),
    do: [active_period_start_date: "Effect can't start in the past"]

  @spec validate_start_is_before_trip(Ecto.Changeset.t(), NaiveDateTime.t() | nil, boolean) ::
          Ecto.Changeset.t()
  def validate_start_is_before_trip(changeset, trip_arrival_time, perform_validation \\ true)

  def validate_start_is_before_trip(changeset, nil, _), do: changeset

  def validate_start_is_before_trip(changeset, trip_arrival_time, perform_validation) do
    changeset
    |> validate_change(:active_period_start, fn :active_period_start, active_period_start ->
      if perform_validation and
           get_field(changeset, :alert_timing) != :recurring and
           NaiveDateTime.diff(active_period_start, trip_arrival_time, :minute) > 60 do
        [
          active_period_start:
            "Effect must start before #{formatted_datetime(trip_arrival_time |> NaiveDateTime.add(1, :hour))}",
          active_period_start_date:
            "Effect must start before #{formatted_datetime(trip_arrival_time |> NaiveDateTime.add(1, :hour))}"
        ]
      else
        []
      end
    end)
  end

  def validate_not_dst_gap(changeset) do
    changeset
    |> validate_change(:active_period_start, fn :active_period_start, active_period_start ->
      validate_not_in_dst_gap(
        ensure_naive_datetime_format(active_period_start),
        :active_period_start
      )
    end)
    |> validate_change(:active_period_end, fn :active_period_end, active_period_end ->
      validate_not_in_dst_gap(
        ensure_naive_datetime_format(active_period_end),
        :active_period_end
      )
    end)
  end

  defp validate_not_in_dst_gap(naive_datetime, field) do
    case DateTime.from_naive(naive_datetime, "America/New_York") do
      {:ok, _datetime} ->
        []

      {:gap, _, _} ->
        [
          {field,
           "Effect periods cannot start or end during a skipped daylight savings time hour"}
        ]
    end
  end

  defp formatted_datetime(datetime, format_string \\ "{0M}/{0D}/{YYYY}, {0h12}:{0m} {AM}"),
    do: Timex.format!(datetime, format_string)

  defp ensure_naive_datetime_format(""), do: nil
  defp ensure_naive_datetime_format(nil), do: nil

  defp ensure_naive_datetime_format(datetime) when is_binary(datetime) do
    datetime |> String.pad_trailing(19, ":00") |> NaiveDateTime.from_iso8601!()
  end

  defp ensure_naive_datetime_format(%DateTime{} = datetime), do: DateTime.to_naive(datetime)

  defp ensure_naive_datetime_format(%NaiveDateTime{} = datetime), do: datetime

  defp ensure_time_format(%Time{} = time), do: time

  defp ensure_time_format(""), do: nil

  defp ensure_time_format(nil), do: nil

  defp ensure_time_format(time) when is_binary(time) do
    time |> String.pad_trailing(8, ":00") |> Time.from_iso8601!()
  end

  defp ensure_date_format(%Date{} = date), do: date

  defp ensure_date_format(""), do: nil

  defp ensure_date_format(nil), do: nil

  defp ensure_date_format(date) when is_binary(date) do
    date |> Date.from_iso8601!()
  end
end
