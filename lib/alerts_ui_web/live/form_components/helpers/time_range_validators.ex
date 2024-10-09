defmodule AlertsUIWeb.FormComponents.Helpers.TimeRangeValidators do
  @moduledoc """
    Validators for time range component
  """
  import Ecto.Changeset

  @spec validate_relationships(Ecto.Changeset.t(), String.t(), map()) :: Ecto.Changeset.t()
  def validate_relationships(changeset, "one-time", time_range) do
    changeset
    |> validate_change(:active_period_start, fn :active_period_start, active_period_start ->
      validate_active_period_start(
        active_period_start,
        time_range["active_period_end"]
      )
    end)
    |> validate_change(:active_period_end, fn :active_period_end, active_period_end ->
      validate_active_period_end(active_period_end, time_range["active_period_start"])
    end)
  end

  def validate_relationships(changeset, "recurring", time_range) do
    changeset
    |> validate_change(:active_period_start, fn :active_period_start, active_period_start ->
      validate_active_period_start(
        active_period_start,
        time_range["active_period_end"]
      )
    end)
    |> validate_change(:active_period_end, fn :active_period_end, active_period_end ->
      validate_active_period_end(active_period_end, time_range["active_period_start"])
    end)
  end

  def validate_relationships(changeset, _, _), do: changeset

  defp validate_active_period_start(active_period_start, %NaiveDateTime{} = active_period_end) do
    if NaiveDateTime.compare(
         active_period_start,
         active_period_end
       ) in [:gt] do
      [
        active_period_start: "Effect must start before #{formatted_datetime(active_period_end)}",
        active_period_start_date:
          "Effect must start before #{formatted_datetime(active_period_end, "{0M}/{0D}/{YYYY}")}"
      ]
    else
      []
    end
  end

  defp validate_active_period_start(active_period_start, active_period_end) do
    {end_validity, end_time} = NaiveDateTime.from_iso8601(active_period_end)

    if end_validity === :ok do
      validate_active_period_start(active_period_start, end_time)
    else
      []
    end
  end

  defp validate_active_period_end(active_period_end, %NaiveDateTime{} = active_period_start) do
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

  defp validate_active_period_end(active_period_end, active_period_start) do
    {start_validity, start_time} = NaiveDateTime.from_iso8601(active_period_start)

    if start_validity === :ok do
      validate_active_period_end(active_period_end, start_time)
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
    required_fields_by_specifier(params["alert_timing_dropdown"], changeset, params)
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
    |> validate_required([:days_of_week],
      message: "Select one or more days for alert to recur"
    )
    |> validate_required(
      required_recurring_time_field_by_specifier(
        params["active_period_start_specifier"],
        :active_period_start_time
      ),
      message: "Enter a valid time range start"
    )
    |> validate_required(
      required_recurring_time_field_by_specifier(
        params["active_period_end_specifier"],
        :active_period_end_time
      ),
      message: "Enter a valid time range end"
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
    validate_change(changeset, :active_period_start, fn :active_period_start,
                                                        active_period_start ->
      if NaiveDateTime.compare(
           active_period_start,
           current_time |> NaiveDateTime.truncate(:second)
         ) in [:lt] do
        [
          active_period_start: "Effect can't start in the past",
          active_period_start_date: "Effect can't start in the past"
        ]
      else
        []
      end
    end)
  end

  defp formatted_datetime(datetime, format_string \\ "{0M}/{0D}/{YYYY}, {0h12}:{0m} {AM}"),
    do: Timex.format!(datetime, format_string)
end
