defmodule AlertsUIWeb.UnauthorizedController do
  @moduledoc """
  Simple controller to return an unauthorized message.
  """
  use AlertsUIWeb, :controller

  def index(conn, _params) do
    text(
      conn,
      "You are unauthorized to view #{System.get_env("SENTRY_ENV", "")} Alerts Manager. To receive access as an MBTA employee, please submit a ServiceNow ticket."
    )
  end
end
