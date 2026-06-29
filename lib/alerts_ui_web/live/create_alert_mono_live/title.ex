defmodule AlertsUIWeb.CreateAlertMonoLive.Title do
  use AlertsUIWeb, :html

  def render(assigns) do
    ~H"""
    <.h1>{@route_type_name} • {@effect_name}</.h1>
    """
  end
end
