defmodule AlertsUIWeb.PageController do
  @moduledoc """
  Static Pages
  """
  use AlertsUIWeb, :controller

  def help(conn, _params) do
    render(conn, :help)
  end
end
