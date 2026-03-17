defmodule AlertsUIWeb.PageController do
  @moduledoc """
  Static Pages
  """
  use AlertsUIWeb, :controller

  def reauthenticate(conn, _params) do
    render(conn, :reauthenticate)
  end
end
