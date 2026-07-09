defmodule AlertsUI.CacheWarming do
  @moduledoc """
  Preloads the MBTA API caches with the most commonly-requested data.

  Called at startup (via CacheWarmer) and periodically (via CacheRefreshWorker) to ensure
  users rarely see loading states waiting for live API calls.
  """

  require Logger

  alias AlertsUI.Models.InformedEntity
  alias AlertsUIWeb.CreateAlertLive

  def warm_all do
    Logger.info("Warming MBTA API caches")
    warm_stops()
    warm_facilities()
    warm_schedules()
    Logger.info("MBTA API cache warming complete")
  end

  defp warm_stops do
    # Bus stops for the stop-route combination selector (expensive: chunks all bus routes)
    CreateAlertLive.get_stops(nil, 3, nil)
  end

  defp warm_schedules do
    CreateAlertLive.get_routes([2, 4])
    |> Enum.map(& &1.id)
    |> CreateAlertLive.get_schedules_by_date("default", nil)
  end

  defp warm_facilities do
    InformedEntity.all_facility_types() |> CreateAlertLive.get_facilities()
  end
end
