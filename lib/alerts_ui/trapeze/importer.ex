defmodule AlertsUI.Trapeze.Importer do
  @moduledoc """
  Oban worker to import Escalator and Elevator alerts from Trapeze
  """
  import Ecto.Query

  alias AlertsUI.AlertBuilder
  alias AlertsUI.FeatureFlags
  alias AlertsUI.FeedOutput.GTFSProtobufDefinition.TransitRealtime.Alert
  use Oban.Worker
  require Logger

  alias AlertsUI.Alerts
  alias AlertsUI.Models.Alert
  alias AlertsUI.Repo
  alias AlertsUI.Trapeze.Monitor
  alias AlertsUI.Trapeze.SFTP
  alias AlertsUI.Trapeze.WorkOrder

  @open_origin "(Opened automatically via Trapeze EAM)"
  @closed_origin "(Closed automatically via Trapeze EAM)"

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
    Monitor.start()

    result =
      cond do
        configuration_incomplete?() ->
          Monitor.result({:warning, "Missing Configuration"})

        not enabled?() ->
          Monitor.result({:warning, "\"Trapeze Import\" Feature Flag Disabled"})

        true ->
          try do
            case SFTP.fetch(SFTP.source_description()) do
              {:ok, {feed, mtime}} ->
                Monitor.processing(feed, mtime)

                process_feed(feed)
                |> Monitor.result()

              {:error, e} ->
                Monitor.result({:error, e})
            end
          rescue
            error ->
              Monitor.result({:error, inspect(error)})
          end
      end

    Monitor.finalize()
    Monitor.stop()
    result
  end

  @spec process_feed([String.t()]) :: {:ok | :error, String.t()}
  def process_feed(feed) do
    feed
    |> Stream.each(&Monitor.start_work_order/1)
    |> Stream.map(fn line ->
      try do
        with {:ok, work_order} <- WorkOrder.from_trapeze_line(line),
             {:ok, params} <- WorkOrder.to_params(work_order) do
          persist(params)
        end
      rescue
        e -> {:error, "ERROR #{inspect(e)}"}
      end
    end)
    |> Stream.map(&Monitor.finish_work_order/1)
    |> Enum.to_list()
    |> Enum.find({:ok, "finish"}, &(&1 != :ok))
  end

  def get_existing_alert(alert_params) do
    facility_ids = Map.get(alert_params, :facility_ids)

    facility_id =
      if is_nil(facility_ids) do
        nil
      else
        hd(facility_ids)
      end

    Repo.one(
      from a in Alert,
        where:
          a.work_order_id == ^alert_params.work_order_id or
            (a.primary_service_type == "access" and
               a.effect_name == ^alert_params.effect_name and
               is_nil(a.closed_timestamp) and
               fragment(
                 "array_to_string(original_facility_selections, ',') LIKE concat('%|', ?::text)",
                 ^facility_id
               ) and
               is_nil(a.work_order_id)),
        order_by: [desc: a.active_period_start],
        limit: 1,
        preload: [:informed_entity, :user]
    )
  end

  # This should be AlertBuilder.alert_data_t() but dialyzer can't tell merge
  # why it's wrong, just that it is.
  @spec persist(map()) :: {:ok | :error, String.t()}
  def persist(alert_params) do
    alert = get_existing_alert(alert_params) || %Alert{}
    Logger.info("processing alert #{alert.alert_id}")

    case alert_change_state(alert, alert_params) do
      :create ->
        create(alert_params)
        {:ok, "none -> open: CREATE"}

      :ignore_already_closed ->
        {:ok, "none -> closed: IGNORE already closed"}

      :ignore_no_change ->
        {:ok, "open -> open: IGNORE open, no change"}

      :close ->
        maybe_close(alert, alert_params)

      :ignore_closed_manually ->
        {:ok, "closed -> open: IGNORE closed manually"}

      :ignore_closed ->
        {:ok, "closed -> closed: IGNORE closed, no change"}
    end
  rescue
    e -> {:error, "ERROR #{inspect(e)}"}
  end

  defp alert_change_state(
         %Alert{alert_id: nil},
         %{status: :open, closed_timestamp: nil}
       ),
       do: :create

  defp alert_change_state(%Alert{alert_id: nil}, %{status: :closed, closed_timestamp: _}),
    do: :ignore_already_closed

  defp alert_change_state(%Alert{alert_id: _, closed_timestamp: nil}, %{
         status: :open,
         closed_timestamp: nil
       }),
       do: :ignore_no_change

  defp alert_change_state(%Alert{alert_id: _, closed_timestamp: nil}, %{
         status: :closed,
         closed_timestamp: _
       }),
       do: :close

  defp alert_change_state(%Alert{alert_id: _, closed_timestamp: _}, %{
         status: :open,
         closed_timestamp: nil
       }),
       do: :ignore_closed_manually

  defp alert_change_state(%Alert{alert_id: _, closed_timestamp: _}, %{
         status: :closed,
         closed_timestamp: _
       }),
       do: :ignore_closed

  @spec create(AlertBuilder.alert_data_t()) :: any()
  defp create(alert_params) do
    alert_data_params =
      AlertBuilder.build_alert(alert_params, :ACCESS)

    alert =
      %Alert{}
      |> Alert.changeset(
        alert_data_params
        |> Map.merge(%{
          can_close_automatically: true,
          last_modified_timestamp: DateTime.now!("Etc/UTC"),
          last_push_notification_timestamp: DateTime.now!("Etc/UTC")
        })
      )
      |> PaperTrail.insert!(user: nil, origin: @open_origin)

    Phoenix.PubSub.broadcast(
      AlertsUI.PubSub,
      "alerts",
      {:alerts_updated}
    )

    alert
  end

  # When neither the new or old alerts are closed
  defp maybe_close(%Alert{closed_timestamp: nil}, %{closed_timestamp: nil}) do
    Logger.info("neither new nor old alerts are closed")
    {:ok, "open -> open: IGNORE not closed"}
  end

  # When the alert is marked as automatically closeable
  defp maybe_close(
         %Alert{
           closed_timestamp: nil,
           can_close_automatically: true,
           created_at: created_at
         } = alert,
         %{
           closed_timestamp: closed_timestamp
         }
       ) do
    # only close if alert was created before the closed timestamp
    Logger.info("Alert is marked as automatically closeable (first pattern)")
    Logger.info("alert created_at is #{created_at}")
    Logger.info("alert closed_timestamp is #{closed_timestamp}")

    if safe_datetime_compare(created_at, closed_timestamp) == :lt do
      Logger.info("alert created_at less than closed_timestamp. closing.")
      close(alert)
    else
      Logger.info(
        "datetime compare was #{safe_datetime_compare(created_at, closed_timestamp)}. not closing. "
      )

      {:ok, "open -> open: IGNORE can't close automatically"}
    end
  end

  # When the alert is operating on the same Work Order
  defp maybe_close(
         %Alert{
           closed_timestamp: nil,
           work_order_id: work_order_id
         } = alert,
         %{
           closed_timestamp: _closed_timestamp,
           work_order_id: work_order_id
         }
       ) do
    Logger.info("alert operating on same work order")
    close(alert)
  end

  # Any other case should be ignored.
  defp maybe_close(%Alert{closed_timestamp: _}, _) do
    Logger.info("fallthrough case")
    {:ok, "open -> open: IGNORE can't close automatically"}
  end

  defp close(alert) do
    Alerts.close(
      Repo.reload!(alert),
      @closed_origin,
      true,
      DateTime.now!("America/New_York") |> DateTime.truncate(:second)
    )

    {:ok, "open -> closed: CLOSE"}
  end

  defp configuration_incomplete?,
    do:
      SFTP.source_description().host in [nil, ""] ||
        SFTP.source_description().port == nil ||
        SFTP.source_description().user in [nil, ""] ||
        SFTP.source_description().password in [nil, ""] ||
        SFTP.source_description().filename in [nil, ""]

  defp enabled?, do: FeatureFlags.enabled?("Trapeze Import")

  defp safe_datetime_compare(%DateTime{} = created_at, %NaiveDateTime{} = closed_timestamp) do
    Logger.info("they were both datetimes")

    closed_timestamp =
      closed_timestamp
      |> DateTime.from_naive!("America/New_York")
      |> DateTime.shift_zone!("Etc/UTC")

    DateTime.compare(created_at, closed_timestamp)
  end

  defp safe_datetime_compare(_, _) do
    Logger.info("one of them was nil")
    nil
  end
end
