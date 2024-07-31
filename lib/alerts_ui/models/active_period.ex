defmodule AlertsUI.Models.ActivePeriod do
  @moduledoc """
    Model of JSONB active period field for Alerts.
    Requires at least one of start or end time to be valid.
  """
  use AlertsUI.Schema
  import Ecto.Changeset

  @start_of_service ~T[03:00:00]
  @end_of_service ~T[03:00:00]

  @type t :: %__MODULE__{
          start: DateTime.t() | nil,
          end: DateTime.t() | nil
        }

  embedded_schema do
    field :start, :utc_datetime
    field :end, :utc_datetime
  end

  def changeset(%__MODULE__{} = active_period, params) do
    case {Map.get(params, :start), Map.get(params, :end)} do
      {nil, nil} ->
        active_period
        |> cast(params, [:start, :end])
        |> add_error(:start, "requires at least one of start or end time")

      {_, _} ->
        cast(active_period, params, [:start, :end])
    end
  end

  @spec start_time_of_first_active_period([t()]) :: DateTime.t() | nil
  def start_time_of_first_active_period(active_periods) do
    case active_periods
         |> Enum.map(& &1.start)
         |> Enum.reject(&is_nil(&1)) do
      [] ->
        nil

      active_periods ->
        active_periods |> Enum.sort_by(& &1, {:asc, Date}) |> hd()
    end
  end

  @spec end_time_of_last_active_period([t()]) :: DateTime.t() | nil
  def end_time_of_last_active_period(active_periods) do
    case active_periods
         |> Enum.map(& &1.end)
         |> Enum.reject(&is_nil(&1)) do
      [] ->
        nil

      active_periods ->
        active_periods |> Enum.sort_by(& &1, {:desc, Date}) |> hd()
    end
  end

  @spec time_inside_active_period?(
          t(),
          DateTime.t()
        ) :: boolean()
  def time_inside_active_period?(active_period, time \\ DateTime.utc_now())

  def time_inside_active_period?(%{start: start, end: nil}, time) do
    DateTime.compare(time, start) == :gt
  end

  def time_inside_active_period?(%{start: nil, end: the_end}, time) do
    DateTime.compare(time, the_end) == :lt
  end

  def time_inside_active_period?(%{start: start, end: the_end}, time) do
    DateTime.compare(time, start) == :gt and DateTime.compare(time, the_end) == :lt
  end

  def start_of_service_time, do: @start_of_service
  def end_of_service_time, do: @end_of_service

  @spec end_of_service_date(DateTime.t(), Time.t()) :: Date.t()
  def end_of_service_date(start_time, end_of_service_time \\ @end_of_service) do
    # Sets the end date of the active period to the next instance of the "end of service" (eg 3:00 AM).
    # Checks if start time is after 3:00am (Eastern). If true, end date is the next day. If false, end date is same day.
    if Time.after?(DateTime.to_time(start_time), end_of_service_time) do
      Date.add(DateTime.to_date(start_time), 1)
    else
      DateTime.to_date(start_time)
    end
  end
end
