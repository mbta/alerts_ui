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
           args: %{delay: 30_000, module: AlertsUI.FeedWriter},
           max_attempts: 1,
           unique: [period: 30, states: [:available, :scheduled, :executing]]
         },
       ]
      }
    ]

  Arguments
    delay: Amount to delay in milliseconds
    module: The job module that would normally be the second arg in the tuple
    args: The args for the job
  """
  @impl Oban.Worker
  def perform(%{args: args} = job, opts \\ []) do
    Logger.debug("DelayedJob: Starting delay at #{inspect(DateTime.now!("Etc/UTC"))}")
    %{"delay" => delay, "module" => module_name} = args
    module = Module.safe_concat([module_name])
    Process.sleep(delay)

    Logger.debug(
      "DelayedJob: Running #{module_name}.perform at #{inspect(DateTime.now!("Etc/UTC"))}"
    )

    downstream_args = Map.get(args, "args", %{})
    job = Map.put(job, "args", downstream_args)
    module.perform(job, opts)
  end
end
