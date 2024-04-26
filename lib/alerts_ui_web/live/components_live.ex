defmodule AlertsUIWeb.ComponentsLive do
  @moduledoc """
  LiveView for presenting a style guide for our shared components.
  """
  use AlertsUIWeb, :live_view

  @doc """
  Renders a color block with a label.

  ## Examples

      <.color_block name="mbta-bus" value="#ffc72c" />

  """
  attr :name, :string, required: true
  attr :value, :string, required: true

  def color_block(assigns) do
    ~H"""
    <div class="flex flex-col">
      <div class="w-20 h-20" style={"background-color: #{@value}"}></div>
      <div class="text-sm py-1">
        <%= @name %>
      </div>
    </div>
    """
  end
end
