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
    :service_types,
    :cause_detail,
    :url,
    :image_url,
    :image_alternative_text
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
          active_period_start: NaiveDateTime.t() | nil,
          active_period_end_specifier: atom() | nil,
          active_period_end: NaiveDateTime.t() | nil,
          service_types: [Route.type_int()],
          cause_detail: String.t(),
          url: String.t() | nil,
          image_url: String.t() | nil,
          image_alternative_text: String.t() | nil
        }

  @spec build_alert_data(nil | String.t()) :: t()
  def build_alert_data(nil), do: %__MODULE__{}

  def build_alert_data(alert_id) do
    alert = Alerts.get_by_alert_id(alert_id)
    effect_map = Effect.effect_map_by_detail(alert.effect_detail)
    informed_entities = alert.informed_entity
    route_type = Alert.get_route_type(alert)
    effect_name = Map.get(effect_map, :effect_name)
    combination = ServiceEffectCombinations.get_combination(route_type, effect_name)
    active_period_end = shift_to_naive(alert.active_period_end)

    %__MODULE__{
      route_type: route_type,
      direction: Alert.get_direction(informed_entities),
      effect_name: effect_name,
      route_ids: Alert.gather_route_ids(informed_entities),
      stop_ids: Alert.gather_parent_stop_ids(informed_entities),
      trip_ids: Alert.gather_trip_ids(informed_entities),
      header_text: alert.header_text,
      description_text: alert.description_text,
      combination: combination,
      active_period_start: shift_to_naive(alert.active_period_start),
      active_period_end: active_period_end,
      active_period_end_specifier:
        determine_specifier(active_period_end, alert.duration_certainty, alert.active_period_start),
      service_types: Alert.service_types(alert),
      cause_detail: alert.cause_detail,
      url: alert.url,
      image_url: alert.image_url,
      image_alternative_text: alert.image_alternative_text
    }
  end

  def shift_to_naive(nil), do: nil

  def shift_to_naive(time) do
    time |> Timex.Timezone.convert("America/New_York") |> DateTime.to_naive()
  end

  def determine_specifier(nil, nil, _ap_start), do: nil
  def determine_specifier(nil, :ESTIMATED, _ap_start), do: :later_today
  def determine_specifier(nil, :UNKNOWN, _ap_start), do: :further_notice
  def determine_specifier(ap_end, :KNOWN, ap_start) when not is_nil(ap_end) do
    end_is_at_end_of_service = Time.compare(NaiveDateTime.to_time(ap_end), ~T[02:30:00]) == :eq
    less_than_a_day_apart = NaiveDateTime.diff(ap_end, ap_start, :hour) <= 24
    case end_is_at_end_of_service and less_than_a_day_apart do
      true -> :end_of_service_today
      false -> :pick_a_date_and_time
    end
  end
end
