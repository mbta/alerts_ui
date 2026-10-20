defmodule AlertsUIWeb.FormComponents.Helpers.AutoText.AlertDataToAutoTextTest do
  @moduledoc false
  use AlertsUIWeb.ConnCase
  import Mock
  alias AlertsUI.Models.EnhancedSchedule
  alias AlertsUIWeb.FormComponents.Helpers.AutoText.AlertDataToAutoText
  alias MBTAV3API.Routes.Route
  alias MBTAV3API.Schedules.Trip
  alias MBTAV3API.Stops.Repo, as: StopsRepo
  alias MBTAV3API.Stops.Stop

  @route_1 %Route{id: "CR-NewBedford", name: "Fall River/New Bedford Line"}
  @route_2 %Route{id: "CR-Worcester", name: "Framingham/Worcester Line"}

  @schedule_1 %EnhancedSchedule{
    route_id: "CR-NewBedford",
    trip: %Trip{id: "CR-683322-595", name: "595", direction_id: 1},
    arrival_time: nil,
    departure_time: nil
  }

  @schedule_2 %EnhancedSchedule{
    route_id: "CR-Worcester",
    trip: %Trip{id: "CR-683322-595", name: "595", direction_id: 1},
    arrival_time: nil,
    departure_time: nil
  }

  @stop_1 %Stop{
    id: "place-FRS-0109",
    name: "Fall River Depot"
  }

  @stop_2 %Stop{
    id: "place-WML-0442",
    name: "Worcester"
  }

  @stop_3 %Stop{
    id: "place-WML-0214",
    name: "Framingham"
  }

  describe "calculate_branch_name/3" do
    test "returns nil if not a CR alert" do
      actual = AlertDataToAutoText.calcuate_branch_name(3, [], [])
      assert is_nil(actual)
    end

    test "returns nil if multiple routes" do
      actual = AlertDataToAutoText.calcuate_branch_name(2, [@route_1, @route_2], [])
      assert is_nil(actual)
    end

    test "returns nil if multiple schedules" do
      actual = AlertDataToAutoText.calcuate_branch_name(2, [], [@schedule_1, @schedule_2])
      assert is_nil(actual)
    end

    test "returns nil if no slash in route name" do
      route = %Route{id: "CR-Fairmount", name: "Fairmount Line"}
      actual = AlertDataToAutoText.calcuate_branch_name(2, [route], [@schedule_1])
      assert is_nil(actual)
    end

    test "works correctly on branching routes" do
      trip_id = @schedule_1.trip.id

      with_mock(StopsRepo, [], by_trip: fn ^trip_id -> [@stop_2, @stop_1, @stop_3] end) do
        expected = "Fall River Line"
        actual = AlertDataToAutoText.calcuate_branch_name(2, [@route_1], [@schedule_1])
        assert expected == actual
      end
    end

    test "works correctly on non-branching routes" do
      trip_id = @schedule_2.trip.id

      with_mock(StopsRepo, [], by_trip: fn ^trip_id -> [@stop_1, @stop_3, @stop_2] end) do
        expected = "Worcester Line"
        actual = AlertDataToAutoText.calcuate_branch_name(2, [@route_2], [@schedule_2])
        assert expected == actual
      end
    end

    test "returns nil if start AND end stop match" do
      trip_id = @schedule_1.trip.id

      with_mock(StopsRepo, [], by_trip: fn ^trip_id -> [@stop_2, @stop_3] end) do
        actual = AlertDataToAutoText.calcuate_branch_name(2, [@route_2], [@schedule_1])
        assert is_nil(actual)
      end
    end

    test "returns nil if NO stops match match" do
      trip_id = @schedule_1.trip.id

      with_mock(StopsRepo, [], by_trip: fn ^trip_id -> [@stop_1] end) do
        actual = AlertDataToAutoText.calcuate_branch_name(2, [@route_2], [@schedule_1])
        assert is_nil(actual)
      end
    end
  end
end
