defmodule AlertsUI.AlertHistory do
  @moduledoc """
  Functions for building an alert history struct
  and exporting it to CSV. Converts all datetimes to formatted
  strings in the right timezone.
  """

  alias AlertsUI.Alerts
  alias AlertsUI.Models.SeverityLevel

  @history_keys [
    :alert_id,
    :version,
    :created_datetime,
    :closed,
    :last_modified_by,
    :last_modified_datetime,
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
    :reminders
  ]

  defstruct @history_keys

  @type t :: %__MODULE__{
          alert_id: String.t(),
          version: integer(),
          created_datetime: String.t(),
          closed: String.t() | nil,
          last_modified_by: String.t(),
          last_modified_datetime: String.t(),
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
          reminders: String.t() | nil
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
    recurring? = recurring?(alert_map.recurrence_days)

    %__MODULE__{
      alert_id: alert_map.alert_id,
      version: index + 1,
      created_datetime: format_datetime(alert_map.created_at, @with_seconds),
      closed: closed?(alert_map.closed_timestamp),
      last_modified_by: Alerts.get_originator_string(alert_map),
      last_modified_datetime: format_datetime(alert_map.updated_at, @with_seconds),
      service_type: Map.get(alert_map, :primary_service_type, ""),
      effect_name: alert_map.effect_name,
      effect: alert_map.effect,
      effect_detail: alert_map.effect_detail,
      affected_entities: nil,
      recurrence: recurring?,
      effect_start: format_datetime(alert_map.active_period_start, @without_seconds),
      effect_end: effect_end(alert_map.duration_certainty, alert_map.active_period_end),
      recurrence_days:
        (alert_map.recurrence_days || []) |> Enum.map_join(",", &String.capitalize/1),
      recurrence_start_time: get_recurrence_time(recurring?, alert_map.active_period_start),
      recurrence_end_time: nil,
      notification_start: format_datetime(alert_map.notification_period_start, @without_seconds),
      notification_end: format_datetime(alert_map.notification_period_end, @without_seconds),
      duration_certainty: alert_map.duration_certainty,
      cause: alert_map.cause,
      cause_detail: alert_map.cause_detail,
      severity_code: alert_map.severity,
      severity_level: alert_map.severity_level,
      severity_name: SeverityLevel.severity_description_by_severity(alert_map.severity),
      main_message: alert_map.header_text,
      supporting_information: alert_map.description_text || "",
      url: alert_map.url || "",
      image_url: alert_map.image_url || "",
      image_alternative_text: alert_map.image_alternative_text || "",
      set_as_website_banner: !is_nil(alert_map.banner_text),
      website_banner_text: alert_map.banner_text || "",
      reminders: nil
    }
  end

  @spec build_history_csv([t()]) :: iodata()
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

  defp convert_atoms(item) when is_atom(item), do: Atom.to_string(item)
  defp convert_atoms(item), do: item

  defp build_headers do
    @history_keys
    |> Enum.map(fn key ->
      key |> Atom.to_string() |> String.capitalize() |> String.replace("_", " ")
    end)
  end

  @spec build_alert_maps(PaperTrail.Version.t(), String.t()) :: [map()]
  defp build_alert_maps(versions, alert_id) do
    # takes in a list of versions
    # pares those down to the changes, alert_id, and the origin information
    # returns a list of alert maps with atom keys
    # starting with the oldest and ending with the newest

    versions
    |> Enum.map(
      &Map.merge(&1.item_changes, %{
        "originator_id" => &1.originator_id,
        "origin" => &1.origin,
        "alert_id" => alert_id
      })
    )
    |> Enum.reduce([%{}], fn version, acc ->
      [Map.merge(hd(acc), version) | acc]
    end)
    |> Enum.reverse()
    |> tl
    |> Enum.map(&Map.new(&1, fn {k, v} -> {String.to_existing_atom(k), v} end))
  end

  defp effect_end("ESTIMATED", _), do: "later today"
  defp effect_end("UNKNOWN", _), do: "further notice"

  defp effect_end("KNOWN", active_period_end) do
    format_datetime(active_period_end, @without_seconds)
  end

  defp closed?(nil), do: false
  defp closed?(_), do: true

  defp recurring?([_ | _]), do: true
  defp recurring?(_), do: false

  defp get_recurrence_time(true, datetime) do
    format_time(datetime, "%-H:" <> @without_seconds)
  end

  defp get_recurrence_time(false, _), do: ""

  defp format_datetime(nil, _format), do: ""

  defp format_datetime(datetime_string, format) do
    {:ok, utc_datetime, _} = DateTime.from_iso8601(datetime_string)

    utc_datetime
    |> DateTime.shift_zone!("America/New_York")
    |> Calendar.strftime("%Y-%m-%dT%H:" <> format)
  end

  defp format_time(datetime_string, format) do
    {:ok, utc_datetime, _} = DateTime.from_iso8601(datetime_string)

    utc_datetime
    |> DateTime.shift_zone!("America/New_York")
    |> DateTime.to_time()
    |> Calendar.strftime(format)
  end
end
