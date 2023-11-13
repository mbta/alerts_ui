defmodule AlertsUI.FeedOutput.CreateGtfsJsonTest do
  use AlertsUI.DataCase, async: true
  alias AlertsUI.FeedOutput.CreateGtfsJson

  describe "build_json/1" do
    test "outputs correct json from alerts list" do
      alerts = [
        %{
          "id" => "123",
          "alert" => %{
            "header_text" => "cool",
            "description_text" => "beans"
          }
        },
        %{
          "id" => "234",
          "alert" => %{
            "header_text" => "hi",
            "description_text" => "mom"
          }
        }
      ]

      expected = %{
        "entity" => [
          %{
            "alert" => %{"description_text" => "beans", "header_text" => "cool"},
            "id" => "123"
          },
          %{
            "alert" => %{"description_text" => "mom", "header_text" => "hi"},
            "id" => "234"
          }
        ],
        "header" => %{
          "gtfs_realtime_version" => "2.0",
          "incrementality" => "FULL_DATASET",
          "timestamp" => 1_699_548_912
        }
      }

      actual = CreateGtfsJson.build_json(alerts)
      assert expected["header"] |> Map.keys() == actual["header"] |> Map.keys()
      assert {:ok, _} = expected["header"]["timestamp"] |> DateTime.from_unix()
      [alert1, alert2] = expected["entity"] |> Enum.sort_by(& &1["id"])
      assert alert1["id"] == "123"
      assert %{"description_text" => "beans", "header_text" => "cool"} = alert1["alert"]
      assert alert2["id"] == "234"
      assert %{"description_text" => "mom", "header_text" => "hi"} = alert2["alert"]
    end
  end
end
