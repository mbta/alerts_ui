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
    :single_route_id,
    :stop_ids,
    :trip_ids,
    :header_text,
    :description_text,
    :banner_text,
    :view_banner,
    :banner_sync_toggle,
    :combination,
    :service_types,
    :cause_detail,
    :url,
    :image_url,
    :image_alternative_text,
    :notification_period_start,
    :notification_specifier,
    :severity,
    :reminder_times,
    :alert_data
  ]

  @type active_period_t :: %{
          active_period_start: NaiveDateTime.t() | nil,
          active_period_start_date: Date.t() | nil,
          active_period_start_time: Time.t() | nil,
          active_period_start_specifier: String.t() | nil,
          active_period_start_time_specifier: String.t() | nil,
          active_period_end: NaiveDateTime.t() | nil,
          active_period_end_date: Date.t() | nil,
          active_period_end_time: Time.t() | nil,
          active_period_end_specifier: String.t(),
          active_period_end_time_specifier: String.t() | nil,
          alert_timing: atom(),
          recurrence_days: [atom()] | nil
        }

  @type t :: %__MODULE__{
          route_type: Route.type_int(),
          direction: String.t(),
          facility_id: String.t(),
          route_ids: [String.t()],
          single_route_id: String.t(),
          stop_ids: [String.t()],
          trip_ids: [String.t()],
          header_text: String.t(),
          description_text: String.t(),
          banner_text: String.t() | nil,
          view_banner: boolean(),
          banner_sync_toggle: boolean(),
          combination: atom(),
          alert_data: active_period_t(),
          notification_specifier: String.t(),
          notification_period_start: NaiveDateTime.t() | nil,
          service_types: [Route.type_int()],
          cause_detail: String.t(),
          url: String.t() | nil,
          image_url: String.t() | nil,
          image_alternative_text: String.t() | nil,
          severity: integer() | nil,
          reminder_times: [NaiveDateTime.t()] | nil
        }

  def build_alert_data(nil), do: %__MODULE__{}

  def build_alert_data(alert_id) do
    alert = Alerts.get_by_alert_id(alert_id)
    effect_map = Effect.effect_map_by_detail(alert.effect_detail)
    informed_entities = alert.informed_entity
    route_type = Alert.get_route_type(alert)
    effect_name = alert.effect_name || Map.get(effect_map, :effect_name)

    combination =
      if is_nil(route_type) and
           effect_name in EffectsForRouteTypes.list_effects(:access) do
        :ACCESS
      else
        ServiceEffectCombinations.get_combination(route_type, effect_name)
      end

    reminder_times = Enum.map(alert.reminder_times, &shift_to_naive(&1.reminder_time))

    notification_period_start = shift_to_naive(alert.notification_period_start)

    notification_specifier =
      if is_nil(notification_period_start) do
        :same_as_effect_period
      else
        :custom
      end

    active_period_map =
      determine_active_period(alert)

    route_ids = alert.original_route_selections || []

    single_route_id = single_route_id(effect_name, route_ids)

    view_banner = if is_nil(alert.banner_text), do: false, else: true

    %__MODULE__{
      route_type: route_type,
      direction: Alert.get_direction(informed_entities) || "default",
      effect_name: effect_name,
      facility_id: Alert.gather_facility_ids(informed_entities) |> List.first(""),
      route_ids: route_ids,
      single_route_id: single_route_id,
      stop_ids: Alert.gather_parent_stop_ids(informed_entities),
      trip_ids: Alert.gather_trip_ids(informed_entities),
      header_text: alert.header_text,
      description_text: alert.description_text,
      combination: combination,
      service_types: Alert.service_types(alert),
      cause_detail: alert.cause_detail,
      url: alert.url,
      image_url: alert.image_url,
      image_alternative_text: alert.image_alternative_text,
      banner_text: alert.banner_text,
      view_banner: view_banner,
      banner_sync_toggle: !view_banner,
      notification_period_start: notification_period_start,
      notification_specifier: notification_specifier,
      severity: alert.severity,
      reminder_times: reminder_times
    }
    |> Map.put(:alert_data, active_period_map)
  end

  def single_route_id(effect_name, [route_id]) when effect_name === "Detour" do
    route_id
  end

  def single_route_id(_effect_name, _route_ids), do: nil

  def determine_active_period(%{active_period: [_active_period]} = alert) do
    # one time active period
    active_period_start = shift_to_naive(alert.active_period_start)
    active_period_end = shift_to_naive(alert.active_period_end)

    end_specifier =
      determine_end_specifier(
        active_period_end,
        alert.duration_certainty
      )

    %{
      alert_timing: "one-time",
      active_period_start: active_period_start,
      active_period_end: active_period_end(active_period_end, end_specifier),
      active_period_end_date: end_date(active_period_end, end_specifier),
      active_period_start_date: start_date(active_period_start),
      active_period_start_specifier: determine_start_specifier(active_period_start),
      active_period_end_specifier: end_specifier
    }
  end

  def determine_active_period(%{active_period: active_period} = alert) do
    # recurring active period
    start_datetime = hd(active_period).start |> shift_to_naive
    end_datetime = hd(active_period).end |> shift_to_naive
    end_specifier = if alert.active_period_end, do: "custom", else: "until_further_notice"

    %{
      alert_timing: "recurring",
      active_period_start_time_specifier: determine_start_specifier(start_datetime),
      active_period_end_time_specifier: determine_end_specifier(end_datetime, :KNOWN),
      active_period_start_specifier: "custom",
      active_period_end_specifier: end_specifier,
      active_period_start_time: start_datetime |> NaiveDateTime.to_time(),
      active_period_end_time: end_datetime |> NaiveDateTime.to_time(),
      active_period_start_date: start_datetime |> start_date,
      active_period_end_date: alert.active_period_end |> end_date(end_specifier),
      recurrence_days: alert.recurrence_days |> Enum.map(&Atom.to_string/1)
    }
  end

  def shift_to_naive(nil), do: nil

  def shift_to_naive(time) do
    time |> Timex.Timezone.convert("America/New_York") |> DateTime.to_naive()
  end

  def start_date(nil), do: nil
  def start_date(ap_start), do: NaiveDateTime.to_date(ap_start)

  def end_date(nil, _), do: nil
  def end_date(ap_end, "end_of_service"), do: ap_end |> NaiveDateTime.to_date() |> Date.add(-1)
  def end_date(ap_end, "later_today"), do: ap_end |> NaiveDateTime.to_date() |> Date.add(-1)
  def end_date(ap_end, _), do: ap_end |> NaiveDateTime.to_date()

  def active_period_end(nil, _), do: nil
  def active_period_end(ap_end, "end_of_service"), do: ap_end |> NaiveDateTime.add(-1, :day)
  def active_period_end(ap_end, _), do: ap_end

  def determine_start_specifier(nil), do: nil

  def determine_start_specifier(ap_start) do
    if ap_start |> NaiveDateTime.to_time() == ActivePeriod.start_of_service_time() do
      "start_of_service"
    else
      "custom"
    end
  end

  def determine_end_specifier(nil, nil), do: nil
  def determine_end_specifier(_ap_end, :ESTIMATED), do: "later_today"
  def determine_end_specifier(nil, :UNKNOWN), do: "until_further_notice"

  def determine_end_specifier(ap_end, :KNOWN) do
    if ap_end |> NaiveDateTime.to_time() == ActivePeriod.end_of_service_time() do
      "end_of_service"
    else
      "custom"
    end
  end
end
