defmodule AlertsUIWeb.CreateAlertMonoLive.Title do
  use AlertsUIWeb, :html

  def render( %{
    route_type_name: route_type_name,
    effect_name: effect_name
  } = assigns) do
    ~H"""
    <.h1>{@route_type_name} • {@effect_name}</.h1>
    """
  end
end
