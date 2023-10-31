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
        cast(active_period, params, [:start, :end])
        |> add_error(:start, "requires at least one of start or end time")

      {_, _} ->
        cast(active_period, params, [:start, :end])
    end
  end
end
