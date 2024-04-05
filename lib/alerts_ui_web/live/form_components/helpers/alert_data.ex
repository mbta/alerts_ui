defmodule AlertsUIWeb.FormComponents.Helpers.AlertData do
  @moduledoc """
  builds alert data from existing alert
  """
  alias AlertsUI.Alerts
  alias AlertsUI.Models.{Alert, Effect}
  alias AlertsUIWeb.FormComponents.Helpers.ServiceEffectCombinations

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

  @spec build_alert_data(nil | String.t()) :: t()
  def build_alert_data(nil), do: %__MODULE__{}

  def build_alert_data(alert_id) do
    alert = Alerts.get_by_alert_id(alert_id)
    effect_map = Effect.effect_map_by_detail(Map.get(alert, :effect_detail))
    informed_entities = Map.get(alert, :informed_entity, [])
    combination = ServiceEffectCombinations.get_combination(informed_entities)

    %__MODULE__{
      route_type: Alert.get_route_type(informed_entities),
      direction: Alert.get_direction(informed_entities),
      effect_name: Map.get(effect_map, :effect_name),
      route_ids: Alert.gather_route_ids(informed_entities),
      stop_ids: Alert.gather_stop_ids(informed_entities),
      trip_ids: Alert.gather_trip_ids(informed_entities),
      header_text: Map.get(alert, :header_text),
      description_text: Map.get(alert, :description_text),
      combination: combination
    }
  end
end
