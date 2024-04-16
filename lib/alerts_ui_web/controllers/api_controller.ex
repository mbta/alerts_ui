defmodule AlertsUIWeb.ApiController do
  @moduledoc """
  TODO
  """
  use AlertsUIWeb, :controller

  def new(conn, params) do
    IO.inspect(params)
    json(conn, %{result: :ok})
  end
end
