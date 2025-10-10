NimbleCSV.define(IBIAlertImportParser, [])

defmodule AlertsUI.IBIAlertImporter do
  @moduledoc """
  Import alerts from the IBI CSV export.
  """
  import Ecto.Query

  alias Ecto.Multi
  alias AlertsUI.Repo
  alias AlertsUI.Models.IBIAlert

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
  @spec import_csv_file(String.t(), chunk_size: integer()) :: {:ok, map()} | Ecto.Multi.failure()
  def import_csv_file(path, options \\ []) do
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
end
