defmodule AlertsUIWeb.PutMetadataInAssigns do
  @moduledoc """
    Makes the environment available as an assign. Feel free to rename this and
    put more stuff in here
  """

  import Phoenix.Component

  def on_mount(:default, _params, _session, socket) do
    environment = AlertsUI.config(:environment_name)
    full_story_org_id = Application.get_env(:alerts_ui, :full_story_org_id)

    {:cont, socket |> assign(environment: environment, full_story_org_id: full_story_org_id)}
  end
end
