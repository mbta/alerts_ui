defmodule AlertsUI.FeedOutput.CreateGtfsJson do
  @moduledoc """
    Given a list of alerts, outputs a JSON ready to write to file
  """
  alias AlertsUI.FeedOutput.CreateOutputAlert

  @spec output_json(any()) ::
          binary()
          | maybe_improper_list(
              binary() | maybe_improper_list(any(), binary() | []) | byte(),
              binary() | []
            )
  def output_json(alerts) do
    %{
      header: CreateOutputAlert.build_gtfs_header(),
      entity: alerts
    }
    |> Jason.encode!()
    |> Jason.Formatter.pretty_print_to_iodata()
  end
end
