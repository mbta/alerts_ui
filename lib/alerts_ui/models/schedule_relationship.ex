defmodule AlertsUI.Models.ScheduleRelationship do
  @moduledoc """
    Causes to be used in the schedule relationship field of Trip Descriptor
  """

  @doc """
  Returns list of atoms allowed in schedule relationship field of Trip Descriptor

  ## Examples
      iex> is_list(AlertsUI.Models.ScheduleRelationship.schedule_relationships)
      true
  """
  def schedule_relationships,
    do: [
      :SCHEDULED,
      :ADDED,
      :UNSCHEDULED,
      :CANCELED
    ]
end
