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

    end_shift =
      if time_range["active_period_end_specifier"] == "end_of_service",
        do: 1,
        else: 0

    validate_change(changeset, :active_period_end, fn :active_period_end, active_period_end ->
      validate_active_period_end(
        active_period_end |> NaiveDateTime.add(end_shift, :day),
        naive_start
      )
    end)
  end

  def validate_relationships(changeset, "recurring", time_range) do
    changeset
    |> validate_change(:active_period_end_date, fn :active_period_end_date,
                                                   active_period_end_date ->
      validate_active_period_end_date(
        active_period_end_date,
        time_range["active_period_start_date"]
      )
    end)
  end

  def validate_relationships(changeset, _, _), do: changeset

  defp validate_active_period_end(active_period_end, active_period_start) do
    if NaiveDateTime.compare(
         active_period_end,
         active_period_start
       ) in [:lt] do
      [
        active_period_end: "Effect must end after #{formatted_datetime(active_period_start)}",
        active_period_end_date:
          "Effect must end after #{formatted_datetime(active_period_start, "{0M}/{0D}/{YYYY}")}"
      ]
    else
      []
    end
  end

  defp validate_active_period_end_date(active_period_end_date, %Date{} = active_period_start_date) do
    if Date.compare(
         active_period_end_date,
         active_period_start_date
       ) in [:lt] do
      [
        active_period_end_date:
          "Effect must end after #{formatted_datetime(active_period_start_date, "{0M}/{0D}/{YYYY}")}"
      ]
    else
      []
    end
  end

  defp validate_active_period_end_date(active_period_end_date, active_period_start_date) do
    {start_validity, start_date} = Date.from_iso8601(active_period_start_date)

    if start_validity === :ok do
      validate_active_period_end_date(active_period_end_date, start_date)
    else
      []
    end
  end

  def validate_notification(changeset, time_range) do
    changeset
    |> validate_change(:notification_period_start, fn :notification_period_start,
                                                      notification_period_start ->
      validate_notification_period_start(
        notification_period_start,
        time_range["active_period_start"],
        time_range["active_period_end"]
      )
    end)
  end

  defp validate_notification_period_start(
         notification_period_start,
         active_period_start,
         active_period_end
       ) do
    {start_validity, start_time} = NaiveDateTime.from_iso8601(active_period_start)

    {end_validity, end_time} =
      NaiveDateTime.from_iso8601(active_period_end)

    cond do
      start_validity === :ok &&
          NaiveDateTime.compare(
            notification_period_start,
            start_time
          ) in [:lt] ->
        [
          notification_period_start:
            {"Effect must start after #{formatted_datetime(start_time)}", []}
        ]

      end_validity === :ok &&
          NaiveDateTime.compare(
            notification_period_start,
            end_time
          ) in [:gt] ->
        [
          notification_period_start:
            {"Effect must end before #{formatted_datetime(end_time)}", []}
        ]

      true ->
        []
    end
  end

  @spec validate_required_fields(Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def validate_required_fields(changeset, params) do
    required_fields_by_specifier(params["alert_timing"], changeset, params)
  end

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

  defp required_fields_by_specifier("recurring", changeset, params) do
    changeset
    |> validate_required([:recurrence_days],
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

  defp required_fields_by_specifier("scheduled", changeset, _) do
    changeset
    |> validate_required([:notification_period_start],
      message: "Enter a valid scheduled alert start"
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

  def validate_start_is_after_now(changeset, current_time) do
    changeset
    |> validate_change(:active_period_start, fn :active_period_start, active_period_start ->
      if NaiveDateTime.diff(current_time, active_period_start, :minute) > 1 do
        [
          active_period_start: "Effect can't start in the past"
        ]
      else
        []
      end
    end)
    |> validate_change(:active_period_start_date, fn :active_period_start_date,
                                                     active_period_start_date ->
      if Date.diff(NaiveDateTime.to_date(current_time), active_period_start_date) > 1 do
        [
          active_period_start_date: "Effect can't start in the past"
        ]
      else
        []
      end
    end)
  end

  defp formatted_datetime(datetime, format_string \\ "{0M}/{0D}/{YYYY}, {0h12}:{0m} {AM}"),
    do: Timex.format!(datetime, format_string)

  defp ensure_naive_datetime_format(datetime) when is_binary(datetime) do
    datetime |> String.pad_trailing(19, ":00") |> NaiveDateTime.from_iso8601!()
  end

  defp ensure_naive_datetime_format(%NaiveDateTime{} = datetime), do: datetime
end
