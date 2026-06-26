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
    warm_routes()
    warm_stops()
    warm_facilities()
    Logger.info("MBTA API cache warming complete")
  end

  defp warm_routes do
    # Standard route types used in the alert form
    CreateAlertLive.get_routes([0, 1, 2, 3])
    # Unlisted routes (type 4)
    CreateAlertLive.get_routes([4])
  end

  defp warm_stops do
    # Bus stops for the stop-route combination selector (expensive: chunks all bus routes)
    CreateAlertLive.get_stops(nil, 3, nil)

    # Subway stops for stop-route combination (fetches types 0 and 1 together)
    CreateAlertLive.get_stops(nil, 1, nil)

    # Commuter rail stops for stop-route combination
    CreateAlertLive.get_stops_for_stop_route(nil, 2)

    # Ferry stops for stop-route combination
    CreateAlertLive.get_stops_for_stop_route(nil, 4)

    # Green Line stops (direction 0 covers all branches; direction is only used for ordering)
    CreateAlertLive.get_stops(["Green"], nil, "0")
  end

  defp warm_facilities do
    InformedEntity.all_facility_types() |> CreateAlertLive.get_facilities()
  end
end
