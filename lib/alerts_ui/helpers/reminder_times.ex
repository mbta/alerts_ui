defmodule AlertsUI.Helpers.ReminderTimes do
  @moduledoc """
  Helper functions for dealing with ReminderTimes
  """

  @spec editable?(String.t() | nil, NaiveDateTime.t() | nil, NaiveDateTime.t()) :: true | false
  def editable?(nil, _, _), do: true
  def editable?("", _, _), do: true
  def editable?(_, nil, _), do: true
  def editable?(_, "", _), do: true

  def editable?(id, %NaiveDateTime{} = reminder_time, current_time) do
    if is_binary(id) and String.starts_with?(id, "new-") do
      true
    else
      NaiveDateTime.compare(reminder_time, current_time) == :gt
    end
  end

  def editable?(id, reminder_time, current_time) when is_binary(reminder_time) do
    case NaiveDateTime.from_iso8601(reminder_time) do
      {:ok, dt} -> editable?(id, dt, current_time)
      {:error, _} -> true
    end
  end

  @spec sent?(NaiveDateTime.t(), NaiveDateTime.t()) :: true | false
  def sent?(reminder_time, current_time) do
    NaiveDateTime.compare(reminder_time, current_time) == :lt
  end
end
