defmodule AlertsUI.DelayedJob do
  @moduledoc """
  Oban worker that runs a job after a delay
  """
  use Oban.Worker

  require Logger

  @doc """
  Example: 
  config :alerts_ui, Oban,
    plugins: [
      {Oban.Plugins.Cron,
       crontab: [
         {
           "*/1 * * * *",
           AlertsUI.DelayedJob,
           args: %{
             delay: 30_000,
             module: AlertsUI.FeedWriter,
             args: %{filename: "example.json"}
           },
           max_attempts: 1,
           unique: [period: 30, states: [:available, :scheduled, :executing]]
         },
       ]
      }
    ]

  Arguments
    delay: [Required] Amount of time to wait (milliseconds)
    module: [Required] The job module that should be invoked after the delay
    args: The args for the job itself
  """
  @impl Oban.Worker
  def perform(%{args: args} = job, opts \\ []) do
    %{"delay" => delay, "module" => module_name} = args
    Logger.info("Delaying job #{module_name} by #{delay}ms")
    Process.sleep(delay)
    module = Module.safe_concat([module_name])
    job = Map.put(job, "args", Map.get(args, "args", nil))
    module.perform(job, opts)
  rescue
    e -> Logger.warning("Error delaying job. args=#{inspect(args)}: #{e}")
  end
end
