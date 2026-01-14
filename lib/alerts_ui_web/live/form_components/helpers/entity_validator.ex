defmodule AlertsUIWeb.FormComponents.Helpers.EntityValidator do
  @moduledoc """
  """

  # TODO special case for trips/schedules?
  def get_bad_ids([_ | _] = ids, %{ok?: true, result: available_entities})
      when not is_nil(available_entities) do
    available_ids = Enum.map(available_entities, & &1.id)

    Enum.reduce(ids, [], fn id, acc ->
      if id in available_ids do
        acc
      else
        [id | acc]
      end
    end)
  end

  def get_bad_ids(id, %{ok?: true, result: available_entities})
      when not is_nil(available_entities) do
    available_ids = Enum.map(available_entities, & &1.id)

    if id in available_ids do
      [id]
    else
      []
    end
  end

  def get_bad_ids(_, _), do: nil
end
