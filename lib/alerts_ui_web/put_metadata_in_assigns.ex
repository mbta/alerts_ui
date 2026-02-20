defmodule AlertsUIWeb.PutMetadataInAssigns do
  @moduledoc """
    Makes the metadata available as an assign
  """

  def put_metadata_in_assigns(conn, _opts) do
    environment = AlertsUI.config(:environment_name)
    full_story_org_id = Application.get_env(:alerts_ui, :full_story_org_id)

    %{conn | assigns: conn.assigns |> Map.merge(%{
      environment: environment,
      full_story_org_id: full_story_org_id
    })}
  end

  def on_mount(:default, _params, _session, socket) do
    {:cont, put_metadata_in_assigns(socket, %{})}
  end
end
