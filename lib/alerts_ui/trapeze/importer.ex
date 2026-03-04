defmodule AlertsUI.Trapeze.Importer do
  @moduledoc """
  Oban worker to import Escalator and Elevator alerts from Trapeze
  """
  import Ecto.Query

  alias AlertsUI.FeedOutput.GTFSProtobufDefinition.Alert
  use Oban.Worker

  alias AlertsUI.Alerts
  alias AlertsUI.Models.Alert
  alias AlertsUI.Repo
  alias AlertsUI.Trapeze.SFTP
  alias AlertsUI.Trapeze.WorkOrder

  require Logger

  @doc """
  Example: 
  config :alerts_ui, Oban,
    plugins: [
      {Oban.Plugins.Cron,
       crontab: [
         {"*/1 * * * *", AlertsUI.Trapeze.Importer},
       ]
      }
    ]
  """
  @impl Oban.Worker
  def perform(_, _opts \\ []) do
    info("Starting #{now_string()}")

    cond do
      configuration_incomplete?() ->
        warning("Not Loading Escalator/Elevator Feed: missing configuration.")
        {:ok, "Missing Configuration"}

      production?() && not allowed_in_production?() ->
        warning("Not Loading Escalator/Elevator Feed: running in production.")
        {:ok, "Running in Production"}

      true ->
        info("Loading Escalator/Elevator Feed.")

        case SFTP.fetch(SFTP.source_description()) do
          {:ok, feed} ->
            info("Processing #{length(feed)} entries")
            process_feed(feed)

          {:error, e} ->
            error("Unable to import. #{inspect(e)}")
            {:error, e}
        end
    end
  end

  @spec info(String.t()) :: any()
  def info(message) do
    Logger.info("#{__MODULE__}: #{message}")
  end

  @spec warning(String.t()) :: any()
  def warning(message) do
    Logger.warning("#{__MODULE__}: #{message}")
  end

  @spec error(String.t()) :: any()
  def error(message) do
    Logger.error("#{__MODULE__}: #{message}")
  end

  @spec process_feed([String.t()]) :: :ok | :error
  def process_feed(feed) do
    feed
    |> Stream.map(&WorkOrder.from_trapeze_line/1)
    |> Stream.map(&WorkOrder.to_params/1)
    |> Stream.map(&persist/1)
    |> Enum.to_list()
    |> Enum.find(:ok, &(&1 == :error))
  end

  defp get_existing_alert(alert_params) do
    [facility | _] = alert_params.original_facility_selections
    [_, facility_id] = String.split(facility, "|")

    Repo.one(
      from a in Alert,
        where:
          a.work_order_id == ^alert_params.work_order_id or
            (a.primary_service_type == ^alert_params.primary_service_type and
               a.effect_name == ^alert_params.effect_name and
               is_nil(a.closed_timestamp) and
               fragment(
                 "array_to_string(original_facility_selections, ',') LIKE concat('%|', ?::text)",
                 ^facility_id
               )),
        order_by: [desc: a.active_period_start],
        limit: 1,
        preload: [:informed_entity, :user]
    )
  end

  @spec persist(map() | {atom(), String.t(), String.t()}) :: :ok | :error
  def persist({:skip, work_order_id, reason}) do
    info("Skipping #{work_order_id}: #{reason}")
  end

  def persist(alert_params) do
    alert = get_existing_alert(alert_params) || %Alert{}

    cond do
      closed_alert?(alert) && not closed_params?(alert_params) ->
        info(
          "Ignoring Work Order ##{alert_params.work_order_id} because the Alert is CLOSED in AM but OPEN in Trapeze"
        )

        :ok

      existing_alert?(alert) || not closed_params?(alert_params) ->
        info("Work Order ##{alert_params.work_order_id}")

        alert
        |> Alert.changeset(
          alert_params
          |> Map.merge(%{
            last_modified_timestamp: DateTime.now!("Etc/UTC"),
            last_push_notification_timestamp: DateTime.now!("Etc/UTC")
          })
        )
        |> PaperTrail.insert_or_update!(
          user: nil,
          origin: "(Opened automatically via Trapeze EAM)"
        )
        |> close_if_necessary(alert.closed_timestamp)

      true ->
        info(
          "Ignoring Work Order ##{alert_params.work_order_id} because it does not exist in AM and is already CLOSED"
        )

        :ok
    end
  end

  defp closed_alert?(map) do
    Map.get(map, :closed_timestamp) != nil
  end

  defp closed_params?(%{status: :closed}), do: true
  defp closed_params?(_), do: false

  defp existing_alert?(%Alert{alert_id: alert_id}) when not is_nil(alert_id), do: true
  defp existing_alert?(_), do: false

  defp close_if_necessary(%Alert{} = alert, nil) do
    if alert.closed_timestamp != nil do
      info("Closing Work Order #{alert.work_order_id}")

      Alerts.close(
        Repo.reload!(alert),
        "(Closed automatically by Trapeze EAM)",
        true,
        alert.closed_timestamp |> DateTime.from_naive!("Etc/UTC")
      )
    end

    :ok
  end

  defp close_if_necessary(%Alert{}, _), do: :ok

  defp close_if_necessary(_, _), do: :error

  defp now_string, do: NaiveDateTime.local_now() |> NaiveDateTime.to_iso8601()

  defp configuration_incomplete?,
    do:
      SFTP.source_description().host in [nil, ""] ||
        SFTP.source_description().port == nil ||
        SFTP.source_description().user in [nil, ""] ||
        SFTP.source_description().password in [nil, ""] ||
        SFTP.source_description().filename in [nil, ""]

  defp production?, do: System.get_env("SENTRY_ENV") == "prod"

  defp allowed_in_production?, do: System.get_env("TRAPEZE_IN_PRODUCTION") == "true"
end
