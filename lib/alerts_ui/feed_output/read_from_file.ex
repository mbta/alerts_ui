defmodule AlertsUI.FeedOutput.ReadFile do
  @moduledoc """
    defines behavior for reading a file
  """
  @callback read(flavor :: atom()) :: :error | {:ok, any()}
end

defmodule AlertsUI.FeedOutput.ReadFromS3 do
  @moduledoc """
    Reads file from S3 bucket.
  """
  alias ExAws.S3
  @behaviour AlertsUI.FeedOutput.ReadFile

  @spec read(atom()) :: :error | {:ok, any()}
  def read(flavor \\ :enhanced_json) do
    make_request_fn = AlertsUI.config(:make_request_fn, &ExAws.request!/1)

    alerts_manager_feed(flavor)
    |> make_request_fn.()
    |> parse_response()
  end

  defp alerts_manager_feed(flavor) do
    get_obj_fn = AlertsUI.config(:get_obj_fn, &S3.get_object/2)

    get_obj_fn.(s3_bucket_name(), s3_file_path(flavor))
  end

  defp s3_bucket_name,
    do: "mbta-alerts-ui"

  defp s3_file_path(flavor),
    do: "#{AlertsUI.config(:s3_bucket_prefix)}/#{filename(flavor)}"

  defp filename(flavor) do
    key = String.to_existing_atom("#{Atom.to_string(flavor)}_output_filename")
    AlertsUI.config(key)
  end

  defp parse_response(%{status: 200, body: json_body}),
    do: {:ok, convert_newlines(json_body)}

  defp parse_response(%{status_code: 200, body: json_body}),
    do: {:ok, json_body}

  defp parse_response(_),
    do: :error

  defp convert_newlines(text), do: String.replace(text, "\r\n", "\n")
end

defmodule AlertsUI.FeedOutput.ReadLocal do
  @moduledoc """
    Reads file from local path
  """
  @behaviour AlertsUI.FeedOutput.ReadFile

  # sobelow_skip ["Traversal.FileModule"]
  @spec read(atom()) :: :error | {:ok, any()}
  def read(flavor \\ :enhanced_json) do
    path = "./assets/outputs/" <> filename(flavor)
    File.read(path)
  end

  defp filename(flavor) do
    key = String.to_existing_atom("#{Atom.to_string(flavor)}_output_filename")
    AlertsUI.config(key)
  end
end

defmodule AlertsUI.FeedOutput.ReadNowhere do
  @moduledoc """
    Does nothing and returns :ok (for testing)
  """
  @behaviour AlertsUI.FeedOutput.ReadFile

  @spec read(atom()) :: {:ok, any()}
  def read(_flavor) do
    {:ok, "abc"}
  end
end
