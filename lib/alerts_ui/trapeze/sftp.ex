defmodule AlertsUI.Trapeze.SFTP do
  @moduledoc """
  Downloads the Elevator/Escalator file from the Trapeze SFTP server
  """

  @spec source_description(map()) :: map()
  def source_description(override \\ %{}) do
    %{
      host: host(),
      port: port(),
      user: user(),
      password: password(),
      filename: filename()
    }
    |> Map.merge(override)
  end

  @spec host() :: String.t()
  def host, do: AlertsUI.config(:trapeze_sftp_host)

  @spec port() :: integer()
  def port do
    case Integer.parse(AlertsUI.config(:trapeze_sftp_port)) do
      {port, _} when is_integer(port) -> port
      _ -> 22
    end
  end

  @spec user() :: String.t()
  def user, do: AlertsUI.config(:trapeze_sftp_user)
  @spec password() :: String.t()
  def password, do: AlertsUI.config(:trapeze_sftp_password)
  @spec filename() :: String.t()
  def filename, do: AlertsUI.config(:trapeze_sftp_filename)

  @spec fetch(%{
          host: String.t(),
          port: integer(),
          user: String.t(),
          password: String.t(),
          filename: String.t()
        }) :: {:ok, {[String.t()], NaiveDateTime.t()}} | {:error, Exception.t()}
  def fetch(%{filename: filename} = source_description) do
    connection_arguments = Map.delete(source_description, :filename)

    SFTPClient.connect(connection_arguments, fn conn ->
      mtime =
        conn
        |> SFTPClient.file_info!(filename)
        |> Map.get(:mtime)

      mtime =
        case mtime do
          {date, time} -> NaiveDateTime.from_erl!({date, time})
          _ -> nil
        end

      feed =
        conn
        |> SFTPClient.stream_file!(filename)
        |> Enum.to_list()
        |> Enum.join("")
        |> String.split("\r\n")
        |> Enum.filter(&(&1 != ""))

      {feed, mtime}
    end)
  end
end
