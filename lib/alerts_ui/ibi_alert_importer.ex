NimbleCSV.define(IBIAlertImportParser, [])

defmodule AlertsUI.IBIAlertImporter do
  @moduledoc """
  Import alerts from the IBI CSV export.
  """
  require Logger

  import Ecto.Query

  alias Ecto.Multi
  alias AlertsUI.AlertBuilder
  alias AlertsUI.Repo
  alias AlertsUI.Models.Alert
  alias AlertsUI.Models.IBIAlert
  alias AlertsUI.Models.LatestIBIAlert

  @default_chunk_size 1000

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

  def convert_ibi_alerts(options \\ []) do
    Repo.transact(
      fn ->
        LatestIBIAlert
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

            alert =
              insert
              |> ibi_alert_to_changeset(%Alert{},
                open: currently_open && latest_version.version_no == insert.version_no
              )
              |> PaperTrail.insert!()

            Enum.each(updates, fn update ->
              update
              |> ibi_alert_to_changeset(alert, open: currently_open && latest_version == update)
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

  def ibi_alert_to_changeset(ibi_alert, am_alert \\ %Alert{}, options \\ [])

  def ibi_alert_to_changeset(ibi_alert, am_alert, [open: true] = options) do
    ibi_alert
    |> ibi_alert_to_changeset(am_alert, Keyword.put(options, :open, false))
    |> Alert.open_changeset(%{})
  end

  def ibi_alert_to_changeset(ibi_alert, am_alert, _options) do
    params =
      ibi_alert
      |> ibi_alert_to_alert_data()
      # probably need to supply current time here?
      |> AlertBuilder.build_alert(from_ibi(ibi_alert, :combination))
      |> Map.put(:alert_id, ibi_alert.alert_id)

    Alert.minimal_changeset(am_alert, params)
  end

  def ibi_alert_to_alert_data(ibi_alert) do
    # alert data fields
    [
      :alert_id,
      :route_type,
      :route_ids,
      :stop_ids,
      :stop_names_and_ids,
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
      :combination
    ]
    |> Enum.reduce(%{}, fn key, alert_data ->
      try do
        Map.put(alert_data, key, from_ibi(ibi_alert, key))
      rescue
        e -> Logger.error("alert #{ibi_alert.alert_id} / #{key}: #{e.message}") && raise(e)
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
      |> Enum.map(fn day -> :"#{day}" end)
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

  def from_ibi(ibi_alert, key), do: Map.get(ibi_alert, key)

  defp split_combined_ids(nil), do: []

  defp split_combined_ids(combined_ids) do
    combined_ids
    |> String.replace("_", "")
    |> String.replace(~r/\s/, "")
    |> String.split(",")
  end

  defp ndt_from_ibi_string(timestamp) do
    if timestamp =~ ~r/\// do
      Timex.parse!(timestamp, "{M}/{D}/{YYYY} {h12}:{m}:{s} {AM}")
    else
      Timex.parse!(timestamp, "{h24}:{m}:{s}")
    end
  end

  defp ndt_from_ibi_reminder_format(timestamp) do
    timestamp
    |> String.replace("T", " ")
    |> String.replace(~r/\:[0-9]*\.[0-9]*$/, "")
    |> Kernel.<>(":00")
    |> NaiveDateTime.from_iso8601!()
  end
end
