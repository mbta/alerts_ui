defmodule AlertsUIWeb.DownloadHistoryLive do
  @moduledoc """
  LiveView for presenting a style guide for our shared components.
  """
  use AlertsUIWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    now = DateTime.shift_zone!(DateTime.utc_now(), "America/New_York")
    previous_month = rem(now.month + 10, 12) + 1

    if connected?(socket) do
      Phoenix.PubSub.subscribe(AlertsUI.PubSub, "file_downloading")
    end

    {:ok,
     assign(socket, %{
       years: year_options(now),
       months: month_options(),
       current_year: now.year,
       previous_month: previous_month,
       loading: false,
       selected_month: previous_month,
       selected_year: now.year
     })}
  end

  @impl true
  def handle_event("get_month", %{"month" => month}, socket) do
    {:noreply, assign(socket, selected_month: month)}
  end

  @impl true
  def handle_event("get_year", %{"year" => year}, socket) do
    {:noreply, assign(socket, selected_year: year)}
  end

  @impl true
  def handle_info({:download_started}, socket) do
    {:noreply, assign(socket, loading: true)}
  end

  @impl true
  def handle_info({:download_finished}, socket) do
    {:noreply, assign(socket, loading: false)}
  end

  defp month_options do
    1..12 |> Enum.to_list() |> Enum.map(fn month -> {Timex.month_name(month), month} end)
  end

  defp year_options(now) do
    2013..now.year |> Enum.to_list() |> Enum.reverse() |> Enum.map(fn year -> {year, year} end)
  end
end
