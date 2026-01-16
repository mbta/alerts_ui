# credo:disable-for-this-file

NimbleCSV.define(AlertsUI.IBIAlertImportParser, [])

defmodule AlertsUI.IBIAlertImporter do
  @moduledoc """
  Import alerts from the IBI CSV export.
  """
  @dialyzer {:nowarn_function, convert_ibi_alerts: 1}

  require Logger

  import Ecto.Query

  alias AlertsUI.AlertBuilder
  alias AlertsUI.IBIAlertImportParser
  alias AlertsUI.IBIAlertImporter.ParentChildStopMapping
  alias AlertsUI.Models.Alert
  alias AlertsUI.Models.Cause
  alias AlertsUI.Models.IBIAlert
  alias AlertsUI.Models.LatestIBIAlert
  alias AlertsUI.Models.ReminderTime
  alias AlertsUI.Repo
  alias Ecto.Adapters.SQL
  alias Ecto.Changeset
  alias Ecto.Multi

  @default_chunk_size 1000

  def import_ibi_alerts!(path, import_id) do
    Repo.transact(
      fn ->
        Logger.info("[import #{import_id}] ingesting source file")
        ingest_csv_file(path)
        Logger.info("[import #{import_id}] fixing timestamps")
        fix_invalid_timestamps()
        # running this twice for alert 515100, why that works who knows, who cares
        fix_invalid_timestamps()
        Logger.info("[import #{import_id}] converting legacy alerts")
        convert_ibi_alerts()
        Logger.info("[import #{import_id}] done")
        {:ok, true}
      end,
      timeout: :infinity
    )
  end

  @doc """
  Import a CSV file according to the format given by `IBIAlert.columns/0` as follows:
    - Stream a local file from `path`
    - Parse the stream of lines as CSV
    - Chunk the rows into manageable batches to mitigate N+1 overhead on query and commit

  The entire operation is wrapped in a transaction, so input files will succeed or fail
  but never a mix of both.
  """
  @spec ingest_csv_file(String.t(), chunk_size: integer()) :: {:ok, map()} | Ecto.Multi.failure()
  # sobelow_skip ["Traversal"]
  def ingest_csv_file(path, options \\ []) do
    fields =
      path
      |> File.open!(fn f -> IO.read(f, :line) end)
      |> IBIAlertImportParser.parse_string(skip_headers: false)
      |> List.flatten()
      |> field_map_from_headers()

    Repo.transact(
      fn ->
        path
        |> File.stream!()
        |> IBIAlertImportParser.parse_stream()
        |> Stream.chunk_every(chunk_size(options))
        |> Stream.each(fn chunk ->
          Enum.reduce(chunk, Multi.new(), fn row, multi ->
            versioned_id = {row_to_alert_id(row, fields), row_to_version_no(row, fields)}
            changeset = IBIAlert.changeset(%IBIAlert{}, row_to_params(row, fields))
            Multi.insert(multi, versioned_id, changeset)
          end)
          |> Repo.transact()
        end)
        |> Stream.run()

        {:ok, true}
      end,
      timeout: :infinity
    )
  end

  @doc """
  Fix recurrence start and end times with hours >24 by wrapping them around.
  """
  def fix_invalid_timestamps do
    Repo.transact(
      fn ->
        # fix DST-adjacent timestamps
        fields = [
          "created_dt",
          "last_modified_dt",
          "notif_start",
          "notif_end",
          "effect_start",
          "effect_end"
        ]

        ambiguous_windows = [
          "3/9/2014 2%AM",
          "3/8/2015 2%AM",
          "3/13/2016 2%AM",
          "3/12/2017 2%AM",
          "3/11/2018 2%AM",
          "3/10/2019 2%AM",
          "3/8/2020 2%AM",
          "3/14/2021 2%AM",
          "3/13/2022 2%AM",
          "3/12/2023 2%AM",
          "3/10/2024 2%AM",
          "3/9/2025 2%AM",
          "11/2/2014 1%AM",
          "11/1/2015 1%AM",
          "11/6/2016 1%AM",
          "11/5/2017 1%AM",
          "11/1/2020 1%AM",
          "11/7/2021 1%AM",
          "11/6/2022 1%AM",
          "11/5/2023 1%AM",
          "11/3/2024 1%AM",
          "11/2/2025 1%AM"
        ]

        for field <- fields, window <- ambiguous_windows do
          SQL.query!(Repo, bump_timestamp_sql(field, window))
        end

        # years set to 8888/9999/10000
        SQL.query!(
          Repo,
          "update ibi_alerts set notif_end = replace(notif_end, '8888', '1900') where notif_end like '%8888%'"
        )

        SQL.query!(
          Repo,
          "update ibi_alerts set effect_end = replace(effect_end, '8888', '1900') where effect_end like '%8888%'"
        )

        SQL.query!(
          Repo,
          "update ibi_alerts set notif_end = replace(notif_end, '9999', '1901') where notif_end like '%9999%'"
        )

        SQL.query!(
          Repo,
          "update ibi_alerts set effect_end = replace(effect_end, '9999', '1901') where effect_end like '%9999%'"
        )

        SQL.query!(
          Repo,
          "update ibi_alerts set recurrence_end = replace(recurrence_end, '9999', '1901') where recurrence_end like '%9999%'"
        )

        SQL.query!(
          Repo,
          "update ibi_alerts set recurrence_end = replace(recurrence_end, '10000', '1902') where recurrence_end like '%10000%'"
        )

        # fix >24 clock timestamps
        Enum.each(24..47, fn digit ->
          SQL.query!(
            Repo,
            "update ibi_alerts
              set recurrence_start_time = regexp_replace(recurrence_start_time, '^#{digit}', '#{rem(digit, 24) |> Integer.to_string() |> String.pad_leading(2, "0")}'),
              recurrence_start = to_char(recurrence_start::date + interval '1 days', 'FMMM/FMDD/YYYY 12:00:00 AM')
              where recurrence_start_time like '#{digit}%'"
          )

          SQL.query!(
            Repo,
            "update ibi_alerts
              set recurrence_end_time = regexp_replace(recurrence_end_time, '^#{digit}', '#{rem(digit, 24) |> Integer.to_string() |> String.pad_leading(2, "0")}'),
              recurrence_end = to_char(recurrence_end::date + interval '1 days', 'FMMM/FMDD/YYYY 12:00:00 AM')
              where recurrence_end_time like '#{digit}%'"
          )
        end)

        {:ok, true}
      end,
      timeout: :infinity
    )
  end

  def bump_timestamp_sql(field, pattern) do
    """
    update ibi_alerts
      set #{field} = to_char(#{field}::timestamp + interval '1 hour', 'FMMM/FMDD/YYYY FMHH:MI:SS PM')
      where #{field} like '#{pattern}';
    """
  end

  @doc """
  Convert the now-imported IBI alerts to Alerts Manager alerts. Note that you'll
  want to perform any fixes to the underlying data (malformed timestamps, I'm looking
  at you) before this. As follows:
    - Stream `LatestIBIAlert` (closed alerts only for now, though we preserve the logic
      for dealing with open alerts)
    - Chunk for efficiency
    - For each chunk, pull the alert ids, and then load all alerts with those ids
      from the underlying `IBIAlert` schema (i.e., pulling all versions for all alerts
      in the chunk)
    - We don't worry here about updating/reimporting here, instead assuming that if
      the need arises to reimport, the user will purge the existing alerts first (if
      not, the alert id will be rejected as non-unique and the transaction will fail)
    - We _do_ allow for the possibility of importing open alerts, even though we
      aren't now. The difference is that when an alert is open, (i.e., when the latest
      IBI version has `is_closed` == `False`) the most recent version of that alert
      will have informed entities and active periods built for it
  """
  @spec convert_ibi_alerts(keyword()) :: {:ok, true}
  def convert_ibi_alerts(options \\ []) do
    query =
      Keyword.get(
        options,
        :query,
        from(i in LatestIBIAlert, where: i.is_closed == "True")
      )

    Repo.transact(
      fn ->
        query
        |> Repo.stream()
        |> Stream.chunk_every(chunk_size(options))
        |> Stream.each(fn chunk ->
          alert_ids = Enum.map(chunk, fn latest -> latest.alert_id end)

          all_versions_index =
            Repo.all(from i in IBIAlert, where: i.alert_id in ^alert_ids)
            |> Enum.group_by(fn version -> version.alert_id end)

          Enum.each(chunk, fn latest_version ->
            currently_open = latest_version.is_closed == "False"

            [insert | updates] =
              all_versions_index
              |> Map.get(latest_version.alert_id)
              |> Enum.sort_by(fn version -> version.integer_version_no end)

            insert_open = currently_open && insert.version_no == latest_version.version_no

            alert =
              insert
              |> ibi_alert_to_changeset(
                %Alert{},
                no_active_periods: !insert_open,
                no_informed_entities: !insert_open
              )
              |> PaperTrail.insert!(origin: insert.last_modified_by, returning: true)
              |> Repo.preload([:informed_entity, :active_period])

            Enum.each(updates, fn update ->
              update_open = currently_open && update.version_no == latest_version.version_no

              update
              |> ibi_alert_to_changeset(
                alert,
                no_active_periods: !update_open,
                no_informed_entities: !update_open
              )
              |> PaperTrail.update!(origin: update.last_modified_by)
            end)

            # fix mode selections for systemwide alerts
            if latest_version.gui_mode_name == "Systemwide" do
              final_mode_source =
                [insert | updates]
                |> Enum.reverse()
                |> Enum.find(& &1.affent_list)

              final_mode_selections =
                if final_mode_source do
                  from_ibi(final_mode_source, :original_mode_selections)
                else
                  [1, 2, 3, 4]
                end

              from(
                a in Alert,
                where: a.alert_id == ^latest_version.alert_id,
                update: [set: [original_mode_selections: ^final_mode_selections]]
              )
              |> Repo.update_all([])
            end

            # add deduplicated reminders
            all_versions_index
            |> Map.get(alert.alert_id)
            |> Enum.map(fn ibi_alert -> extract_reminders(ibi_alert, alert) end)
            |> List.flatten()
            |> Enum.uniq()
            |> Enum.map(fn params -> Changeset.cast(%ReminderTime{}, params, Map.keys(params)) end)
            |> Enum.each(fn changeset -> Repo.insert!(changeset) end)
          end)
        end)
        |> Stream.run()

        {:ok, true}
      end,
      timeout: :infinity
    )
  end

  def ibi_alert_to_changeset(ibi_alert, am_alert, options \\ []) do
    options =
      options
      |> Keyword.put(:no_recurrence_days_validation, true)
      |> Keyword.put(:no_original_selections, true)

    params =
      ibi_alert
      |> ibi_alert_to_alert_data()
      |> AlertBuilder.build_alert(from_ibi(ibi_alert, :combination), DateTime.utc_now(), options)
      |> Map.merge(%{alert_id: ibi_alert.alert_id})

    Alert.changeset(am_alert, params, options)
  end

  @spec ibi_alert_to_alert_data(IBIAlert.t()) :: map()
  def ibi_alert_to_alert_data(ibi_alert) do
    # alert data fields
    [
      :alert_id,
      :route_type,
      :route_ids,
      :stop_ids,
      :trip_ids,
      :stop_names_and_ids,
      :facility_id,
      :direction,
      :service_types,
      :alert_timing,
      :active_period_start,
      :active_period_end,
      :active_period_start_date,
      :active_period_start_time,
      :active_period_end_date,
      :active_period_end_time,
      :recurrence_days,
      :recurrence_start_time,
      :recurrence_end_time,
      :notification_period_start,
      :notification_period_end,
      :header_text,
      :description_text,
      :banner_text,
      :url,
      :cause,
      :cause_detail,
      :effect,
      :effect_detail,
      :effect_name,
      :severity,
      :combination,
      :original_direction_selections,
      :original_route_selections,
      :original_trip_selections,
      :original_facility_selections,
      :original_mode_selections,
      :created_timestamp,
      :closed_timestamp,
      :last_modified_timestamp,
      :legacy,
      :image_url,
      :image_alternative_text
    ]
    |> Enum.reduce(%{}, fn key, alert_data ->
      try do
        Map.put(alert_data, key, from_ibi(ibi_alert, key))
      rescue
        e ->
          Logger.error("alert #{ibi_alert.alert_id} / #{key}: #{e.message}")
          reraise e, __STACKTRACE__
      end
    end)
  end

  defp chunk_size(options) do
    Keyword.get(options, :chunk_size, @default_chunk_size)
  end

  defp field_map_from_headers(headers) do
    # a map keyed by row index, because that's what we use the most
    headers
    |> Enum.with_index()
    |> Enum.map(&{elem(&1, 1), elem(&1, 0)})
    |> Enum.into(%{})
  end

  defp field_map_to_row_index(fields, name) do
    # reverse it to get a row index from a field name
    Enum.find(fields, &(elem(&1, 1) == name)) |> elem(0)
  end

  defp row_to_alert_id(row, fields) do
    Enum.at(row, field_map_to_row_index(fields, "alert_id"))
  end

  defp row_to_version_no(row, fields) do
    Enum.at(row, field_map_to_row_index(fields, "version_no"))
  end

  defp row_to_params(row, fields) do
    row
    |> Enum.with_index()
    |> Enum.reduce(%{}, fn {value, index}, params ->
      case Map.get(fields, index) do
        nil -> raise "no field name at index #{index}"
        field_name -> Map.put(params, field_name, value)
      end
    end)
  end

  @spec from_ibi(IBIAlert.t(), atom()) :: any()
  def from_ibi(ibi_alert, :route_type) do
    gui_mode_name_to_route_type_int(ibi_alert.gui_mode_name)
  end

  def from_ibi(ibi_alert, :route_ids) do
    from_ibi(ibi_alert, :original_route_selections)
  end

  def from_ibi(ibi_alert, :stop_ids) do
    from_ibi(ibi_alert, :stop_names_and_ids)
  end

  def from_ibi(ibi_alert, :trip_ids) do
    from_ibi(ibi_alert, :original_trip_selections)
  end

  def from_ibi(ibi_alert, :direction) do
    from_ibi(ibi_alert, :original_direction_selections) |> Enum.at(0)
  end

  def from_ibi(ibi_alert, :facility_id) do
    from_ibi(ibi_alert, :original_facility_selections) |> Enum.at(0)
  end

  def from_ibi(ibi_alert, :service_types), do: [from_ibi(ibi_alert, :route_type)]

  def from_ibi(ibi_alert, :alert_timing) do
    case ibi_alert.alert_time_type do
      "Recurring" -> :recurring
      _ -> :one_time
    end
  end

  def from_ibi(ibi_alert, :active_period_start) do
    # this field must be populated so no `if` here (and all IBI alerts that
    # lack `effect_start` have `notif_start`)
    case from_ibi(ibi_alert, :alert_timing) do
      :one_time ->
        utc_from_ibi_string(ibi_alert.effect_start || ibi_alert.notif_start)

      :recurring ->
        date =
          ibi_alert.recurrence_start
          |> utc_from_ibi_string()
          |> NaiveDateTime.to_date()

        time =
          (ibi_alert.recurrence_start_time || ibi_alert.recurrence_start)
          |> utc_from_ibi_string()
          |> NaiveDateTime.to_time()

        NaiveDateTime.new!(date, time)
    end
  end

  def from_ibi(ibi_alert, :active_period_end) do
    case from_ibi(ibi_alert, :alert_timing) do
      :one_time ->
        utc_from_ibi_string(ibi_alert.effect_end || ibi_alert.notif_end)

      :recurring ->
        date =
          ibi_alert.recurrence_end
          |> utc_from_ibi_string()
          |> NaiveDateTime.to_date()

        time =
          (ibi_alert.recurrence_end_time || ibi_alert.recurrence_end)
          |> utc_from_ibi_string()
          |> NaiveDateTime.to_time()

        NaiveDateTime.new!(date, time)
    end
  end

  def from_ibi(ibi_alert, :active_period_start_time) do
    if ibi_alert.recurrence_start_time do
      utc_from_ibi_string(ibi_alert.recurrence_start_time) |> NaiveDateTime.to_time()
    end
  end

  def from_ibi(ibi_alert, :active_period_end_time) do
    if ibi_alert.recurrence_end_time do
      utc_from_ibi_string(ibi_alert.recurrence_end_time) |> NaiveDateTime.to_time()
    end
  end

  def from_ibi(ibi_alert, :active_period_start_date) do
    if ibi_alert.recurrence_start do
      utc_from_ibi_string(ibi_alert.recurrence_start) |> NaiveDateTime.to_date()
    end
  end

  def from_ibi(ibi_alert, :active_period_end_date) do
    if ibi_alert.recurrence_end do
      utc_from_ibi_string(ibi_alert.recurrence_end) |> NaiveDateTime.to_date()
    end
  end

  def from_ibi(ibi_alert, :recurrence_days) do
    if ibi_alert.recurrence_days do
      ibi_alert.recurrence_days
      |> String.downcase()
      |> String.replace(~r/\s/, "")
      |> String.split(",")
      |> Enum.filter(fn day_string -> day_string != "" end)
      |> Enum.map(fn day -> String.to_existing_atom(day) end)
    end
  end

  def from_ibi(ibi_alert, :notification_period_start) do
    if ibi_alert.notif_start do
      utc_from_ibi_string(ibi_alert.notif_start)
    end
  end

  def from_ibi(ibi_alert, :notification_period_end) do
    if ibi_alert.notif_end do
      utc_from_ibi_string(ibi_alert.notif_end)
    end
  end

  def from_ibi(ibi_alert, :header_text), do: ibi_alert.header

  def from_ibi(ibi_alert, :description_text), do: ibi_alert.details

  def from_ibi(ibi_alert, :severity) do
    case ibi_alert.severity_name do
      "Information" -> 1
      "information" -> 1
      "up to 10 minutes" -> 3
      "up to 15 minutes" -> 4
      "up to 20 minutes" -> 5
      "up to 25 minutes" -> 6
      "up to 30 minutes" -> 7
      "more than 30 minutes" -> 8
      "more than an hour" -> 9
      "High priority (deliver to T-Alert subscribers immediately)" -> 10
      "Minor" -> 1
      "Moderate" -> 5
      "Severe" -> 10
      unknown -> raise "unknown severity for alert #{ibi_alert.alert_id}: #{unknown}"
    end
  end

  def from_ibi(ibi_alert, :combination) do
    cond do
      ibi_alert.informed_route_list && ibi_alert.informed_direction_list &&
        ibi_alert.informed_trip_list &&
          ibi_alert.informed_stop_list ->
        :RDTS

      ibi_alert.informed_route_list && ibi_alert.informed_direction_list &&
          ibi_alert.informed_trip_list ->
        :RDT

      ibi_alert.informed_route_list && ibi_alert.informed_direction_list &&
          ibi_alert.informed_stop_list ->
        :RDS

      ibi_alert.informed_route_list && ibi_alert.informed_stop_list ->
        :SR

      ibi_alert.informed_route_list ->
        :R

      ibi_alert.informed_facility_list ->
        :ACCESS

      true ->
        nil
    end
  end

  def from_ibi(ibi_alert, :original_direction_selections) do
    split_combined_entities(ibi_alert.informed_direction_list)
  end

  def from_ibi(ibi_alert, :original_facility_selections) do
    split_combined_entities(ibi_alert.informed_facility_list)
  end

  @combo_route_ids [
    "602",
    "627",
    "725",
    "746",
    "2427",
    "3233",
    "3738",
    "4050",
    "8993",
    "116117",
    "214216",
    "441442"
  ]

  @color_lines [
    "Blue Line",
    "Green Line",
    "Orange Line",
    "Red Line"
  ]

  def from_ibi(ibi_alert, :original_route_selections) do
    ibi_alert.informed_route_list
    |> split_combined_entities()
    |> Enum.map(fn name_and_id ->
      [name, id] = String.split(name_and_id, "|")

      cond do
        Enum.member?(@combo_route_ids, id) -> nil
        Enum.member?(@color_lines, name) -> "#{name}|#{String.replace(name, " Line", "")}"
        true -> name_and_id
      end
    end)
    |> Enum.filter(&(!!&1))
    |> Enum.uniq()
  end

  def from_ibi(ibi_alert, :original_trip_selections) do
    split_combined_entities(ibi_alert.informed_trip_list)
  end

  def from_ibi(ibi_alert, :original_mode_selections) do
    case ibi_alert.gui_mode_name do
      "Systemwide" ->
        if ibi_alert.affent_list do
          ibi_alert.affent_list
          |> String.replace("MBTA;", "")
          |> String.split(",")
          |> Enum.map(fn affent ->
            String.trim_leading(affent)
            |> gui_mode_name_to_route_type_int()
          end)
          |> Enum.filter(fn route_type -> !!route_type end)
        else
          [1, 2, 3, 4]
        end

      _ ->
        []
    end
  end

  def from_ibi(ibi_alert, :stop_names_and_ids) do
    ibi_alert.informed_stop_list
    |> split_combined_entities()
    |> Enum.map(fn name_and_id ->
      [name, id] = String.split(name_and_id, "|")

      case ParentChildStopMapping.get_parent_by_child(id) do
        nil -> name_and_id
        parent_id -> "#{name}|#{parent_id}"
      end
    end)
    |> Enum.uniq_by(&(String.split(&1, "|") |> List.last()))
  end

  def from_ibi(ibi_alert, :cause) do
    case from_ibi(ibi_alert, :route_type)
         |> Cause.get_by_mode_and_detail(from_ibi(ibi_alert, :cause_detail)) do
      nil ->
        case ibi_alert.cause_name do
          "Amtrak" -> :OTHER_CAUSE
          "an earlier mechanical problem" -> :TECHNICAL_PROBLEM
          "an earlier signal problem" -> :TECHNICAL_PROBLEM
          "autos impeding service" -> :OTHER_CAUSE
          "congestion" -> :OTHER_CAUSE
          "crossing malfunction" -> :TECHNICAL_PROBLEM
          "construction" -> :CONSTRUCTION
          "disabled train" -> :TECHNICAL_PROBLEM
          "electrical work" -> :MAINTENANCE
          "fire" -> :TECHNICAL_PROBLEM
          "holiday" -> :HOLIDAY
          "ice in harbour" -> :OTHER_CAUSE
          "maintenance" -> :MAINTENANCE
          "mechanical failure" -> :TECHNICAL_PROBLEM
          "mechanical problem" -> :TECHNICAL_PROBLEM
          "police action" -> :POLICE_ACTIVITY
          "residual delay" -> :OTHER_CAUSE
          "signal failure" -> :TECHNICAL_PROBLEM
          "signal problem" -> :TECHNICAL_PROBLEM
          "single tracking" -> :OTHER_CAUSE
          "switch problem" -> :TECHNICAL_PROBLEM
          "technical problem" -> :TECHNICAL_PROBLEM
          "tie replacement" -> :MAINTENANCE
          "track problem" -> :TECHNICAL_PROBLEM
          "wire problem" -> :TECHNICAL_PROBLEM
        end

      cause_from_existing_enums ->
        cause_from_existing_enums
    end
  end

  def from_ibi(ibi_alert, :cause_detail) do
    (Map.get(ibi_alert, :cause_name) || "")
    |> String.replace(~r/\s+/, "_")
    |> String.upcase()
  end

  def from_ibi(ibi_alert, :effect_name) do
    mappings = %{
      "Accessibility" => "Access Issue",
      "Cancelled Trip" => "Cancellation",
      "Dropped Trip" => "Cancellation",
      "Impacted Service" => "Service Change",
      "No Service" => "Service Change",
      "Other (Dock)" => "Service Change",
      "Other (Service)" => "Service Change",
      "Other (Station)" => "Service Change",
      "Other (Stop)" => "Service Change",
      "Out of Service" => "Access Issue",
      "Shuttle Bus" => "Shuttle Bus"
    }

    Map.get(mappings, ibi_alert.effect_name, ibi_alert.effect_name)
  end

  def from_ibi(ibi_alert, :created_timestamp) do
    utc_from_ibi_string(ibi_alert.created_dt)
  end

  def from_ibi(ibi_alert, :closed_timestamp) do
    if ibi_alert.is_closed == "True" do
      from_ibi(ibi_alert, :active_period_end) ||
        from_ibi(ibi_alert, :notification_period_end)
    else
      nil
    end
  end

  def from_ibi(ibi_alert, :last_modified_timestamp) do
    utc_from_ibi_string(ibi_alert.last_modified_dt)
  end

  def from_ibi(ibi_alert, :image_url), do: ibi_alert.alert_image_url

  def from_ibi(ibi_alert, :image_alternative_text), do: ibi_alert.alert_image_description

  def from_ibi(_ibi_alert, :legacy), do: true

  def from_ibi(ibi_alert, key), do: Map.get(ibi_alert, key)

  defp split_combined_entities(nil), do: []

  defp split_combined_entities(combined_entities) do
    combined_entities
    |> String.replace("_", "")
    |> String.split(";")
    |> Enum.map(fn combined ->
      combined
      |> String.split("|")
      |> Enum.reverse()
      |> Enum.join("|")
    end)
  end

  def utc_from_ibi_string(nil), do: nil

  def utc_from_ibi_string(timestamp) do
    if timestamp =~ ~r/\// do
      Timex.parse!(timestamp, "{M}/{D}/{YYYY} {h12}:{m}:{s} {AM}")
    else
      time =
        timestamp
        |> Timex.parse!("{h24}:{m}:{s}")
        |> NaiveDateTime.to_time()

      NaiveDateTime.new!(Date.utc_today(), time)
    end
    |> DateTime.from_naive!("America/New_York")
    |> DateTime.shift_zone!("Etc/UTC")
  end

  def utc_from_ibi_reminder_format(timestamp) do
    timestamp
    |> String.replace("T", " ")
    |> String.replace(~r/\:[0-9]*\.[0-9]*$/, "")
    |> Kernel.<>(":00")
    |> NaiveDateTime.from_iso8601!()
    |> DateTime.from_naive!("America/New_York")
    |> DateTime.shift_zone!("Etc/UTC")
  end

  def extract_reminders(ibi_alert, alert) do
    if ibi_alert.reminders do
      ibi_alert.reminders
      |> String.replace("send bulletin", "")
      |> String.replace("send tweet", "")
      |> String.replace("and tweet", "")
      |> String.replace(~r/\s/, "")
      |> String.split(";")
      |> Enum.map(fn timestamp ->
        %{id: nil, alert_id: alert.id, reminder_time: utc_from_ibi_reminder_format(timestamp)}
      end)
    else
      []
    end
  end

  def gui_mode_name_to_route_type_int(name) do
    case name do
      "Systemwide" -> nil
      "Access" -> nil
      "Elev/Esc" -> nil
      "Subway" -> 1
      "Commuter Rail" -> 2
      "Bus" -> 3
      "Boat" -> 4
      _ -> nil
    end
  end
end
