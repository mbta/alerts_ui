defmodule AlertsUIWeb.HealthController do
  @moduledoc """
  Simple controller to return 200 OK when the application is running.
  This is used by the AWS ALB to determine the health of the target.
  """
  use AlertsUIWeb, :controller
  alias AlertsUI.Repo

  plug(Logster.Plugs.ChangeLogLevel, to: :debug)

  def index(conn, _params) do
    Repo.query!("SELECT 1")
    send_resp(conn, :ok, "Ok")
  end
end
