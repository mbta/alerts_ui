defmodule AlertsUI.Models.ActivePeriod do
  @moduledoc """
    Model of JSONB active period field for Alerts
  """
  use AlertsUI.Schema

  @type t :: %__MODULE__{
          start_time: DateTime.t(),
          end_time: DateTime.t()
        }

  embedded_schema do
    field :start_time, :utc_datetime
    field :end_time, :utc_datetime
  end
end
