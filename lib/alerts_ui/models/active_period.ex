defmodule AlertsUI.Models.ActivePeriod do
  @moduledoc """
    Model of JSONB active period field for Alerts
  """
  use AlertsUI.Schema

  @type t :: %__MODULE__{
          start: DateTime.t(),
          end: DateTime.t()
        }

  embedded_schema do
    field :start, :utc_datetime
    field :end, :utc_datetime
  end
end
