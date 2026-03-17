defmodule AlertsUIWeb.PageController do
  @moduledoc """
  Static Pages
  """
  use AlertsUIWeb, :controller

  def reauthenticate(conn, params) do
    base_url = "/auth/keycloak?prompt=login"

    href = case Map.get(params, "email") do
      email when is_binary(email) -> "#{base_url}&login_hint=#{email}"
      _ -> base_url
    end

    render(conn, :reauthenticate, href: href)
  end
end
