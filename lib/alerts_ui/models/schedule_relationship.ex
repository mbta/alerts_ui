defmodule AlertsUI.Models.ScheduleRelationship do
  @moduledoc """
    Causes to be used in the schedule relationship field of Trip Descriptor
  """
  def schedule_relationships,
    do: [
      :SCHEDULED,
      :ADDED,
      :UNSCHEDULED,
      :CANCELED
    ]
end
