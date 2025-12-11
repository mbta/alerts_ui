defmodule AlertsUIWeb.FormComponents.Helpers.AlertData do
  @moduledoc """
  Builds alert data from existing alert
  Used to populate form when editing an alert
  Can take an Alert struct or an alert_id
  """

  alias AlertsUI.Alerts
  alias AlertsUI.Models.{ActivePeriod, Alert, Effect}

  alias AlertsUIWeb.FormComponents.Helpers.ServiceEffectCombinations

  alias MBTAV3API.Routes.Route

  defstruct [
    :active_period_end,
    :active_period_end_date,
    :active_period_end_specifier,
    :active_period_end_time,
    :active_period_end_time_specifier,
    :active_period_start,
    :active_period_start_date,
    :active_period_start_specifier,
    :active_period_start_time,
    :active_period_start_time_specifier,
    :alert_timing,
    :banner_text,
    :banner_sync_toggle,
    :cause_detail,
    :combination,
    :created_at,
    :created_by,
    :description_text,
    :direction,
    :effect_name,
    :facility_id,
    :header_text,
    :image_alternative_text,
    :image_url,
    :last_edited_at,
    :last_edited_by,
    :notification_period_start,
    :notification_period_end,
    :notification_specifier,
    :original_route_selections,
    :original_stop_selections,
    :original_trip_selections,
    :original_direction_selections,
    :original_facility_selections,
    :recurrence_days,
    :reminder_times,
    :route_ids,
    :route_type,
    :route_types_by_id,
    :service_types,
    :severity,
    :single_route_id,
    :stop_ids,
    :stop_names_and_ids,
    :trip_ids,
    :url,
    :last_push_notification_timestamp
  ]

  @type t :: %__MODULE__{
          active_period_end: NaiveDateTime.t() | nil,
          active_period_end_date: Date.t() | nil,
          active_period_end_specifier: String.t() | nil,
          active_period_end_time: Time.t() | nil,
          active_period_end_time_specifier: String.t() | nil,
          active_period_start: NaiveDateTime.t() | nil,
          active_period_start_date: Date.t() | nil,
          active_period_start_specifier: String.t() | nil,
          active_period_start_time: Time.t() | nil,
          active_period_start_time_specifier: String.t() | nil,
          alert_timing: atom() | nil,
          banner_text: String.t() | nil,
          cause_detail: String.t() | nil,
          combination: atom() | nil,
          created_at: DateTime.t() | nil,
          created_by: String.t() | nil,
          description_text: String.t() | nil,
          direction: String.t() | nil,
          effect_name: String.t() | nil,
          facility_id: String.t() | nil,
          header_text: String.t() | nil,
          image_alternative_text: String.t() | nil,
          image_url: String.t() | nil,
          last_edited_at: DateTime.t() | nil,
          last_edited_by: String.t() | nil,
          notification_period_start: NaiveDateTime.t() | nil,
          notification_period_end: NaiveDateTime.t() | nil,
          notification_specifier: atom() | nil,
          original_route_selections: [String.t()] | nil,
          original_stop_selections: [String.t()] | nil,
          original_trip_selections: [String.t()] | nil,
          original_direction_selections: [String.t()] | nil,
          original_facility_selections: [String.t()] | nil,
          recurrence_days: [atom()] | nil,
          reminder_times: [NaiveDateTime.t()] | nil,
          route_ids: [String.t()] | nil,
          route_type: Route.type_int() | nil,
          route_types_by_id: map() | nil,
          service_types: [Route.type_int()] | nil,
          severity: integer() | nil,
          single_route_id: String.t() | nil,
          stop_ids: [String.t()] | nil,
          stop_names_and_ids: [String.t()] | nil,
          trip_ids: [String.t()] | nil,
          url: String.t() | nil,
          last_push_notification_timestamp: DateTime.t() | nil
        }

  @spec build_alert_data(String.t() | Alert.t() | nil) :: t()
  def build_alert_data(alert_id) when is_binary(alert_id) do
    alert = alert_id |> Alerts.get_by_alert_id()

    if Map.get(alert, :id) == nil do
      build_alert_data(nil)
    else
      build_alert_data(alert)
    end
  end

  def build_alert_data(%AlertsUI.Models.Alert{} = alert) do
    direct_from_alert_keys = [
      :created_at,
      :banner_text,
      :cause_detail,
      :description_text,
      :header_text,
      :image_alternative_text,
      :image_url,
      :severity,
      :url,
      :last_push_notification_timestamp,
      :original_route_selections,
      :original_trip_selections,
      :original_stop_selections,
      :original_direction_selections,
      :original_facility_selections
    ]

    Enum.reduce(direct_from_alert_keys, %__MODULE__{}, fn key, params ->
      Map.put(params, key, Map.get(alert, key))
    end)
    |> Map.merge(create_and_edit_metadata(alert))
    |> Map.merge(effect_name_combination_and_informed_entities(alert))
    |> Map.merge(active_period_map(alert))
    |> Map.merge(reminder_times(alert))
    |> Map.merge(notification_period(alert))
    |> Map.merge(service_types(alert))
    |> Map.merge(banner_sync_toggle(alert))
  end

  def build_alert_data(_), do: %__MODULE__{}

  defp create_and_edit_metadata(alert) do
    created_by =
      alert.id
      |> Alerts.get_earliest_version()
      |> Alerts.get_originator_string()
      |> originator_fallback()

    last_edited_by =
      alert.id
      |> Alerts.get_latest_version()
      |> Alerts.get_originator_string()
      |> originator_fallback()

    %{
      created_by: created_by,
      last_edited_by: last_edited_by,
      last_edited_at: alert.last_modified_timestamp
    }
  end

  defp effect_name_combination_and_informed_entities(alert) do
    effect_name =
      case Map.get(alert, :effect_name) do
        nil ->
          alert.effect_detail
          |> Effect.effect_map_by_detail()
          |> Map.get(:effect_name)

        effect_name ->
          effect_name
      end

    primary_service_type = Map.get(alert, :primary_service_type)
    route_type = get_route_type(primary_service_type)

    combination =
      if primary_service_type == "access" do
        :ACCESS
      else
        ServiceEffectCombinations.get_combination(route_type, effect_name)
      end

    route_ids = Alert.get_original_ids(alert.original_route_selections || [])

    single_route_id =
      if alert.effect_name == "Detour" and length(route_ids) === 1 do
        hd(route_ids)
      else
        nil
      end

    route_type = get_route_type(Map.get(alert, :primary_service_type))

    %{
      combination: combination,
      effect_name: effect_name,
      direction: Alert.get_direction(alert.informed_entity) || "default",
      facility_id: Alert.gather_facility_ids(alert.informed_entity) |> List.first(),
      route_ids: route_ids,
      route_type: route_type,
      route_types_by_id: route_types_by_id(combination, route_type, route_ids),
      single_route_id: single_route_id,
      stop_ids: Alert.gather_parent_stop_ids(alert.informed_entity),
      stop_names_and_ids: alert.original_stop_selections,
      trip_ids: Alert.gather_trip_ids(alert.informed_entity)
    }
  end

  defp active_period_map(alert) do
    if alert.recurrence_days && !Enum.empty?(alert.recurrence_days) do
      determine_recurring_active_period(alert)
    else
      determine_one_time_active_period(alert)
    end
  end

  defp reminder_times(alert) do
    %{
      reminder_times: Enum.map(alert.reminder_times, &shift_to_naive(&1.reminder_time))
    }
  end

  defp notification_period(alert) do
    notification_period_start = shift_to_naive(alert.notification_period_start)
    notification_period_end = shift_to_naive(alert.notification_period_end)
    notification_specifier = get_notification_specifier(notification_period_start)

    %{
      notification_period_start: notification_period_start,
      notification_period_end: notification_period_end,
      notification_specifier: notification_specifier
    }
  end

  defp service_types(alert), do: %{service_types: Alert.service_types(alert)}

  defp banner_sync_toggle(alert) do
    %{banner_sync_toggle: is_nil(alert.banner_text)}
  end

  def determine_one_time_active_period(alert) do
    shifted_active_period_start = shift_to_naive(alert.active_period_start)

    # use notification_period_end for "later today" alerts because
    # their active period ends are only 2 hours out.
    shifted_active_period_end =
      if alert.duration_certainty == :ESTIMATED do
        shift_to_naive(alert.notification_period_end)
      else
        shift_to_naive(alert.active_period_end)
      end

    end_specifier =
      determine_end_specifier(
        shifted_active_period_end,
        alert.duration_certainty
      )

    %{
      alert_timing: :"one-time",
      active_period_start: shifted_active_period_start,
      active_period_end: shifted_active_period_end,
      active_period_end_date: end_date(shifted_active_period_end, end_specifier),
      active_period_start_date: start_date(shifted_active_period_start),
      active_period_start_specifier: determine_start_specifier(shifted_active_period_start),
      active_period_end_specifier: end_specifier
    }
  end

  def determine_recurring_active_period(%{active_period: active_period} = alert) do
    shifted_active_period_start = shift_to_naive(alert.active_period_start)
    shifted_active_period_end = shift_to_naive(alert.active_period_end)

    [start_datetime, end_datetime] =
      if active_period && !Enum.empty?(active_period) do
        [
          List.first(active_period).start |> shift_to_naive(),
          List.last(active_period).end |> shift_to_naive()
        ]
      else
        [shifted_active_period_start, shifted_active_period_end]
      end

    end_specifier = if alert.active_period_end, do: "custom", else: "until_further_notice"

    [recurrence_start_time, recurrence_end_time] =
      [
        Map.get(alert, :recurrence_start_time) || NaiveDateTime.to_time(start_datetime),
        Map.get(alert, :recurrence_end_time) || NaiveDateTime.to_time(end_datetime)
      ]

    %{
      alert_timing: :recurring,
      active_period_start: shifted_active_period_start,
      active_period_end: shifted_active_period_end,
      active_period_start_time_specifier: determine_start_specifier(start_datetime),
      active_period_end_time_specifier: determine_end_specifier(end_datetime, :KNOWN),
      active_period_start_specifier: "custom",
      active_period_end_specifier: end_specifier,
      active_period_start_time: recurrence_start_time,
      active_period_end_time: recurrence_end_time,
      active_period_start_date: start_datetime |> start_date,
      active_period_end_date:
        alert.active_period_end |> shift_to_naive |> end_date(end_specifier),
      recurrence_days: alert.recurrence_days |> Enum.map(&Atom.to_string/1)
    }
  end

  defp get_notification_specifier(nil), do: :same_as_effect_period
  defp get_notification_specifier(_notification_period_start), do: :custom

  def shift_to_naive(nil), do: nil

  def shift_to_naive(time) do
    time |> Timex.Timezone.convert("America/New_York") |> DateTime.to_naive()
  end

  def start_date(nil), do: nil
  def start_date(ap_start), do: NaiveDateTime.to_date(ap_start)

  def end_date(nil, _), do: nil
  def end_date(ap_end, "end_of_service"), do: ap_end |> NaiveDateTime.to_date() |> Date.add(-1)
  def end_date(ap_end, "later_today"), do: ap_end |> NaiveDateTime.to_date() |> Date.add(-1)

  def end_date(ap_end, _) do
    end_time = NaiveDateTime.to_time(ap_end)
    end_date = NaiveDateTime.to_date(ap_end)

    if Time.compare(end_time, ActivePeriod.end_of_service_time()) in [:lt, :eq] do
      Date.add(end_date, -1)
    else
      end_date
    end
  end

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

  defp get_route_type(nil), do: nil
  defp get_route_type("access"), do: nil
  defp get_route_type("systemwide"), do: nil
  defp get_route_type(route_type), do: String.to_integer(route_type)

  defp route_types_by_id(:SR, route_type, route_ids) do
    # necessary to form informed entities correctly upon persisting
    route_ids
    |> Enum.map(fn route_id -> {route_id, route_type} end)
    |> Map.new()
  end

  defp route_types_by_id(_, _, _), do: nil

  defp originator_fallback(nil), do: "Legacy User"
  defp originator_fallback(user_name), do: user_name
end
