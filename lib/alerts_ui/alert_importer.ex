defmodule AlertsUI.AlertImporter do
  @moduledoc """
  Import alerts from an external source, e.g., IBI.
  """

  @default_chunk_size 1000

  def import_csv_file(path, options \\ []) do
    Repo.transaction(fn ->
      path
      |> File.stream!()
      |> CSV.decode()
      |> Stream.map(fn row -> row_to_changeset(row) end)
      |> Stream.chunk_every(chunk_size())
      |> Stream.each(fn chunk ->
        Enum.reduce(chunk, Multi.new(), fn changeset, multi ->
          PaperTrail.Multi.insert(multi, changeset)
        end)
        |> Multi.run()
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
