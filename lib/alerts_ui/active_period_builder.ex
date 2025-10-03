defmodule AlertsUI.ActivePeriodBuilder do
  @moduledoc """
    Builds active period/s for an alert from form data

    All incoming times are naive datetimes created in the eastern timezone
    and need to be converted to UTC datetimes

    if the end_specifier for a one-time active period is :end_of_service,
    the date has been shifted 1 day back
    so that the user sees the date of the "service day", not the actual date.
    thus in that case this code shifts it back 1 day forward

    active_period_end == nil is what we're looking at to tell
    if a recurring alert has no set end and thus needs updating
    Do not change that without also changing the recurring alert updater
  """

  @type active_period_data_t :: %{
          active_period: [any()],
          active_period_start: DateTime.t(),
          active_period_end: DateTime.t() | nil,
          duration_certainty: atom(),
          recurrence_times: [Time.t()]
        }

  @spec build_one_time_active_period(
          %{
            active_period_start: NaiveDateTime.t() | nil,
            active_period_end: NaiveDateTime.t() | nil,
            active_period_end_specifier: atom() | nil,
            active_period_start_specifier: atom() | nil
          },
          DateTime.t()
        ) :: active_period_data_t() | %{}

  def build_one_time_active_period(%{active_period_start: nil}, _), do: %{}
  def build_one_time_active_period(%{active_period_end_specifier: nil}, _), do: %{}
  def build_one_time_active_period(%{active_period_start_specifier: nil}, _), do: %{}

  def build_one_time_active_period(
        %{
          active_period_start: naive_start,
          active_period_start_specifier: active_period_start_specifier,
          active_period_end_specifier: active_period_end_specifier,
          active_period_end: naive_end
        },
        current_time
      ) do
    utc_start =
      build_one_time_active_period_start(naive_start, active_period_start_specifier, current_time)

    utc_end =
      build_one_time_active_period_end(
        naive_end,
        active_period_end_specifier,
        naive_start,
        current_time
      )

    %{
      active_period_start: utc_start,
      active_period_end: utc_end,
      active_period: [%{start: utc_start, end: utc_end}],
      duration_certainty:
        active_period_end_specifier_to_duration_certainty(active_period_end_specifier)
    }
  end

  @spec build_recurring_active_period(%{
          active_period_start_time: Time.t(),
          active_period_end_time: Time.t(),
          active_period_end_specifier: :until_further_notice | :custom,
          active_period_start_date: Date.t(),
          active_period_end_date: Date.t(),
          recurrence_days: [atom()]
        }) :: active_period_data_t() | %{}

  def build_recurring_active_period(%{
        active_period_start_time: start_time,
        active_period_end_time: end_time,
        active_period_start_date: start_date,
        active_period_end_date: end_date,
        active_period_end_specifier: end_specifier,
        recurrence_days: recurrence_days
      }) do
    weekday_integers = Enum.map(recurrence_days, &Timex.day_to_num/1)

    end_date =
      if end_specifier == :until_further_notice do
        Timex.shift(start_date, years: 1)
      else
        end_date
      end

    list_of_dates =
      Date.range(start_date, end_date) |> Enum.filter(&(Timex.weekday(&1) in weekday_integers))

    next_day_modifier = if Time.before?(start_time, end_time), do: 0, else: 1

    active_periods =
      Enum.map(list_of_dates, fn date ->
        %{
          start:
            date
            |> DateTime.new!(start_time, "America/New_York")
            |> DateTime.shift_zone!("Etc/UTC"),
          end:
            date
            |> Date.add(next_day_modifier)
            |> DateTime.new!(end_time, "America/New_York")
            |> DateTime.shift_zone!("Etc/UTC")
        }
      end)

    active_period_end =
      if end_specifier == :until_further_notice do
        nil
      else
        List.last(active_periods).end
      end

    duration_certainty =
      if end_specifier == :until_further_notice do
        :UNKNOWN
      else
        :KNOWN
      end

    %{
      active_period_start: hd(active_periods).start,
      active_period_end: active_period_end,
      active_period: active_periods,
      recurrence_times: [
        DateTime.to_time(hd(active_periods).start),
        DateTime.to_time(List.last(active_periods).end)
      ],
      duration_certainty: duration_certainty
    }
  end

  defp active_period_end_specifier_to_duration_certainty(:later_today), do: :ESTIMATED
  defp active_period_end_specifier_to_duration_certainty(:until_further_notice), do: :UNKNOWN
  defp active_period_end_specifier_to_duration_certainty(:end_of_service), do: :KNOWN
  defp active_period_end_specifier_to_duration_certainty(:custom), do: :KNOWN

  defp build_one_time_active_period_start(_start_time, :now, current_time) do
    current_time
  end

  defp build_one_time_active_period_start(naive_start, _specifier, _time) do
    naive_start |> naive_eastern_datetime_to_utc
  end

  defp build_one_time_active_period_end(nil, _, _, _), do: nil

  defp build_one_time_active_period_end(_, :until_further_notice, _, _), do: nil

  defp build_one_time_active_period_end(_naive_end, :later_today, naive_start, current_time) do
    # if start time is BEFORE current time, use current time + 2 hours
    # else if start time is AFTER current time, use start time + 2 hours
    # this ensures "later today" is always in the future.
    utc_start = naive_eastern_datetime_to_utc(naive_start)

    if DateTime.compare(utc_start, current_time) == :lt do
      DateTime.add(current_time, 2, :hour)
    else
      DateTime.add(utc_start, 2, :hour)
    end
  end

  defp build_one_time_active_period_end(naive_end, _, _, _) do
    naive_eastern_datetime_to_utc(naive_end)
  end

  @spec naive_eastern_datetime_to_utc(NaiveDateTime.t() | nil) :: DateTime.t() | nil
  def naive_eastern_datetime_to_utc(nil), do: nil

  def naive_eastern_datetime_to_utc(naive),
    do: naive |> DateTime.from_naive!("America/New_York") |> Timex.Timezone.convert("Etc/UTC")
end
