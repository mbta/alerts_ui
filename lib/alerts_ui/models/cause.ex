defmodule AlertsUI.Models.Cause do
  @moduledoc """
    Causes to be used in the cause field of Alerts
  """
  use AlertsUI.Schema

  @type t :: %__MODULE__{
          name: String.t()
        }

  schema "causes" do
    field :name, :string
    timestamps()
  end
end
