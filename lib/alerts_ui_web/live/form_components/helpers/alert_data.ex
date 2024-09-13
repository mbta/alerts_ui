defmodule AlertsUIWeb.FormComponents.Helpers.AlertData do
  @moduledoc """
  Builds alert data from existing alert
  Used to populate form when editing an alert
  """
  alias AlertsUI.Alerts
  alias AlertsUI.Models.{ActivePeriod, Alert, Effect}

  alias AlertsUIWeb.FormComponents.Helpers.{
    EffectsForRouteTypes,
    ServiceEffectCombinations
  }

  alias MBTAV3API.Routes.Route

  defstruct [
    :route_type,
    :effect_name,
    :direction,
    :facility_id,
    :route_ids,
    :stop_ids,
    :trip_ids,
    :header_text,
    :description_text,
    :banner_text,
    :combination,
    :active_period_start,
    :active_period_end,
    :active_period_end_specifier,
    :service_types,
    :cause_detail,
    :url,
    :image_url,
    :image_alternative_text,
    :notification_period_start
    :severity
  ]

  @type t :: %__MODULE__{
          route_type: Route.type_int(),
          direction: String.t(),
          facility_id: String.t(),
          route_ids: [String.t()],
          stop_ids: [String.t()],
          trip_ids: [String.t()],
          header_text: String.t(),
          description_text: String.t(),
          banner_text: String.t() | nil,
          combination: atom(),
          active_period_start: NaiveDateTime.t() | nil,
          active_period_end_specifier: atom() | nil,
          active_period_end: NaiveDateTime.t() | nil,
          service_types: [Route.type_int()],
          cause_detail: String.t(),
          url: String.t() | nil,
          image_url: String.t() | nil,
          image_alternative_text: String.t() | nil,
          notification_period_start: NaiveDateTime.t() | nil
          severity: integer() | nil
        }

  @spec build_alert_data(nil | String.t()) :: t()
  def build_alert_data(nil), do: %__MODULE__{}

  def build_alert_data(alert_id) do
    alert = Alerts.get_by_alert_id(alert_id)
    effect_map = Effect.effect_map_by_detail(alert.effect_detail)
    informed_entities = alert.informed_entity
    route_type = Alert.get_route_type(alert)
    effect_name = Map.get(effect_map, :effect_name)

    combination =
      if is_nil(route_type) and
           effect_name in EffectsForRouteTypes.list_effects("Access") do
        :ACCESS
      else
        ServiceEffectCombinations.get_combination(route_type, effect_name)
      end

    active_period_end = shift_to_naive(alert.active_period_end)

    %__MODULE__{
      route_type: route_type,
      direction: Alert.get_direction(informed_entities),
      effect_name: effect_name,
      facility_id: Alert.gather_facility_ids(informed_entities) |> List.first(""),
      route_ids: Alert.gather_route_ids(informed_entities),
      stop_ids: Alert.gather_parent_stop_ids(informed_entities),
      trip_ids: Alert.gather_trip_ids(informed_entities),
      header_text: alert.header_text,
      description_text: alert.description_text,
      combination: combination,
      active_period_start: shift_to_naive(alert.active_period_start),
      active_period_end: active_period_end,
      active_period_end_specifier:
        determine_specifier(
          active_period_end,
          alert.duration_certainty,
          alert.active_period_start
        ),
      service_types: Alert.service_types(alert),
      cause_detail: alert.cause_detail,
      url: alert.url,
      image_url: alert.image_url,
      image_alternative_text: alert.image_alternative_text,
      banner_text: alert.banner_text,
      notification_period_start: shift_to_naive(alert.notification_period_start)
      severity: alert.severity
    }
  end

  def shift_to_naive(nil), do: nil

  def shift_to_naive(time) do
    time |> Timex.Timezone.convert("America/New_York") |> DateTime.to_naive()
  end

  def determine_specifier(nil, nil, _ap_start), do: nil
  def determine_specifier(_ap_end, :ESTIMATED, _ap_start), do: :later_today
  def determine_specifier(nil, :UNKNOWN, _ap_start), do: :until_further_notice

  def determine_specifier(ap_end, :KNOWN, ap_start) when not is_nil(ap_end) do
    end_is_at_end_of_service =
      Time.compare(NaiveDateTime.to_time(ap_end), ActivePeriod.end_of_service_time()) == :eq

    less_than_a_day_apart = NaiveDateTime.diff(ap_end, ap_start, :hour) <= 24

    case end_is_at_end_of_service and less_than_a_day_apart do
      true -> :end_of_service_today
      false -> :custom
    end
  end
end
