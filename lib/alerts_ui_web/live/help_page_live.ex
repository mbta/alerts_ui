defmodule AlertsUIWeb.HelpPageLive do
  @moduledoc """
  LiveView for viewing the help page
  """

  use AlertsUIWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Help Page")}
  end
end
