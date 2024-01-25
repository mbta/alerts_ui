defmodule AlertsUI.AlertBuilder do
  @moduledoc """
    Builds an alert from form data
  """
  alias AlertsUI.Alerts
  alias AlertsUI.Models.Effect

  def build_alert(alert_data) do
    effect_map = Effect.effect_map_by_name(Map.get(alert_data, :effect_name, nil))

    %{
      alert_id: (Alerts.get_max_alert_id() + 1) |> Integer.to_string(),
      header_text: Map.get(alert_data, :header_text),
      description_text: Map.get(alert_data, :description_text),
      effect: Map.get(effect_map, :effect),
      effect_detail: Map.get(effect_map, :effect_detail),
      informed_entity: build_informed_entities(alert_data)
    }
  end

  def build_informed_entities(alert_data) do
    %{
      route_type: Map.get(alert_data, :route_type)
    }
    |> List.wrap()
  end
end
