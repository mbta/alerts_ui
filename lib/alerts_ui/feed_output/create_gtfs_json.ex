defmodule AlertsUI.FeedOutput.CreateGtfsJson do
  @moduledoc """
    Given a list of alerts, outputs a JSON ready to write to file
  """
  alias AlertsUI.FeedOutput.{CreateOutputAlert, CreateStandardAlert}

  @spec output_standard_json(any()) ::
          binary()
          | maybe_improper_list(
              binary() | maybe_improper_list(any(), binary() | []) | byte(),
              binary() | []
            )
  def output_standard_json(alerts) do
    entity =
      alerts
      |> Enum.map(&CreateStandardAlert.build_standard_alert/1)

    %{
      header: CreateOutputAlert.build_gtfs_header(),
      entity: entity
    }
    |> encode_json
  end

  @spec output_enhanced_json(any()) ::
          binary()
          | maybe_improper_list(
              binary() | maybe_improper_list(any(), binary() | []) | byte(),
              binary() | []
            )
  def output_enhanced_json(alerts) do
    %{
      header: CreateOutputAlert.build_gtfs_header(),
      entity: alerts
    }
    |> encode_json
  end

  def encode_json(alerts) do
    alerts
    |> Jason.encode!()
    |> Jason.Formatter.pretty_print()
  end
end
