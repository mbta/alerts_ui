defmodule AlertsUI.Helpers.Recurrence do
  @moduledoc """
  Functions around turning an array of days (as defined by the enumeration for
  the `alerts.recurrence_days` column) into a string description.
  """

  @spec recurrence_text_from_days(list(String.t()) | list(atom())) :: String.t()
  def recurrence_text_from_days(nil), do: nil

  def recurrence_text_from_days([]), do: nil

  def recurrence_text_from_days(days) do
    case normalize_weekdays(days) do
      [1, 2, 3, 4, 5, 6, 7] ->
        "daily"

      [1, 2, 3, 4, 5] ->
        "weekdays"

      [6, 7] ->
        "weekends"

      [day] ->
        number_to_day_string(day) <> "s"

      days ->
        case day_range(days) do
          [first_day, last_day] ->
            [number_to_day_string(first_day), number_to_day_string(last_day)]
            |> Enum.join("-")

          nil ->
            "#{length(days)} days a week"
        end
    end
  end

  @spec normalize_weekdays(list(String.t()) | list(atom())) :: list(integer())
  defp normalize_weekdays(days) do
    days
    |> Enum.map(fn
      day when is_atom(day) -> day
      day -> String.to_existing_atom(String.downcase(day))
    end)
    |> Enum.map(&day_to_number/1)
    |> Enum.uniq()
    |> Enum.sort()
  end

  @spec day_range(list(integer()), integer() | nil, integer() | nil, integer() | nil) ::
          list(integer()) | nil
  defp day_range(days, start_day \\ nil, end_day \\ nil, next_start_day \\ nil)

  # First call of this function: use initial value as start_day
  defp day_range([day | rest], nil, _, _), do: day_range([day | rest], day, nil, nil)

  # First call, so this is the only value.
  defp day_range([day], start_day, _, _) when is_nil(start_day), do: [day, day]

  defp day_range([current, next | rest], start_day, end_day, next_start_day) do
    # More than one day in the list and...
    cond do
      # ... in sequence: continue with the next values.
      next - current == 1 ->
        day_range([next | rest], start_day, end_day, next_start_day)

      # ... break sequence: Not the first time, so Failure!
      next - current > 1 && next_start_day ->
        nil

      # ... break sequence: Maybe wrapping? Record and continue.
      next - current > 1 ->
        day_range([next | rest], start_day, current, next)
    end
  end

  defp day_range([7], start_day, end_day, next_start_day) do
    # On Sunday...
    cond do
      # ... and the sequence hasn't broken yet. All done!
      is_nil(end_day) ->
        [start_day, 7]

      # ... and sequence has broken once and does not wrap. Failure!
      end_day && start_day != 1 ->
        nil

      # ... and sequence has broken once, but wraps. All done!
      next_start_day && start_day == 1 ->
        [next_start_day, end_day]
    end
  end

  defp day_range([day], start_day, end_day, _) when day < 7 do
    # End of the list not on a Sunday...
    if is_nil(end_day) do
      # ... but the sequence hasn't broken. All done!
      [start_day, day]
    else
      # ... and the sequence has already broken once. Invalid!
      nil
    end
  end

  @spec day_to_number(atom()) :: integer()
  defp day_to_number(day_atom) do
    case day_atom do
      :monday -> 1
      :tuesday -> 2
      :wednesday -> 3
      :thursday -> 4
      :friday -> 5
      :saturday -> 6
      :sunday -> 7
    end
  end

  @spec number_to_day(integer()) :: atom()
  def number_to_day(day_number) do
    case day_number do
      1 -> :monday
      2 -> :tuesday
      3 -> :wednesday
      4 -> :thursday
      5 -> :friday
      6 -> :saturday
      7 -> :sunday
    end
  end

  @spec number_to_day(integer()) :: String.t()
  defp number_to_day_string(day_number) do
    day_number
    |> number_to_day()
    |> Atom.to_string()
    |> String.capitalize()
  end
end
