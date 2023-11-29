defmodule AlertsUI.FeedOutput.WriteFile do
  @moduledoc """
    defines behavior for writing a file
  """
  @callback write(filename :: String.t(), content :: binary()) ::
              :ok | :ok | {:error, term()}
end

defmodule AlertsUI.FeedOutput.WriteToS3 do
  @moduledoc """
    Writes file to S3 bucket.
    There is only one bucket, different environments
    go to different file paths
  """
  @behaviour AlertsUI.FeedOutput.WriteFile
  @bucket_name System.get_env("S3_BUCKET_NAME", "")
  @bucket_prefix System.get_env("S3_BUCKET_PREFIX", "")

  def write(filename, content) do
    filepath = "#{@bucket_prefix}/#{filename}"

    case ExAws.S3.put_object(@bucket_name, filepath, content) |> ExAws.request!() do
      {:ok, _term} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
end

defmodule AlertsUI.FeedOutput.WriteLocal do
  @moduledoc """
    Writes file to local path
  """
  @behaviour AlertsUI.FeedOutput.WriteFile

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
