defmodule AlertsUIWeb.FormComponents.Helpers.AlertData do
  @moduledoc """
  builds alert data from existing alert
  """
  alias AlertsUI.Alerts
  alias AlertsUI.Models.Effect
  alias AlertsUIWeb.FormComponents.Helpers.CombinationFromInformedEntity

  defstruct [
    :route_type,
    :effect_name,
    :direction,
    :route_ids,
    :stop_ids,
    :trip_ids,
    :header_text,
    :description_text,
    :combination
  ]

  @type t :: %__MODULE__{
          route_type: integer(),
          direction: String.t(),
          route_ids: [String.t()],
          stop_ids: [String.t()],
          trip_ids: [String.t()],
          header_text: String.t(),
          description_text: String.t(),
          combination: atom()
        }

  def build_alert_data(nil), do: %{}

  def build_alert_data(alert_id) do
    alert = Alerts.get_by_alert_id(alert_id)
    effect_map = Effect.effect_map_by_detail(Map.get(alert, :effect_detail))
    informed_entities = Map.get(alert, :informed_entity, [])
    combination = CombinationFromInformedEntity.get_combination(informed_entities)

    %__MODULE__{
      route_type: get_route_type(informed_entities),
      effect_name: Map.get(effect_map, :effect_name),
      route_ids: gather_route_ids(informed_entities),
      stop_ids: gather_stop_ids(informed_entities),
      trip_ids: gather_trip_ids(informed_entities),
      header_text: Map.get(alert, :header_text),
      description_text: Map.get(alert, :description_text),
      combination: combination
    }
  end

  defp get_route_type([]), do: nil

  defp get_route_type(informed_entities) do
    case Enum.any?(informed_entities, &(&1.route_type in [0, 1])) do
      true -> 1
      false -> hd(informed_entities).route_type
    end
  end

  defp gather_route_ids(informed_entities) do
    informed_entities
    |> Enum.map(&Map.get(&1, :route_id))
    |> Enum.filter(&(!is_nil(&1)))
    |> Enum.uniq()
  end

  defp gather_stop_ids(informed_entities) do
    informed_entities
    |> Enum.map(&Map.get(&1, :stop_id))
    |> Enum.filter(&(!is_nil(&1)))
    |> Enum.uniq()
  end

  defp gather_trip_ids(informed_entities) do
    informed_entities
    |> Enum.map(fn ie ->
      case Map.get(ie, :trip) do
        nil -> nil
        trip -> Map.get(trip, :trip_id)
      end
    end)
    |> Enum.filter(&(!is_nil(&1)))
    |> Enum.uniq()
  end
end
