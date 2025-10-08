NimbleCSV.define(IBIAlertParser)

defmodule AlertsUI.AlertImporter do
  @moduledoc """
  Import alerts from an external source, e.g., IBI.
  """

  @default_chunk_size 1000

  @spec import_csv_file(String.t(), [chunk_size: integer()]) :: {:ok, map()} | Ecto.Multi.failure()
  def import_csv_file(path, options \\ []) do
    Repo.transaction(fn ->
      path
      |> File.stream!()
      |> IBIAlertParser.parse_stream()
      |> Stream.map(fn row -> row_to_changeset(row) end)
      |> Stream.chunk_every(chunk_size())
      |> Stream.each(fn chunk ->
        Enum.reduce(chunk, Multi.new(), fn changeset, multi ->
          PaperTrail.Multi.insert(multi, changeset)
        end)
        |> Repo.transaction()
      end)
    end)
  end

  defp chunk_size(options) do
    Keyword.get(options, :chunk_size, @default_chunk_size)
  end

  defp row_to_changeset(row) do
    Alert.changeset(%Alert{}, row_to_alert_data(params))
  end

  defp row_to_alert_data(row) do
  end
end
