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
  def output_json(alerts) do
    %{
      header: build_gtfs_header(),
      entity: alerts
    }
    |> Jason.encode!()
    |> Jason.Formatter.pretty_print_to_iodata()
  end

  def build_gtfs_header do
    %{
      gtfs_realtime_version: "2.0",
      incrementality: :FULL_DATASET,
      timestamp: DateTime.utc_now() |> DateTime.to_unix()
    }
  end
end
