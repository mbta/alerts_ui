defmodule AlertsUIWeb.SFTPDemoLive do
  @moduledoc """
  LiveView for demonstrating SFTP config
  """

  use AlertsUIWeb, :live_view
  alias AlertsUI.Trapeze.SFTP

  @test_config %{
    host: "mbtaftp.mbta.com",
    port: 10_022,
    user: "mbtaeamrtest",
    filename: "/MBTAEAMTEST/T-Alert/file.txt"
  }

  @prod_config %{
    host: "mbtaftp.mbta.com",
    port: 10_022,
    user: "mbtaeamr1",
    filename: "/MBTAEAM/T-Alert/file.txt"
  }

  @configurations [test: @test_config, production: @prod_config]

  @impl true
  def mount(_params, _session, socket) do
    config_key = elem(hd(@configurations), 0)

    {:ok,
     assign(socket,
       config_key: config_key,
       password: "",
       configurations: @configurations,
       output: sftp_fetch(config_key, "")
     )}
  end

  @impl true
  def handle_event("submit", %{"config_key" => config_key, "password" => password}, socket) do
    {:noreply,
     assign(socket,
       config_key: config_key,
       password: password,
       output: sftp_fetch(String.to_existing_atom(config_key), password)
     )}
  end

  defp sftp_fetch(_, ""), do: "Empty Password"
  defp sftp_fetch(_, nil), do: "Empty Password"

  defp sftp_fetch(key, password) do
    config = @configurations[key] |> Map.merge(%{password: password})

    case SFTP.fetch(config) do
      {:ok, {data, nil}} ->
        ["Unable to load filestat, but that's ok." | data]
        |> Enum.join("\n")

      {:ok, {data, mtime}} ->
        [NaiveDateTime.to_iso8601(mtime) | data]
        |> Enum.join("\n")

      {:error, reason} ->
        "ERROR: #{inspect(reason)}"
    end
  end

  defp config_to_string(%{
         host: host,
         port: port,
         user: user,
         filename: filename
       }) do
    "sftp://#{user}:***@#{host}:#{port}#{filename}"
  end
end
