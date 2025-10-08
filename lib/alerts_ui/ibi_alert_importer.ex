NimbleCSV.define(IBIAlertImportParser, [])
defmodule AlertsUI.IBIAlertImporter do
  @moduledoc """
  Import alerts from the IBI CSV export.
  """

  alias AlertsUI.Models.IBIAlert, as: IBIAlert

  @default_chunk_size 1000

  @doc """
  Import a CSV file according to the format given by `IBIAlert.columns/0` as follows:
    - Stream a local file from `path`
    - Parse the stream of lines as CSV
    - Chunk the rows into manageable batches to mitigate N+1 overhead on query and commit
    - For each chunk:
        - Find and index any existing alerts for this chunk by `alert_id`
        - Create a `Multi` consisting of the insert and update operations for this chunk
        - Commit the multi
  
  The entire operation is wrapped in a transaction, so input files will succeed or fail
  but never a mix of both. 
  """
  @spec import_csv_file(String.t(), [chunk_size: integer()]) :: {:ok, map()} | Ecto.Multi.failure()
  def import_csv_file(path, options \\ []) do
    Repo.transact(fn ->
      path
      |> File.stream!()
      |> IBIAlertImportParser.parse_stream()
      |> Stream.chunk_every(chunk_size(options))
      |> Stream.each(fn chunk ->
        alert_ids = Enum.map(chunk, fn row -> row_to_alert_id(row) end)

        existing_alerts_index = Repo.all(
          from i in IBIAlert, where: i.alert_id in ^alert_ids
        ) |> Map.new(fn alert -> {alert.alert_id, alert} end)

        Enum.reduce(chunk, Multi.new(), fn row, multi ->
          case existing_alerts_index[row_to_alert_id(row)] do
            nil ->
              changeset = %IBIAlert.changeset(%IBIAlert{}, params)
              PaperTrail.Multi.insert(multi, changeset)
            alert ->
              changeset = %IBIAlert.changeset(alert, params)
              PaperTrail.Multi.update(multi, changeset)
          end
        end)
        |> Repo.transact()
      end)
    end)
  end

  defp chunk_size(options) do
    Keyword.get(options, :chunk_size, @default_chunk_size)
  end

  defp row_to_changeset(row, existing_alert_index) do
    alert = existing_alert_index[row_to_alert_id(row)] || %IBIAlert{}
    IBIAlert.changeset(alert, row_to_params(row))
  end

  def row_to_alert_id(row), do: row[1]

  def row_to_params(row = []) do
    row
    |> Enum.with_index()
    |> Enum.reduce(%{}, fn {value, index}, params ->
      case @fields[index] do
        nil -> raise "no field name at index #{index}"
        field_name -> Map.put(params, %{field_name => value})
      end
    end)
  end
end
