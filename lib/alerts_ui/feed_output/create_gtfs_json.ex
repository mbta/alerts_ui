defmodule AlertsUI.FeedOutput.CreateGtfsJson do
  @moduledoc """
    Given a list of alerts, outputs a JSON ready to write to file
  """

  @spec output_json(any()) ::
          binary()
          | maybe_improper_list(
              binary() | maybe_improper_list(any(), binary() | []) | byte(),
              binary() | []
            )
  def output_json(map) do
    map
    |> build_json
    |> Jason.encode!()
    |> Jason.Formatter.pretty_print_to_iodata()
  end

  def build_json(alerts) do
    %{
      "header" => %{
        "gtfs_realtime_version" => "2.0",
        "incrementality" => "FULL_DATASET",
        "timestamp" => DateTime.utc_now() |> DateTime.to_unix()
      },
      "entity" => alerts
    }
  end
end
