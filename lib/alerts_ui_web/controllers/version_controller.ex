defmodule AlertsUIWeb.VersionController do
  @moduledoc """
  Simple controller to return git sha of build.
  """
  use AlertsUIWeb, :controller

  def index(conn, _params) do
    text(conn, AlertsUI.config(:git_sha))
  end
end
