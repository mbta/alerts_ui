defmodule AlertsUIWeb.FormComponents.Helpers.CombinationFromInformedEntity do
  @moduledoc """
  infers combination needed from informed entity of existing alerts
  used in alert editing
  """

  @spec get_combination(list()) :: atom()
  def get_combination([]), do: nil

  def get_combination(informed_entity) do
    informed_entity
    |> Enum.reduce([R: false, D: false, T: false, S: false], fn ie, acc ->
      [
        R: Map.get(ie, :route_id, false) || acc[:R],
        D: Map.get(ie, :direction_id, false) || acc[:D],
        T: Map.get(ie, :trip, false) || acc[:T],
        S: Map.get(ie, :stop_id, false) || acc[:S]
      ]
    end)
    |> Enum.filter(fn {_k, v} -> v end)
    |> Enum.map_join(fn {k, _v} -> k end)
    |> String.to_atom()
    |> case do
      :RS -> :SR
      other -> other
    end
  end
end
