defmodule AlertsUI.Helpers.ReminderTimes do
  @moduledoc """
  Helper functions for dealing with ReminderTimes
  """

  alias AlertsUI.ActivePeriodBuilder

  @spec editable?(String.t() | nil, NaiveDateTime.t() | nil) :: true | false
  def editable?(nil, _), do: true
  def editable?("", _), do: true
  def editable?(_, nil), do: true
  def editable?(_, ""), do: true

  def editable?(id, %NaiveDateTime{} = reminder_time) do
    if is_binary(id) and String.starts_with?(id, "new-") do
      true
    else
      reminder_time
      |> ActivePeriodBuilder.naive_eastern_datetime_to_utc()
      |> Kernel.||(~N[2999-01-01T00:00:00])
      |> DateTime.compare(DateTime.utc_now()) == :gt
    end
  end

  def editable?(id, reminder_time) when is_binary(reminder_time) do
    case NaiveDateTime.from_iso8601(reminder_time) do
      {:ok, dt} -> editable?(id, dt)
      {:error, _} -> true
    end
  end

  @spec sent?(NaiveDateTime.t()) :: true | false
  def sent?(reminder_time) do
    reminder_time
    |> ActivePeriodBuilder.naive_eastern_datetime_to_utc()
    |> DateTime.compare(DateTime.utc_now()) == :lt
  end
end
