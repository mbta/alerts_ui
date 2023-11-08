defmodule AlertsUI.Models.ActivePeriod do
  @moduledoc """
    Model of JSONB active period field for Alerts.
    Requires at least one of start or end time to be valid.
  """
  use AlertsUI.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          start: DateTime.t() | nil,
          end: DateTime.t() | nil
        }

  embedded_schema do
    field :start, :utc_datetime
    field :end, :utc_datetime
  end

  def changeset(%__MODULE__{} = active_period, params \\ %{}) do
    case {Map.get(params, :start), Map.get(params, :end)} do
      {nil, nil} ->
        active_period
        |> cast(params, [:start, :end])
        |> add_error(:start, "requires at least one of start or end time")

      {_, _} ->
        cast(active_period, params, [:start, :end])
    end
  end

  @spec is_time_inside_active_period?(
          %{
            :end => DateTime.t() | nil,
            :start => DateTime.t() | nil
          },
          DateTime.t()
        ) :: boolean()
  def is_time_inside_active_period?(active_period, time \\ DateTime.utc_now())

  def is_time_inside_active_period?(%{start: start, end: nil}, time) do
    DateTime.compare(time, start) == :gt
  end

  def is_time_inside_active_period?(%{start: nil, end: the_end}, time) do
    DateTime.compare(time, the_end) == :lt
  end

  def is_time_inside_active_period?(%{start: start, end: the_end}, time) do
    DateTime.compare(time, start) == :gt and DateTime.compare(time, the_end) == :lt
  end
end
