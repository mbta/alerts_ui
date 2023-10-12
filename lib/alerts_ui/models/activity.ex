defmodule AlertsUI.Models.Activity do
  @moduledoc """
    Causes to be used in the activity field of Informed Entity
  """
  def activities,
    do: [
      "BOARD",
      "EXIT",
      "RIDE",
      "USING_ESCALATOR",
      "USING_WHEELCHAIR",
      "BRINGING_BIKE",
      "STORE_BIKE",
      "PARK_CAR"
    ]
end
