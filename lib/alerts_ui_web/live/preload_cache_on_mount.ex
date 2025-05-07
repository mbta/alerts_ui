defmodule AlertsUIWeb.PreloadCacheOnMount do
  @moduledoc """
    Preloads the cache with expensive API calls
  """

  def on_mount(:default, _params, _session, socket) do
    if Application.get_env(:alerts_ui, :preload_cache?) do
      # preload api calls into cache to avoid load times
      # if we're in production
      AlertsUIWeb.CreateAlertLive.get_stops_for_stop_route(3, nil)
    end

    {:cont, socket}
  end
end
