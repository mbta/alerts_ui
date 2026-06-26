defmodule AlertsUI.Jobs.CacheRefreshWorker do
  @moduledoc """
  Periodically clears and re-warms the MBTA API caches.

  The MBTA API caches use lazy-write (writes only on cache miss), so a warming job that runs
  while entries are still valid would just return cached data without refreshing. Clearing first
  forces a miss, ensuring fresh data is written on each run.
  """
  use Oban.Worker, max_attempts: 1

  alias MBTAV3API.Facilities
  alias MBTAV3API.Routes
  alias MBTAV3API.Stops

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    Stops.Repo.clear_cache()
    Routes.Repo.clear_cache()
    Facilities.Repo.clear_cache()

    AlertsUI.CacheWarming.warm_all()
    :ok
  end
end
