defmodule AlertsUIWeb.CreateAlertLive.Helpers.EntityValidator do
  @moduledoc """
    Takes in an id or list of ids, and an AsyncResult containing
    a list of entities in the result. Returns list of IDs not found
    in the result.
  """

  @spec get_obsolete_ids(list() | nil, map()) :: list() | nil
  def get_obsolete_ids(nil, _available_entities) do
    []
  end

  def get_obsolete_ids(id, available_entities) when is_binary(id) do
    get_obsolete_ids(List.wrap(id), available_entities)
  end

  def get_obsolete_ids(_ids, %{result: nil}), do: nil

  def get_obsolete_ids(ids, %{ok?: true, result: available_entities}) do
    get_obsolete_ids(ids, available_entities)
  end

  def get_obsolete_ids(ids, available_entities)
      when not is_nil(available_entities) and is_list(ids) do
    available_ids = Enum.map(available_entities, &get_entity_id/1)

    Enum.reduce(ids, [], fn id, acc ->
      if id in available_ids do
        acc
      else
        [id | acc]
      end
    end)
  end

  def get_obsolete_ids(_, _), do: nil

  def get_entity_id(%{trip: %{id: id}}), do: id

  def get_entity_id(%{id: id}), do: id
end
