defmodule AlertsUIWeb.FormComponents.AccessAffectedService do
  @moduledoc """
    Live Component for access affected service section
  """
  use AlertsUIWeb, :live_component
  use AlertsUI.Schema

  require Logger

  @impl true
  def mount(socket) do
    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class={
      unless @progress.name == "details",
        do: "hidden",
        else: "min-w-full flex flex-col"
    }>
      facilities <hr />
    </div>
    """
  end
end
