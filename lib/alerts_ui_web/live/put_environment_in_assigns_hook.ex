defmodule AlertsUIWeb.PutEnvironmentInAssigns do
  @moduledoc """
    Makes the environment available as an assign. Feel free to rename this and
    put more stuff in here
  """

  import Phoenix.Component

  def on_mount(:default, _params, _session, socket) do
    environment = AlertsUI.config(:environment_name)
    {:cont, socket |> assign(:environment, environment)}
  end
end
