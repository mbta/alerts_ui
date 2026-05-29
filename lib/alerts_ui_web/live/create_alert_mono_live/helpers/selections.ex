defmodule AlertsUIWeb.CreateAlertMonoLive.Helpers.Selections do
  use AlertsUIWeb, :html

  def selections_loading?(%{loading: true}), do: true
  def selections_loading?(_), do: false
end
