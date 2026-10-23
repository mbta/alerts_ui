defmodule AlertsUIWeb.FormComponents.Helpers.AlertDataBuilder do
  @moduledoc """
  Builds alert data from existing alert
  Used to populate form when editing an alert
  Can take an Alert struct or an alert_id
  """

  alias AlertsUI.Alerts
  alias AlertsUI.Models.{ActivePeriod, Alert, Effect}
  alias AlertsUIWeb.CreateAlertLive.Helpers.GetKeyForModeEffect

  import AlertsUIWeb.CreateAlertLive.Helpers.AlertDataHelpers,
    only: [get_single_route_effect_names: 0, get_single_facility_effect_names: 0]

  alias MBTAV3API.Routes.Route

  # credo:disable-for-this-file
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
    :can_close_automatically,
    :cause_detail,
    :combination,
    :created_timestamp,
    :created_by,
    :description_text,
    :direction,
    :effect_name,
    :facility_ids,
    :single_facility_id,
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
    :service_types,
    :severity,
    :single_route_id,
    :stop_ids,
    :stop_names_and_ids,
    :trip_ids,
    :url,
    :last_push_notification_timestamp,
    :notification_toggle,
    :work_order_id,
    :skate_detour_id
  ]

  @type reminder_time_t :: %{
          id: String.t(),
          time: NaiveDateTime.t()
        }
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
          can_close_automatically: boolean(),
          cause_detail: String.t() | nil,
          combination: atom() | nil,
          created_timestamp: DateTime.t() | nil,
          created_by: String.t() | nil,
          description_text: String.t() | nil,
          direction: String.t() | nil,
          effect_name: String.t() | nil,
          facility_ids: [String.t()] | nil,
          single_facility_id: String.t() | nil,
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
          reminder_times: [reminder_time_t()] | nil,
          route_ids: [String.t()] | nil,
          route_type: Route.type_int() | nil,
          service_types: [Route.type_int()] | nil,
          severity: integer() | nil,
          single_route_id: String.t() | nil,
          stop_ids: [String.t()] | nil,
          stop_names_and_ids: [String.t()] | nil,
          trip_ids: [String.t()] | nil,
          url: String.t() | nil,
          last_push_notification_timestamp: DateTime.t() | nil,
          notification_toggle: boolean(),
          work_order_id: String.t() | nil,
          skate_detour_id: integer() | nil
        }

  @spec build_alert_data(String.t() | Alert.t() | nil, atom()) ::
          t()
  def build_alert_data(alert, form_type \\ nil)

  def build_alert_data(alert_id, form_type) when is_binary(alert_id) do
    alert = alert_id |> Alerts.get_by_alert_id()

    if Map.get(alert, :id) == nil do
      build_alert_data(nil)
    else
      build_alert_data(alert, form_type)
    end
  end

  def build_alert_data(%AlertsUI.Models.Alert{} = alert, form_type) do
    direct_from_alert_keys = [
      :banner_text,
      :cause_detail,
      :description_text,
      :header_text,
      :image_alternative_text,
      :image_url,
      :severity,
      :url,
      :original_route_selections,
      :original_trip_selections,
      :original_stop_selections,
      :original_direction_selections,
      :original_facility_selections
    ]

    Enum.reduce(direct_from_alert_keys, %__MODULE__{}, fn key, params ->
      Map.put(params, key, Map.get(alert, key))
    end)
    |> Map.merge(create_and_edit_metadata(alert, form_type))
    |> Map.merge(effect_name_combination_and_informed_entities(alert, form_type))
    |> Map.merge(last_push_notification_timestamp(alert))
    |> Map.merge(active_period_map(alert))
    |> Map.merge(reminder_times(alert))
    |> Map.merge(notification_period(alert, form_type))
    |> Map.put(:form_type, form_type)
    |> Map.merge(service_types(alert))
    |> Map.merge(banner_sync_toggle(alert))
    |> Map.merge(work_order_id(alert, form_type))
    |> Map.merge(skate_detour_id(alert, form_type))
  end

  def build_alert_data(_, _), do: %__MODULE__{}

  # if the alert is being duplicated, don't include any of the original metadata
  defp create_and_edit_metadata(_alert, :duplicating), do: %{}

  # if the alert is new it has no history
  defp create_and_edit_metadata(%Alert{id: nil}, _), do: %{}

  defp create_and_edit_metadata(alert, _form_type) do
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
      created_timestamp: alert.created_timestamp,
      created_by: created_by,
      last_edited_by: last_edited_by,
      last_edited_at: alert.last_modified_timestamp
    }
  end

  defp effect_name_combination_and_informed_entities(alert, form_type) do
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
        GetKeyForModeEffect.get_value_of_key(:combination, route_type, effect_name)
      end

    route_ids = Alert.gather_route_ids(alert)

    single_route_id =
      if alert.effect_name in get_single_route_effect_names() && length(route_ids) === 1 do
        hd(route_ids)
      else
        nil
      end

    route_ids =
      if is_nil(single_route_id) && alert.effect_name in get_single_route_effect_names(),
        do: [],
        else: route_ids

    facility_ids = Alert.gather_facility_ids(alert)

    single_facility_id =
      if alert.effect_name in get_single_facility_effect_names() && length(facility_ids) === 1 do
        hd(facility_ids)
      else
        nil
      end

    notification_key =
      if form_type == :editing,
        do: :send_push_notification_on_edit,
        else: :send_push_notification_on_create

    send_push_notification? =
      GetKeyForModeEffect.get_value_of_key(
        notification_key,
        route_type || primary_service_type,
        effect_name
      )

    %{
      combination: combination,
      effect_name: effect_name,
      direction: Alert.get_direction(alert) || "default",
      facility_ids: facility_ids,
      single_facility_id: single_facility_id,
      route_ids: route_ids,
      route_type: route_type,
      single_route_id: single_route_id,
      stop_ids: Alert.gather_parent_stop_ids(alert),
      stop_names_and_ids: alert.original_stop_selections,
      trip_ids: Alert.gather_trip_ids(alert),
      notification_toggle: send_push_notification?
    }
  end

  defp active_period_map(alert) do
    if alert.recurring do
      determine_recurring_active_period(alert)
    else
      determine_one_time_active_period(alert)
    end
  end

  defp reminder_times(alert) do
    %{
      reminder_times:
        Enum.map(alert.reminder_times, fn time ->
          %{
            id: time.id,
            time: shift_to_naive(time.reminder_time)
          }
        end)
        |> Enum.sort_by(& &1.time, NaiveDateTime)
    }
  end

  defp notification_period(alert, :duplicating) do
    notification_period_start = shift_to_naive(alert.notification_period_start)
    notification_specifier = get_notification_specifier(notification_period_start)

    %{
      notification_period_start: notification_period_start,
      notification_specifier: notification_specifier
    }
  end

  defp notification_period(alert, :new) do
    notification_period_start = shift_to_naive(alert.notification_period_start)
    notification_period_end = shift_to_naive(alert.notification_period_end)

    %{
      notification_period_start: notification_period_start,
      notification_period_end: notification_period_end,
      notification_specifier: :now
    }
  end

  defp notification_period(alert, _form_type) do
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

  defp work_order_id(alert, :editing) do
    %{
      work_order_id: alert.work_order_id
    }
  end

  defp work_order_id(_alert, _form_type), do: %{work_order_id: nil}

  defp skate_detour_id(alert, :editing) do
    %{
      skate_detour_id: alert.skate_detour_id
    }
  end

  defp skate_detour_id(_alert, _form_type), do: %{skate_detour_id: nil}

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
        alert.duration_certainty,
        alert.can_close_automatically
      )

    %{
      alert_timing: :"one-time",
      active_period_start: shifted_active_period_start,
      active_period_end: shifted_active_period_end,
      active_period_end_date: end_date(shifted_active_period_end, end_specifier),
      active_period_start_date: start_date(shifted_active_period_start),
      active_period_start_specifier: determine_start_specifier(shifted_active_period_start),
      active_period_end_specifier: end_specifier,
      # preserve selections when ex-recurring alerts are made recurring again
      recurrence_days: (alert.recurrence_days || []) |> Enum.map(&Atom.to_string/1)
    }
  end

  def determine_recurring_active_period(%{active_period: active_period} = alert) do
    shifted_active_period_start = shift_to_naive(alert.active_period_start)
    shifted_active_period_end = shift_to_naive(alert.active_period_end)

    [start_datetime, end_datetime] = [shifted_active_period_start, shifted_active_period_end]

    end_specifier = if alert.active_period_end, do: "custom", else: "until_further_notice"

    [recurrence_start_time, recurrence_end_time] =
      [
        Map.get(alert, :recurrence_start_time) || NaiveDateTime.to_time(start_datetime),
        Map.get(alert, :recurrence_end_time) || further_notice_end_time(active_period)
      ]

    %{
      alert_timing: :recurring,
      active_period_start: shifted_active_period_start,
      active_period_end: shifted_active_period_end,
      active_period_start_time_specifier: determine_start_specifier(start_datetime),
      active_period_end_time_specifier:
        determine_end_specifier(end_datetime, :KNOWN, alert.can_close_automatically),
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

  defp further_notice_end_time(active_period) do
    # get end time from first active period. fallback for older alerts with no
    # recurrence time stored.
    hd(active_period).end |> shift_to_naive() |> NaiveDateTime.to_time()
  end

  defp get_notification_specifier(nil), do: :same_as_effect_period
  defp get_notification_specifier(_notification_period_start), do: :custom

  defp last_push_notification_timestamp(alert) do
    %{last_push_notification_timestamp: Map.get(alert, :last_push_notification_timestamp)}
  end

  def shift_to_naive(nil), do: nil

  def shift_to_naive(time) do
    time |> DateTime.shift_zone!("America/New_York") |> DateTime.to_naive()
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

  @spec determine_end_specifier(NaiveDateTime.t(), atom() | nil, boolean()) ::
          String.t() | nil
  def determine_end_specifier(ap_end, certainty, autoclosable \\ false)

  def determine_end_specifier(nil, nil, _), do: nil
  def determine_end_specifier(nil, _, true), do: "when_work_order_is_closed"
  def determine_end_specifier(_, :ESTIMATED, _), do: "later_today"
  def determine_end_specifier(nil, _, _), do: "until_further_notice"

  def determine_end_specifier(ap_end, :KNOWN, _) do
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

  defp originator_fallback(nil), do: "Legacy User"
  defp originator_fallback(user_name), do: user_name
end
