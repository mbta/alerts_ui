defmodule AlertsUI.Models.ActivePeriod do
  @moduledoc """
    Model of JSONB active period field for Alerts
  """
  use AlertsUI.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          start: DateTime.t(),
          end: DateTime.t()
        }

  embedded_schema do
    field :start, :utc_datetime
    field :end, :utc_datetime
  end

  def changeset(%__MODULE__{} = active_period, params \\ %{}) do
    cast(active_period, params, [:start, :end])
    |> validate_required([:start, :end])
  end
end
