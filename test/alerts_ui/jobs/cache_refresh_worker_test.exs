defmodule AlertsUI.Jobs.CacheRefreshWorkerTest do
  use ExUnit.Case, async: false

  import Mock

  alias AlertsUI.CacheWarming
  alias AlertsUI.Jobs.CacheRefreshWorker
  alias MBTAV3API.Facilities
  alias MBTAV3API.Routes
  alias MBTAV3API.Stops
  alias Oban.Job

  describe "perform/1" do
    test "clears all repo caches and warms them" do
      with_mock(Stops.Repo, clear_cache: fn -> :ok end) do
        with_mock(Routes.Repo, clear_cache: fn -> :ok end) do
          with_mock(Facilities.Repo, clear_cache: fn -> :ok end) do
            with_mock(CacheWarming, warm_all: fn -> :ok end) do
              result = CacheRefreshWorker.perform(%Job{args: %{}})

              assert result == :ok
              assert_called(Stops.Repo.clear_cache())
              assert_called(Routes.Repo.clear_cache())
              assert_called(Facilities.Repo.clear_cache())
              assert_called(CacheWarming.warm_all())
            end
          end
        end
      end
    end

    test "clears caches before warming" do
      call_order = :ets.new(:call_order, [:ordered_set, :public])

      with_mock(Stops.Repo,
        clear_cache: fn ->
          :ets.insert(call_order, {:stops_clear, :ets.info(call_order, :size)})
          :ok
        end
      ) do
        with_mock(Routes.Repo,
          clear_cache: fn ->
            :ets.insert(call_order, {:routes_clear, :ets.info(call_order, :size)})
            :ok
          end
        ) do
          with_mock(Facilities.Repo,
            clear_cache: fn ->
              :ets.insert(call_order, {:facilities_clear, :ets.info(call_order, :size)})
              :ok
            end
          ) do
            with_mock(CacheWarming,
              warm_all: fn ->
                :ets.insert(call_order, {:warm_all, :ets.info(call_order, :size)})
                :ok
              end
            ) do
              CacheRefreshWorker.perform(%Job{args: %{}})

              ordered = call_order |> :ets.tab2list() |> Enum.sort_by(&elem(&1, 1))
              operation_order = Enum.map(ordered, &elem(&1, 0))

              warm_index = Enum.find_index(operation_order, &(&1 == :warm_all))
              clears = [:stops_clear, :routes_clear, :facilities_clear]

              for clear <- clears do
                clear_index = Enum.find_index(operation_order, &(&1 == clear))
                assert clear_index < warm_index, "#{clear} should happen before warm_all"
              end
            end
          end
        end
      end

      :ets.delete(call_order)
    end
  end
end
