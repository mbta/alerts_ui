defmodule AlertsUI.AlertHistory do
  @moduledoc """
  Functions for building an alert history struct
  and exporting it to CSV. Converts all datetimes to formatted
  strings in the right timezone.
  """

  alias AlertsUI.Alerts
  alias AlertsUI.Models.{Alert, SeverityLevel}
  alias AlertsUIWeb.Helpers.ContentFormatter

  @history_keys [
    :alert_id,
    :version,
    :created_datetime,
    :closed,
    :last_modified_by,
    :last_modified_datetime,
    :push_notification_sent,
    :service_type,
    :effect_name,
    :effect,
    :effect_detail,
    :affected_entities,
    :recurrence,
    :effect_start,
    :effect_end,
    :recurrence_start_time,
    :recurrence_end_time,
    :recurrence_days,
    :notification_start,
    :notification_end,
    :duration_certainty,
    :cause,
    :cause_detail,
    :severity_code,
    :severity_level,
    :severity_name,
    :main_message,
    :supporting_information,
    :url,
    :image_url,
    :image_alternative_text,
    :set_as_website_banner,
    :website_banner_text,
    :reminders,
    :source_id
  ]

  defstruct @history_keys

  @type t :: %__MODULE__{
          alert_id: String.t(),
          version: integer(),
          created_datetime: String.t(),
          closed: String.t() | nil,
          last_modified_by: String.t(),
          last_modified_datetime: String.t(),
          push_notification_sent: boolean(),
          service_type: String.t(),
          effect_name: String.t(),
          effect: String.t(),
          effect_detail: String.t(),
          affected_entities: String.t(),
          recurrence: boolean() | nil,
          effect_start: String.t(),
          effect_end: String.t(),
          recurrence_start_time: String.t() | nil,
          recurrence_end_time: String.t() | nil,
          recurrence_days: String.t() | nil,
          notification_start: String.t() | nil,
          notification_end: String.t() | nil,
          duration_certainty: String.t(),
          cause: String.t() | nil,
          cause_detail: String.t() | nil,
          severity_code: integer(),
          severity_level: String.t(),
          severity_name: String.t(),
          main_message: String.t(),
          supporting_information: String.t(),
          url: String.t(),
          image_url: String.t() | nil,
          image_alternative_text: String.t() | nil,
          set_as_website_banner: String.t() | nil,
          website_banner_text: String.t() | nil,
          reminders: String.t() | nil,
          source_id: String.t() | nil
        }

  @with_seconds "%M:%S"
  @without_seconds "%M"

  @spec alert_history(String.t()) :: [t()]
  def alert_history(alert_id) do
    alert_id
    |> Alerts.get_uuid_by_alert_id()
    |> Alerts.get_all_versions()
    |> build_alert_maps(alert_id)
    |> Enum.with_index()
    |> Enum.map(&build_history(&1))
  end

  @spec build_history({map(), integer()}) :: struct()
  def build_history({alert_map, index}) do
    [recurrence_start_time, recurrence_end_time] =
      get_recurrence_times(alert_map)

    %__MODULE__{
      alert_id: alert_map |> alert_id(),
      version: index + 1,
      created_datetime: alert_map |> created_datetime(),
      closed: alert_map |> closed(),
      last_modified_by: alert_map |> last_modified_by(),
      last_modified_datetime: alert_map |> last_modified_datetime(),
      push_notification_sent: alert_map |> push_notification_sent(),
      service_type: alert_map |> service_type(),
      effect_name: alert_map |> effect_name(),
      effect: alert_map |> effect(),
      effect_detail: alert_map |> effect_detail(),
      affected_entities: alert_map |> affected_entities(),
      recurrence: alert_map |> recurrence(),
      effect_start: alert_map |> effect_start(),
      effect_end: alert_map |> effect_end(),
      recurrence_days: alert_map |> recurrence_days(),
      recurrence_start_time: recurrence_start_time,
      recurrence_end_time: recurrence_end_time,
      notification_start: alert_map |> notification_start(),
      notification_end: alert_map |> notification_end(),
      duration_certainty: alert_map |> duration_certainty(),
      cause: alert_map |> cause(),
      cause_detail: alert_map |> cause_detail(),
      severity_code: alert_map |> severity_code(),
      severity_level: alert_map |> severity_level(),
      severity_name: alert_map |> severity_name(),
      main_message: alert_map |> main_message(),
      supporting_information: alert_map |> supporting_information(),
      url: alert_map |> url(),
      image_url: alert_map |> image_url(),
      image_alternative_text: alert_map |> image_alternative_text(),
      set_as_website_banner: alert_map |> set_as_website_banner(),
      website_banner_text: alert_map |> website_banner_text(),
      reminders: alert_map |> reminders(),
      source_id: alert_map |> source_id()
    }
  end

  # build_history helpers

  defp alert_id(map) do
    Map.get(map, :alert_id)
  end

  defp created_datetime(map) do
    created_datetime = Map.get(map, :created_timestamp) || Map.get(map, :created_at)
    format_datetime(created_datetime, @with_seconds)
  end

  defp closed(map) do
    closed?(Map.get(map, :closed_timestamp))
  end

  defp last_modified_by(map) do
    Alerts.get_originator_string(map)
  end

  defp last_modified_datetime(map) do
    format_datetime(Map.get(map, :last_modified_timestamp), @with_seconds)
  end

  defp push_notification_sent(map) do
    last_modified_datetime = Map.get(map, :last_modified_timestamp)

    last_push_notification_timestamp =
      Map.get(map, :last_push_notification_timestamp)

    # cast to datetimes and compare. If times are less than 2 minutes apart
    # we say that we sent a push notification.
    # (older alerts will have LPNT slightly before LMD)
    push_notification_sent?(last_modified_datetime, last_push_notification_timestamp)
  end

  defp push_notification_sent?(last_modified_datetime, last_push_notification_timestamp)
       when is_binary(last_modified_datetime) and is_binary(last_push_notification_timestamp) do
    with {:ok, last_modified_datetime, _} <- DateTime.from_iso8601(last_modified_datetime),
         {:ok, last_push_notification_timestamp, _} <-
           DateTime.from_iso8601(last_push_notification_timestamp) do
      DateTime.diff(last_modified_datetime, last_push_notification_timestamp, :minute) |> abs < 2
    else
      {:error, _} -> false
    end
  end

  defp push_notification_sent?(_, _), do: false

  defp service_type(map) do
    get_service_type(Map.get(map, :primary_service_type))
  end

  defp effect_name(map) do
    Map.get(map, :effect_name)
  end

  defp effect(map) do
    Map.get(map, :effect)
  end

  defp effect_detail(map) do
    Map.get(map, :effect_detail)
  end

  defp affected_entities(map) do
    build_affected_entities(map)
  end

  defp recurrence(%{recurring: true}), do: true
  defp recurrence(%{}), do: false

  defp effect_start(map) do
    format_datetime(Map.get(map, :active_period_start), @without_seconds)
  end

  defp effect_end(map) do
    effect_end(
      Map.get(map, :duration_certainty) || "UNKNOWN",
      Map.get(map, :active_period_end),
      %{
        can_close_automatically: Map.get(map, :can_close_automatically),
        primary_service_type: Map.get(map, :primary_service_type),
        effect_name: Map.get(map, :effect_name)
      }
    )
  end

  defp recurrence_days(map) do
    get_recurrence_days(Map.get(map, :recurrence_days))
  end

  defp notification_start(map) do
    format_datetime(Map.get(map, :notification_period_start), @without_seconds)
  end

  defp notification_end(map) do
    case Map.get(map, :notification_duration_certainty) do
      nil ->
        format_datetime(
          Map.get(map, :notification_period_end),
          @without_seconds
        )

      certainty ->
        effect_end(
          certainty,
          Map.get(map, :notification_period_end)
        )
    end
  end

  defp duration_certainty(map) do
    Map.get(map, :duration_certainty)
  end

  defp cause(map) do
    Map.get(map, :cause) || "UNKNOWN_CAUSE"
  end

  defp cause_detail(map) do
    Map.get(map, :cause_detail) || "UNKNOWN_CAUSE"
  end

  defp severity_code(map) do
    Map.get(map, :severity)
  end

  defp severity_level(map) do
    Map.get(map, :severity_level)
  end

  defp severity_name(map) do
    SeverityLevel.severity_description_by_severity(Map.get(map, :severity))
  end

  defp main_message(map) do
    Map.get(map, :header_text)
  end

  defp supporting_information(map) do
    Map.get(map, :description_text) || ""
  end

  defp url(map) do
    Map.get(map, :url) || ""
  end

  defp image_url(map) do
    Map.get(map, :image_url) || ""
  end

  defp image_alternative_text(map) do
    Map.get(map, :image_alternative_text) || ""
  end

  defp set_as_website_banner(map) do
    !is_nil(Map.get(map, :banner_text))
  end

  defp website_banner_text(map) do
    Map.get(map, :banner_text) || ""
  end

  defp reminders(map) do
    Map.get(map, :plaintext_reminder_selections) || ""
  end

  defp source_id(map) do
    # shows either the trapeze id or skate id if present.
    # an alert will never have both of these.
    Map.get(map, :work_order_id) || Map.get(map, :skate_detour_id)
  end

  # end build_history helpers

  defp build_affected_entities(alert_map) do
    route_names = build_entity(Map.get(alert_map, :original_route_selections), "Routes")

    direction_names =
      Map.get(alert_map, :original_direction_selections)
      |> Alert.get_original_names()
      |> build_direction

    stop_names = build_entity(Map.get(alert_map, :original_stop_selections), "Stops")

    trip_names = build_entity(Map.get(alert_map, :original_trip_selections), "Trips")

    facility_names = build_entity(Map.get(alert_map, :original_facility_selections), "Facilities")

    [facility_names, route_names, stop_names, direction_names, trip_names]
    |> Enum.join("; ")
    |> String.replace("; ; ", "; ")
    |> String.trim("; ")
  end

  defp build_entity([], _title), do: ""
  defp build_entity(nil, _title), do: ""

  defp build_entity(selections, title) do
    title <>
      ": " <>
      (selections
       |> Alert.get_original_names()
       |> Enum.join(", "))
  end

  defp build_direction([""]), do: ""

  defp build_direction([direction_name]) do
    "Direction: #{direction_name}"
  end

  defp build_direction(_), do: ""

  @spec build_history_csv([t()]) :: [list()]
  def build_history_csv(history_list) do
    # build keyword list to maintain order of keys
    headers = build_headers()

    values =
      history_list
      |> Enum.map(fn history ->
        history = Map.from_struct(history)

        Enum.map(@history_keys, fn key ->
          {key, history[key]}
        end)
        |> Keyword.values()
        |> Enum.map(&convert_atoms/1)
      end)

    [headers | values]
  end

  defp convert_atoms(nil), do: ""
  defp convert_atoms(item) when is_atom(item), do: Atom.to_string(item)
  defp convert_atoms(item), do: item

  def build_headers do
    @history_keys
    |> Enum.map(fn key ->
      key |> Atom.to_string() |> String.capitalize() |> String.replace("_", " ")
    end)
  end

  @spec build_alert_maps(PaperTrail.Version.t(), String.t()) :: [map()]
  # sobelow_skip ["DOS.StringToAtom"]
  defp build_alert_maps(versions, alert_id) do
    # takes in a list of versions
    # pares those down to the changes, alert_id, and the origin information
    # returns a list of alert maps with atom keys
    # starting with the oldest and ending with the newest
    # skips sobelow warning because old keys may not be created atoms
    # and this is not user input- it comes straight from the DB

    versions
    |> Enum.map(
      &Map.merge(&1.item_changes, %{
        "originator_id" => &1.originator_id,
        "origin" => &1.origin,
        "alert_id" => alert_id,
        # actual updated_at timestamp is not stored in version
        # so use version inserted_at timestamp instead
        "updated_at" => &1.inserted_at
      })
    )
    |> Enum.reduce([%{}], fn version, acc ->
      [Map.merge(hd(acc), version) | acc]
    end)
    |> Enum.reverse()
    |> tl
    |> Enum.map(&Map.new(&1, fn {k, v} -> {String.to_atom(k), v} end))
  end

  defp effect_end(estimate, active_period_end, opts \\ %{})

  defp effect_end("KNOWN", active_period_end, _) do
    format_datetime(active_period_end, @without_seconds)
  end

  defp effect_end(_, _, %{
         can_close_automatically: true,
         primary_service_type: "access",
         effect_name: "Elevator Closure"
       }),
       do: "from Trapeze"

  defp effect_end(_, _, %{
         can_close_automatically: true,
         primary_service_type: "access",
         effect_name: "Escalator Closure"
       }),
       do: "from Trapeze"

  defp effect_end("ESTIMATED", _, _), do: "later today"
  defp effect_end("UNKNOWN", _, _), do: "further notice"

  defp closed?(nil), do: false
  defp closed?(_), do: true

  defp get_recurrence_days([_ | _] = recurrence_days) do
    recurrence_days |> Enum.map_join(",", &String.capitalize/1)
  end

  defp get_recurrence_days(_), do: ""

  defp get_recurrence_times(alert_map) do
    recurrence_start_time =
      case Map.get(alert_map, :recurrence_start_time) do
        nil -> ""
        start_time -> format_time(start_time)
      end

    recurrence_end_time =
      case Map.get(alert_map, :recurrence_end_time) do
        nil -> ""
        end_time -> format_time(end_time)
      end

    [recurrence_start_time, recurrence_end_time]
  end

  defp get_service_type(nil), do: ""
  defp get_service_type("access"), do: "Facility"
  defp get_service_type("systemwide"), do: "Systemwide"

  defp get_service_type(service_type) do
    service_type_integer = Integer.parse(service_type)

    if service_type_integer == :error do
      ""
    else
      {service_type_integer, _remainder} = service_type_integer
      ContentFormatter.service_type_string(service_type_integer)
    end
  end

  defp format_datetime(nil, _format), do: ""

  defp format_datetime(datetime_string, format) when is_binary(datetime_string) do
    {:ok, utc_datetime, _} = DateTime.from_iso8601(datetime_string)
    format_datetime(utc_datetime, format)
  end

  defp format_datetime(%DateTime{} = utc_datetime, format) do
    utc_datetime
    |> DateTime.shift_zone!("America/New_York")
    |> Calendar.strftime("%Y-%m-%dT%H:" <> format)
  end

  defp format_time(time_string) do
    time_string
    |> Time.from_iso8601!()
    |> Calendar.strftime("%-H:" <> @without_seconds)
  end
end
