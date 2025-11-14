# credo:disable-for-this-file

NimbleCSV.define(AlertsUI.IBIAlertImportParser, [])

defmodule AlertsUI.IBIAlertImporter do
  @moduledoc """
  Import alerts from the IBI CSV export.
  """
  require Logger

  import Ecto.Query

  alias AlertsUI.AlertBuilder
  alias AlertsUI.IBIAlertImportParser
  alias AlertsUI.Models.Alert
  alias AlertsUI.Models.IBIAlert
  alias AlertsUI.Models.LatestIBIAlert
  alias AlertsUI.Repo
  alias Ecto.Adapters.SQL
  alias Ecto.Multi

  @default_chunk_size 1000

  def import_ibi_alerts(path) do
    Repo.transact(
      fn ->
        ingest_csv_file(path)
        fix_invalid_timestamps()
        convert_ibi_alerts()
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
    - For each chunk:
        - Find all versions of existing alerts by `alert_id`
        - Index those versions by a tuple of `{alert_id, version_no}`
        - Create a `Multi` for the chunk
        - For every row in the chunk, check for an existing alert in the index. If present, attach an update to the multi; otherwise attach an insert
        - Commit the multi

  The entire operation is wrapped in a transaction, so input files will succeed or fail
  but never a mix of both.
  """
  @spec ingest_csv_file(String.t(), chunk_size: integer()) :: {:ok, map()} | Ecto.Multi.failure()
  def ingest_csv_file(path, options \\ []) do
    Repo.transact(
      fn ->
        path
        |> File.stream!()
        |> IBIAlertImportParser.parse_stream()
        |> Stream.chunk_every(chunk_size(options))
        |> Stream.each(fn chunk ->
          alert_ids = Enum.map(chunk, fn row -> row_to_alert_id(row) end)

          existing_alerts_index =
            Repo.all(from i in IBIAlert, where: i.alert_id in ^alert_ids)
            |> Map.new(fn alert ->
              {{alert.alert_id, alert.version_no}, alert}
            end)

          Enum.reduce(chunk, Multi.new(), fn row, multi ->
            if Enum.at(row, 0) == "alert_version_id" do
              multi
            else
              versioned_id = {row_to_alert_id(row), row_to_version_no(row)}

              case existing_alerts_index[versioned_id] do
                nil ->
                  changeset = IBIAlert.changeset(%IBIAlert{}, row_to_params(row))
                  Multi.insert(multi, versioned_id, changeset)

                alert ->
                  changeset = IBIAlert.changeset(alert, row_to_params(row))
                  Multi.update(multi, versioned_id, changeset)
              end
            end
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
        Repo.update_all(
          from(i in IBIAlert, where: like(i.notif_start, "11/5/2017 1:05%")),
          set: [notif_start: "11/5/2017 2:05:00 AM", effect_start: "11/5/2017 2:05:00 AM"]
        )

        Repo.update_all(
          from(i in IBIAlert, where: like(i.notif_end, "3/9/2014 2:30%")),
          set: [notif_end: "3/9/2014 3:30:00 AM", effect_end: "3/9/2014 3:30:00 AM"]
        )

        Repo.update_all(
          from(i in IBIAlert, where: like(i.notif_end, "3/8/2015 2:30%")),
          set: [notif_end: "3/8/2015 3:30:00 AM", effect_end: "3/8/2015 3:30:00 AM"]
        )

        Repo.update_all(
          from(i in IBIAlert, where: like(i.notif_end, "11/1/2015 1:39%")),
          set: [notif_end: "11/1/2015 2:39:00 AM", effect_end: "11/1/2015 2:39:00 AM"]
        )

        Repo.update_all(
          from(i in IBIAlert, where: like(i.notif_end, "3/13/2016 2:30%")),
          set: [notif_end: "3/13/2016 3:30:00 AM", effect_end: "3/13/2016 3:30:00 AM"]
        )

        Repo.update_all(
          from(i in IBIAlert, where: like(i.notif_end, "3/11/2018 2:30%")),
          set: [notif_end: "3/11/2018 3:30:00 AM", effect_end: "3/11/2018 3:30:00 AM"]
        )

        Repo.update_all(
          from(i in IBIAlert, where: like(i.notif_end, "3/10/2019 2:30%")),
          set: [notif_end: "3/10/2019 3:30:00 AM", effect_end: "3/10/2019 3:30:00 AM"]
        )

        Repo.update_all(
          from(i in IBIAlert, where: like(i.notif_end, "3/8/2020 2:30%")),
          set: [notif_end: "3/8/2020 3:30:00 AM", effect_end: "3/8/2020 3:30:00 AM"]
        )

        Repo.update_all(
          from(i in IBIAlert, where: like(i.notif_end, "3/14/2021 2:30%")),
          set: [notif_end: "3/14/2021 3:30:00 AM", effect_end: "3/14/2021 3:30:00 AM"]
        )

        Repo.update_all(
          from(i in IBIAlert, where: like(i.notif_end, "3/13/2022 2:30%")),
          set: [notif_end: "3/13/2022 3:30:00 AM", effect_end: "3/13/2022 3:30:00 AM"]
        )

        Repo.update_all(
          from(i in IBIAlert, where: like(i.notif_end, "3/12/2023 2:30%")),
          set: [notif_end: "3/12/2023 3:30:00 AM", effect_end: "3/12/2023 3:30:00 AM"]
        )

        Repo.update_all(
          from(i in IBIAlert, where: like(i.notif_end, "3/10/2024 2:30%")),
          set: [notif_end: "3/10/2024 3:30:00 AM", effect_end: "3/10/2024 3:30:00 AM"]
        )

        Repo.update_all(
          from(i in IBIAlert, where: like(i.notif_end, "3/9/2025 2:59%")),
          set: [notif_end: "3/9/2025 3:59:00 AM", effect_end: "3/9/2025 3:59:00 AM"]
        )

        Repo.update_all(
          from(i in IBIAlert, where: like(i.notif_end, "11/2/2014 1:19%")),
          set: [notif_end: "11/2/2014 2:19:00 AM", effect_end: "11/2/2014 2:19:00 AM"]
        )

        Repo.update_all(
          from(i in IBIAlert, where: like(i.notif_end, "11/6/2022 1:40%")),
          set: [notif_end: "11/6/2022 2:40:00 AM", effect_end: "11/6/2022 2:40:00 AM"]
        )

        Repo.update_all(
          from(i in IBIAlert, where: like(i.notif_end, "11/7/2021 1:07%")),
          set: [notif_end: "11/7/2021 2:07:00 AM", effect_end: "11/7/2021 2:07:00 AM"]
        )

        Repo.update_all(
          from(i in IBIAlert, where: like(i.notif_end, "11/3/2024 1:07%")),
          set: [notif_end: "11/3/2024 2:07:00 AM", effect_end: "11/3/2024 2:07:00 AM"]
        )

        Repo.update_all(
          from(i in IBIAlert, where: like(i.notif_end, "11/3/2024 1:07%")),
          set: [notif_end: "11/3/2024 2:07:00 AM", effect_end: "11/3/2024 2:07:00 AM"]
        )

        Repo.update_all(
          from(i in IBIAlert, where: like(i.notif_end, "11/1/2020 1:15%")),
          set: [notif_end: "11/1/2020 2:15:00 AM", effect_end: "11/1/2020 2:15:00 AM"]
        )

        # years set to 8888/9999
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

        # fix >24 clock timestamps
        Enum.each(24..47, fn digit ->
          SQL.query!(
            Repo,
            "update ibi_alerts set recurrence_start_time = regexp_replace(recurrence_start_time, '^#{digit}', '#{rem(digit, 24) |> Integer.to_string() |> String.pad_leading(2, "0")}') where recurrence_start_time like '#{digit}%'"
          )

          SQL.query!(
            Repo,
            "update ibi_alerts set recurrence_end_time = regexp_replace(recurrence_end_time, '^#{digit}', '#{rem(digit, 24) |> Integer.to_string() |> String.pad_leading(2, "0")}') where recurrence_end_time like '#{digit}%'"
          )
        end)

        {:ok, true}
      end,
      timeout: :infinity
    )
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
      if Keyword.get(options, :import_open_alerts) do
        LatestIBIAlert
      else
        from i in LatestIBIAlert, where: i.is_closed == "True"
      end

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
              |> PaperTrail.insert!(returning: true)
              |> Repo.preload([:informed_entity, :active_period])

            Enum.each(updates, fn update ->
              update_open = currently_open && update.version_no == latest_version.version_no

              update
              |> ibi_alert_to_changeset(
                alert,
                no_active_periods: !update_open,
                no_informed_entities: !update_open
              )
              |> PaperTrail.update!()
            end)
          end)
        end)
        |> Stream.run()

        {:ok, true}
      end,
      timeout: :infinity
    )
  end

  def ibi_alert_to_changeset(ibi_alert, am_alert, options \\ []) do
    options = Keyword.put(options, :no_recurrence_days_validation, true)

    params =
      ibi_alert
      |> ibi_alert_to_alert_data()
      |> AlertBuilder.build_alert(from_ibi(ibi_alert, :combination), DateTime.utc_now(), options)
      |> Map.put(:alert_id, ibi_alert.alert_id)

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
      :reminder_times,
      :alert_timing,
      :active_period_start,
      :active_period_end,
      :active_period_start_date,
      :active_period_start_time,
      :active_period_end_date,
      :active_period_end_time,
      :recurrence_days,
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
      :original_facility_selections
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

  defp row_to_alert_id(row), do: Enum.at(row, 1)

  defp row_to_version_no(row), do: Enum.at(row, 2)

  defp row_to_params(row) do
    row
    |> Enum.with_index()
    |> Enum.reduce(%{}, fn {value, index}, params ->
      case Enum.at(IBIAlert.fields(), index) do
        nil -> raise "no field name at index #{index}"
        field_name -> Map.put(params, field_name, value)
      end
    end)
  end

  @spec from_ibi(IBIAlert.t(), atom()) :: any()
  def from_ibi(ibi_alert, :route_type) do
    case ibi_alert.gui_mode_name do
      "Systemwide" -> nil
      "Access" -> 0
      "Elev/Esc" -> 0
      "Subway" -> 1
      "Commuter Rail" -> 2
      "Bus" -> 3
      "Boat" -> 4
    end
  end

  def from_ibi(ibi_alert, :route_ids) do
    split_combined_ids(ibi_alert.informed_route_id)
  end

  def from_ibi(ibi_alert, :stop_ids) do
    split_combined_ids(ibi_alert.informed_stop_id)
  end

  def from_ibi(ibi_alert, :trip_ids) do
    split_combined_ids(ibi_alert.informed_trip_id)
  end

  def from_ibi(ibi_alert, :direction) do
    ibi_alert.informed_direction_id
  end

  def from_ibi(ibi_alert, :facility_id), do: ibi_alert.informed_facility_id

  def from_ibi(ibi_alert, :service_types), do: [from_ibi(ibi_alert, :route_type)]

  def from_ibi(ibi_alert, :reminder_times) do
    if ibi_alert.reminders do
      ibi_alert.reminders
      |> String.replace("send bulletin", "")
      |> String.replace("send tweet", "")
      |> String.replace("and tweet", "")
      |> String.replace(~r/\s/, "")
      |> String.split(";")
      |> Enum.map(fn timestamp -> ndt_from_ibi_reminder_format(timestamp) end)
    else
      []
    end
  end

  def from_ibi(ibi_alert, :alert_timing) do
    case ibi_alert.alert_time_type do
      "Recurring" -> :recurring
      _ -> :one_time
    end
  end

  def from_ibi(ibi_alert, :active_period_start) do
    # this field must be populated so no `if` here (and all IBI alerts that
    # lack `effect_start` have `notif_start`)
    ndt_from_ibi_string(ibi_alert.effect_start || ibi_alert.notif_start)
  end

  def from_ibi(ibi_alert, :active_period_end) do
    if ibi_alert.effect_end do
      ndt_from_ibi_string(ibi_alert.effect_end)
    end
  end

  def from_ibi(ibi_alert, :active_period_start_time) do
    if ibi_alert.recurrence_start_time do
      ndt_from_ibi_string(ibi_alert.recurrence_start_time) |> NaiveDateTime.to_time()
    end
  end

  def from_ibi(ibi_alert, :active_period_end_time) do
    if ibi_alert.recurrence_end_time do
      ndt_from_ibi_string(ibi_alert.recurrence_end_time) |> NaiveDateTime.to_time()
    end
  end

  def from_ibi(ibi_alert, :active_period_start_date) do
    if ibi_alert.recurrence_start do
      ndt_from_ibi_string(ibi_alert.recurrence_start) |> NaiveDateTime.to_date()
    end
  end

  def from_ibi(ibi_alert, :active_period_end_date) do
    if ibi_alert.recurrence_end do
      ndt_from_ibi_string(ibi_alert.recurrence_end) |> NaiveDateTime.to_date()
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
      ndt_from_ibi_string(ibi_alert.notif_start)
    end
  end

  def from_ibi(ibi_alert, :notification_period_end) do
    if ibi_alert.notif_end do
      ndt_from_ibi_string(ibi_alert.notif_end)
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
      ibi_alert.informed_route_id && ibi_alert.informed_direction_id && ibi_alert.informed_trip_id &&
          ibi_alert.informed_stop_id ->
        :RDTS

      ibi_alert.informed_route_id && ibi_alert.informed_direction_id && ibi_alert.informed_trip_id ->
        :RDT

      ibi_alert.informed_route_id && ibi_alert.informed_direction_id && ibi_alert.informed_stop_id ->
        :RDS

      ibi_alert.informed_route_id && ibi_alert.informed_stop_id ->
        :SR

      ibi_alert.informed_route_id ->
        :R

      ibi_alert.informed_facility_id ->
        :ACCESS

      true ->
        nil
    end
  end

  def from_ibi(ibi_alert, :original_direction_selections) do
    Enum.filter([from_ibi(ibi_alert, :direction)], & &1)
  end

  def from_ibi(ibi_alert, :original_facility_selections) do
    Enum.filter([from_ibi(ibi_alert, :facility_id)], & &1)
  end

  def from_ibi(ibi_alert, :original_route_selections), do: from_ibi(ibi_alert, :route_ids)
  def from_ibi(ibi_alert, :original_trip_selections), do: from_ibi(ibi_alert, :trip_ids)

  def from_ibi(ibi_alert, key), do: Map.get(ibi_alert, key)

  defp split_combined_ids(nil), do: []

  defp split_combined_ids(combined_ids) do
    combined_ids
    |> String.replace("_", "")
    |> String.replace(~r/\s/, "")
    |> String.split(",")
  end

  def ndt_from_ibi_string(timestamp) do
    if timestamp =~ ~r/\// do
      Timex.parse!(timestamp, "{M}/{D}/{YYYY} {h12}:{m}:{s} {AM}")
    else
      Timex.parse!(timestamp, "{h24}:{m}:{s}")
    end
  end

  def ndt_from_ibi_reminder_format(timestamp) do
    timestamp
    |> String.replace("T", " ")
    |> String.replace(~r/\:[0-9]*\.[0-9]*$/, "")
    |> Kernel.<>(":00")
    |> NaiveDateTime.from_iso8601!()
  end
end
