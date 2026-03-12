defmodule AlertsUI.Trapeze.Importer do
  @moduledoc """
  Oban worker to import Escalator and Elevator alerts from Trapeze
  """
  import Ecto.Query

  alias AlertsUI.AlertBuilder
  alias AlertsUI.FeedOutput.GTFSProtobufDefinition.Alert
  use Oban.Worker

  alias AlertsUI.Alerts
  alias AlertsUI.Models.Alert
  alias AlertsUI.Repo
  alias AlertsUI.Trapeze.Monitor
  alias AlertsUI.Trapeze.SFTP
  alias AlertsUI.Trapeze.WorkOrder

  require Logger

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
    cond do
      configuration_incomplete?() ->
        Monitor.result({:warning, "Missing Configuration"})

      production?() && not allowed_in_production?() ->
        Monitor.result({:warning, "Running in Production"})

      true ->
        Monitor.start()
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
            Monitor.result({:error, error})
        end
        Monitor.finish()
        Monitor.close()
    end
  end

  @spec process_feed([String.t()]) :: {:ok, String.t()} | {:error, String.t()}
  def process_feed(feed) do
    feed
    |> Stream.map(&WorkOrder.from_trapeze_line/1)
    |> Stream.map(&Monitor.start_work_order/1)
    |> Stream.map(&WorkOrder.to_params/1)
    |> Stream.map(&persist/1)
    |> Stream.map(&Monitor.finish_work_order/1)
    |> Enum.to_list()
    |> Enum.find({:ok, "finish"}, &(&1 != :ok))
  end

  defp get_existing_alert(alert_params) do
    original_facility_selections = Map.get(alert_params, :original_facility_selections)

    facility_id =
      if original_facility_selections do
        [facility | _] = original_facility_selections
        [_, facility_id] = String.split(facility, "|")
        facility_id
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

  @spec persist(AlertBuilder.alert_data_t() | {atom(), String.t(), String.t()}) ::
          {:ok, String.t()} | {:error, String.t()}
  def persist({:skip, _work_order_id, reason}) do
    {:warning, "IGNORE #{reason}"}
  end

  def persist(alert_params) do
    alert = get_existing_alert(alert_params) || %Alert{}

    case alert_change_state(alert, alert_params) do
      :create ->
        Monitor.change_work_order(from: "none", to: "open")
        create(alert_params)
        {:ok, "CREATE"}

      :ignore_already_closed ->
        Monitor.change_work_order(from: "none", to: "closed")
        {:ok, "IGNORE already closed"}

      :ignore_no_change ->
        Monitor.change_work_order(from: "open", to: "open")
        {:ok, "IGNORE open, no change"}

      :close ->
        Monitor.change_work_order(from: "open", to: "closed")
        close(alert, alert_params.closed_timestamp)
        {:ok, "CLOSE"}

      :ignore_closed_manually ->
        Monitor.change_work_order(from: "closed", to: "open")
        {:ok, "IGNORE closed manually"}

      :ignore_closed ->
        Monitor.change_work_order(from: "closed", to: "closed")
        {:ok, "IGNORE closed, no change"}
    end
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
    alert_data_params = AlertBuilder.build_alert(alert_params, :ACCESS)

    %Alert{}
    |> Alert.changeset(
      alert_data_params
      |> Map.merge(%{
        last_modified_timestamp: DateTime.now!("Etc/UTC"),
        last_push_notification_timestamp: DateTime.now!("Etc/UTC")
      })
    )
    |> PaperTrail.insert!(user: nil, origin: @open_origin)
  end

  defp close(%Alert{}, nil), do: {:ok, "IGNORE"}

  defp close(%Alert{closed_timestamp: nil} = alert, closed_timestamp) do
    Alerts.close(
      Repo.reload!(alert),
      @closed_origin,
      true,
      closed_timestamp |> DateTime.from_naive!("Etc/UTC")
    )
  end

  defp close(%Alert{closed_timestamp: _}, _), do: {:ok, "IGNORE"}

  defp configuration_incomplete?,
    do:
      SFTP.source_description().host in [nil, ""] ||
        SFTP.source_description().port == nil ||
        SFTP.source_description().user in [nil, ""] ||
        SFTP.source_description().password in [nil, ""] ||
        SFTP.source_description().filename in [nil, ""]

  defp production?, do: AlertsUI.config(:environment_name) == "prod"

  defp allowed_in_production?, do: AlertsUI.config(:trapeze_in_production) == "true"
end
