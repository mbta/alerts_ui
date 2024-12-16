defmodule AlertsUIWeb.VersionController do
  @moduledoc """
  Simple controller to return git sha of build.
  """
  use AlertsUIWeb, :controller

  def index(conn, _params) do
    text(conn, System.get_env("GIT_SHA", "none"))
  end
end
