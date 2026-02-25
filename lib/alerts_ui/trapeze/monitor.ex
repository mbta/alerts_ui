defmodule AlertsUI.Trapeze.Monitor do
  @moduledoc """
  Monitoring
  """

  use GenServer

  import Ecto.Query
  require Logger

  alias AlertsUI.Repo
  alias AlertsUI.Trapeze.Models.TrapezeMonitor
  alias AlertsUI.Trapeze.WorkOrder

  # 2 hours
  @mtime_error 120 * 60
  # 30 minutes
  @mtime_warning 30 * 60

  # 10 minutes
  @check_error 10 * 60
  # 5 minutes
  @check_warning 5 * 60

  def start do
    previous = most_recent_success() || %TrapezeMonitor{}

    GenServer.start_link(
      __MODULE__,
      %{
        current: %TrapezeMonitor{checked_at: now!()},
        previous: previous
      },
      name: __MODULE__
    )

    info("Starting #{now_string()}")

    if previous.checked_at != nil do
      diff = DateTime.diff(now!(), previous.checked_at)
      distance = "#{trunc(diff / 60)} minutes, #{rem(diff, 60)} seconds"

      update_distance =
        "Last successful check #{distance} ago: #{previous.checked_at |> DateTime.to_iso8601()}"

      cond do
        diff > @check_error -> error(update_distance)
        diff > @check_warning -> warning(update_distance)
        true -> info(update_distance)
      end
    else
      warning("No previously successful checks!")
    end
  end

  defp most_recent_success do
    Repo.one(
      from t in TrapezeMonitor,
        where: t.result == "ok",
        order_by: [desc: t.created_at],
        limit: 1
    )
  end

  @spec processing([String.t()], NaiveDateTime.t()) :: any
  def processing(feed, mtime) do
    now = now!()

    mtime =
      cond do
        mtime != nil ->
          mtime
          |> DateTime.from_naive!("America/New_York")
          |> DateTime.shift_zone!("Etc/UTC")

        feed != [] ->
          feed
          |> hd()
          |> String.split("|")
          |> hd()
          |> DateTime.from_iso8601()
          |> elem(1)

        true ->
          nil
      end

    if mtime != nil do
      diff = DateTime.diff(now, mtime)
      distance = "#{trunc(diff / 60)} minutes, #{rem(diff, 60)} seconds"

      update_distance =
        "Work Order file updated #{distance} ago: #{mtime |> DateTime.to_iso8601()}"

      cond do
        diff > @mtime_error -> error(update_distance)
        diff > @mtime_warning -> warning(update_distance)
        true -> info(update_distance)
      end
    else
      error("Work Order file modification unavailable")
    end

    set(:checked_at, now)
    set(:processed_at, mtime)
    joined = feed |> Enum.join("\n")
    checksum = :crypto.hash(:md5, joined) |> Base.encode16()
    set(:checksum, checksum)

    info("Processing #{length(feed)} entries. Checksum #{checksum}.")
  end

  @spec result({:ok | :warning | :error, String.t() | Exception.t()}) :: any()
  def result({:error, %errmod{message: message}}) do
    error_string = "#{inspect(errmod)}: #{message}"
    result({:error, "Unable to import. #{error_string}"})
  end

  def result({:error, %{} = error}) do
    error_string = "#{inspect(error)}"
    result({:error, "Unable to import. #{error_string}"})
  end

  def result({result, reason}) when is_atom(result) and is_binary(reason) do
    if result != :ok, do: apply(__MODULE__, result, [reason])
    set(:result, Atom.to_string(result))
    set(:reason, reason)
    {result, reason}
  end

  @spec report() :: TrapezeMonitor.t()
  def report do
    GenServer.call(__MODULE__, :report)
  end

  @spec start_work_order(WorkOrder.t() | {atom(), String.t(), String.t()}) :: WorkOrder.t()
  def start_work_order({:skip, work_order_id, reason}) do
    GenServer.cast(__MODULE__, {:start_work_order, work_order_id})
    {:skip, work_order_id, reason}
  end

  def start_work_order(%WorkOrder{} = work_order) do
    GenServer.cast(__MODULE__, {:start_work_order, work_order.work_order_id})
    work_order
  end

  @spec change_work_order([from: String.t(), to: String.t()] | String.t()) :: any
  def change_work_order(string) when is_binary(string) do
    GenServer.cast(__MODULE__, {:change_work_order, string})
  end

  def change_work_order(args) do
    from_source = args[:from]
    to_source = args[:to]
    change_work_order("#{from_source} -> #{to_source}")
  end

  @spec finish_work_order({:ok | :warning | :error, String.t()}) ::
          {:ok | :warning | :error, String.t()}
  def finish_work_order({result, reason} = response) do
    log_call = if result == :ok, do: :info, else: result
    message = GenServer.call(__MODULE__, {:get_current_work_order})
    apply(__MODULE__, log_call, ["#{message} #{reason}"])
    # There's no guarantee of delivery and reception timing, so do this second
    # so we don't accidentally double-log
    GenServer.cast(__MODULE__, {:change_work_order, reason})
    response
  end

  @spec finish() :: any
  def finish do
    report()
    |> TrapezeMonitor.changeset(%{})
    |> Repo.insert!()

    info("Finished processing #{now_string()}")
  end

  def close, do: GenServer.stop(__MODULE__)

  defp set(key, value) do
    GenServer.cast(__MODULE__, {:set, key, value})
  end

  defp now!, do: DateTime.now!("Etc/UTC") |> DateTime.truncate(:second)

  defp now_string, do: NaiveDateTime.local_now() |> NaiveDateTime.to_iso8601()

  @spec info(String.t()) :: any()
  def info(message) do
    Logger.info("#{inspect(__MODULE__)}: #{message}")
  end

  @spec warning(String.t()) :: any()
  def warning(message) do
    Logger.warning("#{inspect(__MODULE__)}: #{message}")
  end

  @spec error(String.t()) :: any()
  def error(message) do
    Logger.error("#{inspect(__MODULE__)}: #{message}")
  end

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_call(:report, _from, state) do
    {:reply, state.current, state}
  end

  @impl true
  def handle_call({:get_current_work_order}, _from, state) do
    [work_order | _] = state.current.work_order_changes
    {:reply, work_order, state}
  end

  @impl true
  def handle_cast({:set, key, value}, state) do
    new_current = Map.put(state.current, key, value)
    {:noreply, %{state | current: new_current}}
  end

  @impl true
  def handle_cast({:start_work_order, work_order_id}, state) do
    new_current =
      Map.put(state.current, :work_order_changes, [
        work_order_id | state.current.work_order_changes
      ])

    {:noreply, %{state | current: new_current}}
  end

  @impl true
  def handle_cast({:change_work_order, change}, state) do
    [work_order | rest] = state.current.work_order_changes

    new_current =
      Map.put(state.current, :work_order_changes, [work_order <> " " <> change | rest])

    {:noreply, %{state | current: new_current}}
  end
end
