defmodule AlertsUIWeb.SocketHelpers do
  import Phoenix.LiveView, only: [connected?: 1, get_connect_params: 1]

  def remount?(socket) do
    connected?(socket) && (get_connect_params(socket)["_mounts"] || 0) > 0
  end
end
