defmodule AlertsUIWeb.PutEnvironmentInAssigns do
  @moduledoc """
    Makes the environment available as an assign. Both standard and LiveView.
    Feel free to rename this and put more stuff in here
  """

  def put_environment_in_assigns(conn, _opts) do
    environment = AlertsUI.config(:environment_name)
    %{conn | assigns: conn.assigns |> Map.merge(%{environment: environment})}
  end

  def on_mount(:default, _params, _session, socket) do
    {:cont, put_environment_in_assigns(socket, %{})}
  end
end
