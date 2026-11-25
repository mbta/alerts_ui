defmodule AlertsUI.Jobs.AlertAssociationDailyWorker do
  @moduledoc """
  Oban worker that checks the stops and trips of open alerts for
  association validity once a day, against the production API.
  (eg that they are still associated with their routes)
  """
  use Oban.Worker

  require Logger

  alias AlertsUI.AlertValidation.AlertAssociationValidator

  @impl Oban.Worker
  def perform(_job) do
    AlertAssociationValidator.validate_alerts()
    |> AlertAssociationValidator.format_invalid_alerts("current")
    |> Logger.info()

    AlertAssociationValidator.validate_commuter_rail_alerts()
    |> AlertAssociationValidator.format_invalid_alerts("current", "Commuter Rail ")
    |> Logger.info()
  end
end
