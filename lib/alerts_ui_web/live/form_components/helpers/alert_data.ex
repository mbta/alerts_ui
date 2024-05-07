defmodule AlertsUIWeb.FormComponents.Helpers.AlertData do
  @moduledoc """
  builds alert data from existing alert
  """
  alias AlertsUI.Alerts
  alias AlertsUI.Models.{Alert, Effect}
  alias AlertsUIWeb.FormComponents.Helpers.ServiceEffectCombinations
  alias MBTAV3API.Routes.Route

  defstruct [
    :route_type,
    :effect_name,
    :direction,
    :route_ids,
    :stop_ids,
    :trip_ids,
    :header_text,
    :description_text,
    :combination,
    :active_period_start,
    :active_period_end,
    :active_period_end_specifier,
    :service_types
  ]

  @type t :: %__MODULE__{
          route_type: Route.type_int(),
          direction: String.t(),
          route_ids: [String.t()],
          stop_ids: [String.t()],
          trip_ids: [String.t()],
          header_text: String.t(),
          description_text: String.t(),
          combination: atom(),
          active_period_start: NaiveDateTime.t(),
          active_period_end_specifier: atom(),
          active_period_end: NaiveDateTime.t(),
          service_types: [Route.type_int()]
        }

  @spec build_alert_data(nil | String.t()) :: t()
  def build_alert_data(nil), do: %__MODULE__{}

  def build_alert_data(alert_id) do
    alert = Alerts.get_by_alert_id(alert_id)
    effect_map = Effect.effect_map_by_detail(Map.get(alert, :effect_detail))
    informed_entities = Map.get(alert, :informed_entity, [])
    combination = ServiceEffectCombinations.get_combination(informed_entities)

    active_period_end = Map.get(alert, :active_period_end) |> shift_to_naive()

    %__MODULE__{
      route_type: Alert.get_route_type(alert),
      direction: Alert.get_direction(informed_entities),
      effect_name: Map.get(effect_map, :effect_name),
      route_ids: Alert.gather_route_ids(informed_entities),
      stop_ids: Alert.gather_parent_stop_ids(informed_entities),
      trip_ids: Alert.gather_trip_ids(informed_entities),
      header_text: Map.get(alert, :header_text),
      description_text: Map.get(alert, :description_text),
      combination: combination,
      active_period_start: Map.get(alert, :active_period_start) |> shift_to_naive(),
      active_period_end: active_period_end,
      active_period_end_specifier:
        determine_specifier(active_period_end, Map.get(alert, :duration_certainty)),
      service_types: Alert.service_types(alert)
    }
  end

  def shift_to_naive(nil), do: nil

  def shift_to_naive(time) do
    time |> Timex.Timezone.convert("America/New_York") |> DateTime.to_naive()
  end

  def determine_specifier(nil, nil), do: nil
  def determine_specifier(nil, :ESTIMATED), do: :later_today
  def determine_specifier(nil, :UNKNOWN), do: :further_notice

  def determine_specifier(ap_end, :KNOWN) when not is_nil(ap_end) do
    case NaiveDateTime.to_time(ap_end) == ~T[02:30:00] do
      true -> :end_of_service_today
      false -> :pick_a_date_and_time
    end
  end
end
