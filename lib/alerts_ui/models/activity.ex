defmodule AlertsUI.Models.Activity do
  @moduledoc """
    Activities to be used in the activity field of Informed Entity
  """

  @type activity :: atom()

  @doc """
  Returns list of atoms allowed in activities field of Informed Entity

  ## Examples
      iex> is_list(AlertsUI.Models.Activity.activities)
      true
  """
  def activities,
    do: [
      :BOARD,
      :EXIT,
      :RIDE,
      :USING_ESCALATOR,
      :USING_WHEELCHAIR,
      :BRINGING_BIKE,
      :STORE_BIKE,
      :PARK_CAR
    ]
end
