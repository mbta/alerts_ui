defmodule AlertsUI.SkateDetours.GetDetoursTest do
  @moduledoc false
  use AlertsUI.DataCase
  import Mock

  alias AlertsUI.SkateDetours.{GetDetours, ReadLocal}

  describe "get_detours\0" do
    test "detours are empty" do
      with_mock(ReadLocal, [], read: fn -> {:ok, ""} end) do
        data = GetDetours.get_detours()
        assert data == []
      end
    end

    test "parses detours from file" do
      data = GetDetours.get_detours()
      assert length(data) == 8

      assert %AlertsUI.Models.SkateDetour{
               id: 7,
               route_id: "1",
               reason: "Drawbridge being raised",
               nearest_intersection: "Massachusetts Avenue & Western Avenue",
               estimated_duration: "2026-04-14",
               activated_at: ~U[2026-04-06 18:44:19Z],
               updated_at: ~U[2026-04-09 13:37:59Z],
               autoclose_on: nil,
               direction_id: 1,
               missed_stops: ["72"],
               route_segments: nil,
               connection_points: ["71", "73"],
               missed_stops_text_only: nil,
               connection_points_text_only: nil
             } = hd(data)
    end
  end
end
