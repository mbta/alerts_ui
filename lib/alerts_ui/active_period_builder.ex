defmodule AlertsUI.ActivePeriodBuilder do
  @moduledoc """
    Builds active period/s for an alert from form data

    All incoming times are naive datetimes created in the eastern timezone
    and need to be converted to UTC datetimes
  """

  @type active_period_data_t :: %{
          active_period: [any()],
          active_period_start: DateTime.t(),
          active_period_end: DateTime.t() | nil,
          duration_certainty: atom()
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

    utc_end = build_one_time_active_period_end(naive_end)

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
          days_of_week: [atom()]
        }) :: active_period_data_t() | %{}

  def build_recurring_active_period(%{
        active_period_start_time: start_time,
        active_period_end_time: end_time,
        active_period_start_date: start_date,
        active_period_end_date: end_date,
        active_period_end_specifier: end_specifier,
        days_of_week: days_of_week
      }) do
    weekday_integers = Enum.map(days_of_week, &Timex.day_to_num/1)

    end_date =
      if end_specifier == :until_further_notice, do: Date.add(start_date, 365), else: end_date

    list_of_dates =
      Date.range(start_date, end_date) |> Enum.filter(&(Timex.weekday(&1) in weekday_integers))

    next_day_modifier = if Time.after?(start_time, end_time), do: 1, else: 0

    active_periods =
      Enum.map(list_of_dates, fn date ->
        %{
          start:
            date
            |> DateTime.new!(start_time, "America/New_York")
            |> Timex.Timezone.convert("Etc/UTC"),
          end:
            date
            |> Date.add(next_day_modifier)
            |> DateTime.new!(end_time, "America/New_York")
            |> Timex.Timezone.convert("Etc/UTC")
        }
      end)

    active_period_end =
      if end_specifier == :until_further_notice,
        do: nil,
        else: (active_periods |> Enum.reverse() |> hd).end

    %{
      active_period_start: hd(active_periods).start,
      active_period_end: active_period_end,
      active_period: active_periods,
      duration_certainty: :KNOWN
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

  defp build_one_time_active_period_end(nil), do: nil
  defp build_one_time_active_period_end(naive_end), do: naive_end |> naive_eastern_datetime_to_utc

  @spec naive_eastern_datetime_to_utc(NaiveDateTime.t() | nil) :: DateTime.t() | nil
  def naive_eastern_datetime_to_utc(nil), do: nil

  def naive_eastern_datetime_to_utc(naive),
    do: naive |> DateTime.from_naive!("America/New_York") |> Timex.Timezone.convert("Etc/UTC")
end
