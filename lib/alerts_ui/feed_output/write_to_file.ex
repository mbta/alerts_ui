defmodule AlertsUI.FeedOutput.WriteFile do
  @moduledoc """
    defines behavior for writing a file
  """
  @callback write(filename :: String.t(), content :: binary()) ::
              :ok | {:error, term()}
end

defmodule AlertsUI.FeedOutput.WriteToS3 do
  @moduledoc """
    Writes file to S3 bucket.
    There is only one bucket, different environments
    go to different file paths
  """
  @behaviour AlertsUI.FeedOutput.WriteFile

  def write(filename, content) do
    case ExAws.S3.put_object(get_bucket_name(), get_file_path(filename), content)
         |> ExAws.request() do
      {:ok, _term} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp get_bucket_name do
    System.get_env("S3_BUCKET_NAME", "")
  end

  defp get_file_path(filename) do
    "#{System.get_env("S3_BUCKET_PREFIX", "")}/#{filename}"
  end
end

defmodule AlertsUI.FeedOutput.WriteLocal do
  @moduledoc """
    Writes file to local path
  """
  @behaviour AlertsUI.FeedOutput.WriteFile

  # sobelow_skip ["Traversal.FileModule"]
  def write(filename, content) do
    path = "./assets/outputs/" <> filename
    File.write(path, content)
  end
end

defmodule AlertsUI.FeedOutput.WriteNowhere do
  @moduledoc """
    Does nothing and returns :ok (for testing)
  """
  @behaviour AlertsUI.FeedOutput.WriteFile

  def write(_filename, _content) do
    :ok
  end
end
