defmodule AlertsUI.SkateDetours.ReadFile do
  @moduledoc """
    defines behavior for writing a file
  """
  @callback read() ::
              :ok | {:error, term()}
end

defmodule AlertsUI.SkateDetours.ReadFromS3 do
  @moduledoc """
    Reads file from S3 bucket.
  """
  @behaviour AlertsUI.SkateDetours.ReadFile

  @spec read() :: {:ok, binary()} | {:error, any()}
  def read do
  require Logger;
  Logger.info("bucket name:")
  Logger.info(get_bucket_name())
  Logger.info("file path:")
  Logger.info(get_file_path())
    case ExAws.S3.get_object(get_bucket_name(), get_file_path())
         |> ExAws.request() do
      {:ok, term} -> {:ok, term}
      {:error, reason} -> {:error, reason}
    end
  end

  defp get_bucket_name do
    AlertsUI.config(:skate_bucket_name)
  end

  defp get_file_path do
    AlertsUI.config(:skate_file_path)
  end
end

defmodule AlertsUI.SkateDetours.ReadLocal do
  @moduledoc """
    Reads file from local path
  """
  @behaviour AlertsUI.SkateDetours.ReadFile

  # sobelow_skip ["Traversal.FileModule"]
  @spec read() :: {:ok, binary()} | {:error, any()}
  def read do
    path = "./test/support/fixtures/active.ndjson"
    File.read(path)
  end
end
