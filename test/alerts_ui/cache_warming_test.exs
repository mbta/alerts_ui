defmodule AlertsUI.CacheWarmingTest do
  use ExUnit.Case, async: false

  import Mock
  import ExUnit.CaptureLog
  import Test.Support.Helpers

  alias AlertsUI.CacheWarming
  alias AlertsUI.Models.InformedEntity
  alias AlertsUIWeb.CreateAlertHelpers

  describe "warm_all/0" do
    test "calls all warming functions and logs progress" do
      set_log_level(:info)

      with_mock(CreateAlertHelpers,
        get_routes: fn _types -> [] end,
        get_stops: fn _routes, _type, _dir -> [] end,
        get_stops_for_stop_route: fn _routes, _type -> [] end,
        get_facilities: fn _types -> [] end
      ) do
        {result, log} = with_log(fn -> CacheWarming.warm_all() end)

        assert result == :ok
        assert log =~ "Warming MBTA API caches"
        assert log =~ "MBTA API cache warming complete"
      end
    end

    test "warms standard and unlisted route types" do
      with_mock(CreateAlertHelpers,
        get_routes: fn _types -> [] end,
        get_stops: fn _routes, _type, _dir -> [] end,
        get_stops_for_stop_route: fn _routes, _type -> [] end,
        get_facilities: fn _types -> [] end
      ) do
        CacheWarming.warm_all()

        assert_called(CreateAlertHelpers.get_routes([3]))
      end
    end

    test "warms stops for all service modes" do
      with_mock(CreateAlertHelpers,
        get_routes: fn _types -> [] end,
        get_stops: fn _routes, _type, _dir -> [] end,
        get_stops_for_stop_route: fn _routes, _type -> [] end,
        get_facilities: fn _types -> [] end
      ) do
        CacheWarming.warm_all()

        assert_called(CreateAlertHelpers.get_stops(nil, 3, nil))
        assert_called(CreateAlertHelpers.get_stops(nil, 1, nil))
        assert_called(CreateAlertHelpers.get_stops_for_stop_route(nil, 2))
        assert_called(CreateAlertHelpers.get_stops_for_stop_route(nil, 4))
      end
    end

    test "warms all facility types" do
      with_mock(CreateAlertHelpers,
        get_routes: fn _types -> [] end,
        get_stops: fn _routes, _type, _dir -> [] end,
        get_stops_for_stop_route: fn _routes, _type -> [] end,
        get_facilities: fn _types -> [] end
      ) do
        CacheWarming.warm_all()

        assert_called(CreateAlertHelpers.get_facilities(InformedEntity.all_facility_types()))
      end
    end
  end
end
