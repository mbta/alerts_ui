defmodule AlertsUI.Telemetry do
  @moduledoc """
  Telemetry functionality.
  """
  require Logger

  def handle_event([:alerts_ui, :repo, :query], measurements, metadata, _config) do
    total_time = convert_time(Map.get(measurements, :total_time))
    idle_time = convert_time(Map.get(measurements, :idle_time))
    # :idle_time - the time the connection spent waiting before being checked out for the query
    # :queue_time - the time spent waiting to check out a database connection
    # :query_time - the time spent executing the query
    # :decode_time - the time spent decoding the data received from the database
    # :total_time - the sum of (queue_time, query_time, and decode_time)️
    if total_time > 500 or idle_time > 2000 do
      queue_time = convert_time(Map.get(measurements, :queue_time))
      query_time = convert_time(Map.get(measurements, :query_time))
      decode_time = convert_time(Map.get(measurements, :decode_time))

      Logger.info(
        "SLOW QUERY: total_ms: #{total_time}, queue_ms: #{queue_time}, query_ms: #{query_time}, decode_ms: #{decode_time}, idle_ms: #{idle_time} query: #{metadata.query},  Stacktrace: #{inspect(metadata.stacktrace)}"
      )
    end
  end

  def handle_event([:vm, :total_run_queue_lengths], measurements, _, _) do
    %{cpu: cpu, io: io, total: total} = measurements
    Logger.info("Queue Lengths CPU: #{cpu}, IO: #{io}, Total: #{total}")
  end

  def handle_event([:vm, :memory], measurements, _, _) do
    total = measurements.total / 1024 / 1024
    Logger.info("Memory: #{:erlang.float_to_binary(total, decimals: 2)}MB")
  end

  defp convert_time(nil), do: 0

  defp convert_time(time) do
    System.convert_time_unit(time, :native, :millisecond)
  end
end
