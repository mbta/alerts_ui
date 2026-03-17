defmodule AlertsUI.CacheWarmer do
  @moduledoc """
    Preloads the cache with expensive API calls
  """
  use Task, restart: :transient

  def start_link(_arg) do
    Task.start_link(__MODULE__, :run, [])
  end

  def run do
    if Application.get_env(:alerts_ui, :preload_cache?) do
      # Small delay to ensure the app is fully started
      Process.sleep(2_000)
      AlertsUIWeb.CreateAlertLive.get_stops(nil, 3, nil)
    end
  end
end
