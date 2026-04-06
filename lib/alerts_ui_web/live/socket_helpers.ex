defmodule AlertsUIWeb.SocketHelpers do
  import Phoenix.LiveView, only: [connected?: 1, get_connect_params: 1]
  import Phoenix.Component, only: [assign: 3]

  @doc """
  To be called after `mount/3` (and after `mark_if_remounted/1` below) in handlers.
  """
  def remounted?(socket) do
    !!(Map.get(socket.assigns, :remounted))
  end

  @doc """
  To be called in `mount/3` to determine whether a socket it undergoing remount.
  """
  def remounting?(socket) do
    connected?(socket) && (get_connect_params(socket)["_mounts"] || 0) > 0
  end

  @doc """
  To be called in `mount/3` to mark a socket as remounted.
  """
  def mark_if_remounted(socket) do
    if remounting?(socket) do
      assign(socket, :remounted, true)
    else
      socket
    end
  end
end
