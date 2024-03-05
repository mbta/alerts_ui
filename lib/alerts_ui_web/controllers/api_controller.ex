defmodule AlertsUIWeb.ApiController do
  @moduledoc """
  Proof-of-Concept test route demonstrating API auth verification.
  """
  use AlertsUIWeb, :controller

  def test(conn, _params) do
    json(conn, %{result: :ok})
  end
end
