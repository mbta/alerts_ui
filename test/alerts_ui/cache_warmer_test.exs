defmodule AlertsUI.CacheWarmerTest do
  use ExUnit.Case, async: false

  import Mock

  alias AlertsUI.CacheWarmer
  alias AlertsUI.CacheWarming

  describe "run/0" do
    test "calls warm_all when preload_cache? is true" do
      Application.put_env(:alerts_ui, :preload_cache?, true)

      on_exit(fn -> Application.delete_env(:alerts_ui, :preload_cache?) end)

      with_mock(Process, [:passthrough], sleep: fn _ms -> :ok end) do
        with_mock(CacheWarming, warm_all: fn -> :ok end) do
          CacheWarmer.run()

          assert_called(CacheWarming.warm_all())
        end
      end
    end

    test "does not call warm_all when preload_cache? is false" do
      Application.put_env(:alerts_ui, :preload_cache?, false)

      on_exit(fn -> Application.delete_env(:alerts_ui, :preload_cache?) end)

      with_mock(CacheWarming, warm_all: fn -> :ok end) do
        CacheWarmer.run()

        assert_not_called(CacheWarming.warm_all())
      end
    end

    test "does not call warm_all when preload_cache? is not set" do
      Application.delete_env(:alerts_ui, :preload_cache?)

      with_mock(CacheWarming, warm_all: fn -> :ok end) do
        CacheWarmer.run()

        assert_not_called(CacheWarming.warm_all())
      end
    end

    test "sleeps before warming to allow app to fully start" do
      Application.put_env(:alerts_ui, :preload_cache?, true)

      on_exit(fn -> Application.delete_env(:alerts_ui, :preload_cache?) end)

      with_mock(Process, [:passthrough], sleep: fn _ms -> :ok end) do
        with_mock(CacheWarming, warm_all: fn -> :ok end) do
          CacheWarmer.run()

          assert_called(Process.sleep(2_000))
        end
      end
    end
  end
end
