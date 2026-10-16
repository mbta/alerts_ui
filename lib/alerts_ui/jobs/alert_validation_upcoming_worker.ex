defmodule AlertsUI.Jobs.AlertValidationUpcomingWorker do
  @moduledoc """
  Oban worker that checks the informed entities of open alerts for validity
  against the dev API when there's a new build.
  We store the last time we ran the check in LastGTFSValidation. We then
  compare that time to the time listed on the API's status page.
  If the API has been updated since we last ran the check, we
  run it and make a record of the time.
  """
  use Oban.Worker

  require Logger

  alias AlertsUI.AlertValidation.AlertValidator
  alias AlertsUI.Models.LastGTFSValidation

  @impl Oban.Worker
  def perform(_job) do
    base_url = AlertsUI.config(:dev_api_url)
    api_key = AlertsUI.config(:dev_api_key)

    stored_time = LastGTFSValidation.get_most_recent_validation()

    with {:ok, response} <- Req.get(base_url <> "/status"),
         body when not is_nil(body) <- Map.get(response, :body),
         status when not is_nil(status) <-
           get_in(body, ["data", "attributes", "route", "last_updated"]),
         {:ok, api_last_updated_time, 0} <- DateTime.from_iso8601(status),
         true <- last_updated_time_after_stored_time?(api_last_updated_time, stored_time) do
      Logger.info("New GTFS detected in dev. Updating stored time and validating alerts.")
      LastGTFSValidation.store_last_gtfs_validation(DateTime.utc_now())

      AlertValidator.validate_alerts(base_url, api_key)
      |> AlertValidator.format_invalid_alerts("upcoming")
      |> Logger.info()

      AlertValidator.validate_commuter_rail_alerts(base_url, api_key)
      |> AlertValidator.format_invalid_alerts("current", "Commuter Rail ")
      |> Logger.info()
    else
      {:error, error} when is_atom(error) ->
        Logger.error("error in processing upcoming GTFS validation: #{error}")
        {:error, error}

      {:error, exception} ->
        Logger.error(
          "error in processing upcoming GTFS validation: " <> Exception.message(exception)
        )

        {:error, Exception.message(exception)}

      false ->
        Logger.info("Did not run upcoming GTFS validation")

      _ ->
        Logger.warning("Issue with upcoming GTFS validation")
    end
  end

  @spec last_updated_time_after_stored_time?(DateTime.t() | nil, DateTime.t() | nil) ::
          boolean()
  def last_updated_time_after_stored_time?(
        %DateTime{} = last_updated_time,
        %DateTime{} = stored_time
      ) do
    DateTime.compare(last_updated_time, stored_time) == :gt
  end

  def last_updated_time_after_stored_time?(_, _), do: true
end
