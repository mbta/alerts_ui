defmodule AlertsUI.Models.ExtendedTime do
  @moduledoc """
  ExtendedTime schema is for saving GTFS timefields that can extend into the next day. Eg, a time field can be "25:30:30",
  which means 1:30AM the day after the schedule day. To account for this, there is a "relative day" field, which is 1 for
  the same day and 2 for the next day. The time field is then "normalized" (eg to "01:30:30") so it can be stored as
  a valid time type.
  """
  use AlertsUI.Schema
  import Ecto.Changeset
  alias AlertsUI.Models.ExtendedTime

  @type t :: %__MODULE__{
          relative_day: 1 | 2,
          time: Time.t()
        }

  embedded_schema do
    field :relative_day, :integer
    field :time, :time
  end

  def changeset(%__MODULE__{} = ex_time, params \\ %{}) do
    cast(ex_time, params, [:relative_day, :time])
  end

  @doc """
  Builds an ExtendedTime struct from a time string. If the time string has an hour greater than 23,
  the relative day will be 2 and the hour will be H - 24. Otherwise, the relative day is 1 and the time string
  is parsed unchanged.

  ## Examples
      iex> AlertsUI.Models.ExtendedTime.new("15:15:35")
      %AlertsUI.Models.ExtendedTime{relative_day: 1, time: ~T[15:15:35]}

      iex> AlertsUI.Models.ExtendedTime.new("25:15:35")
      %AlertsUI.Models.ExtendedTime{relative_day: 2, time: ~T[01:15:35]}
  """
  @spec new(String.t() | nil) :: t | nil
  def new(nil), do: nil

  def new(base_time) do
    case Time.from_iso8601(base_time) do
      {:ok, parsed_time} ->
        %ExtendedTime{
          relative_day: 1,
          time: parsed_time
        }

      {:error, :invalid_time} ->
        %ExtendedTime{
          relative_day: 2,
          time: normalized_time(base_time)
        }
    end
  end

  @doc """
    Given a time string, gives back Time type with hours mod 24 of the original, minutes and seconds unchanged.
    iex> AlertsUI.Models.ExtendedTime.normalized_time("00:14:45")
    ~T[00:14:45]
    iex> AlertsUI.Models.ExtendedTime.normalized_time("13:16:45")
    ~T[13:16:45]
    iex> AlertsUI.Models.ExtendedTime.normalized_time("24:17:45")
    ~T[00:17:45]
    iex> AlertsUI.Models.ExtendedTime.normalized_time("25:15:35")
    ~T[01:15:35]
  """

  @spec normalized_time(String.t()) :: Time.t()
  def normalized_time(base_time) do
    [base_hours, minutes, seconds] =
      base_time |> String.split(":") |> Enum.map(&String.to_integer(&1))

    Time.new!(rem(base_hours, 24), minutes, seconds)
  end

  @doc """
  Compares two ExtendedTime structs.

  Returns :gt if first date is later than the second and :lt for vice versa. If the two dates are equal :eq is returned.

  ## Examples

      iex> x = AlertsUI.Models.ExtendedTime.new("23:00:00")
      iex> y = AlertsUI.Models.ExtendedTime.new("24:30:00")
      iex> z = AlertsUI.Models.ExtendedTime.new("25:00:00")
      iex> AlertsUI.Models.ExtendedTime.compare(x, y)
      :lt
      iex> AlertsUI.Models.ExtendedTime.compare(y, x)
      :gt
      iex> AlertsUI.Models.ExtendedTime.compare(y, z)
      :lt
      iex> AlertsUI.Models.ExtendedTime.compare(z, y)
      :gt
      iex> AlertsUI.Models.ExtendedTime.compare(z, z)
      :eq
  """
  @spec compare(t, t) :: :lt | :eq | :gt
  def compare(%ExtendedTime{relative_day: relative_day_a}, %ExtendedTime{
        relative_day: relative_day_b
      })
      when relative_day_a < relative_day_b,
      do: :lt

  def compare(%ExtendedTime{relative_day: relative_day_a}, %ExtendedTime{
        relative_day: relative_day_b
      })
      when relative_day_a > relative_day_b,
      do: :gt

  def compare(%ExtendedTime{time: time_a}, %ExtendedTime{time: time_b}),
    do: Time.compare(time_a, time_b)
end
