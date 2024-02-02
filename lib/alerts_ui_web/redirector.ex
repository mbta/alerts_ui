defmodule AlertsUIWeb.Redirector do
  @moduledoc """
  A Plug to allow for redirects within the Phoenix router.
  """
  @behaviour Plug

  alias Phoenix.Controller
  alias Plug.Conn

  @type option :: {:to, String.t()}
  @type options :: [option()]

  @impl Plug
  @spec init(options()) :: options()
  def init([to: _] = opts), do: opts
  def init(_), do: raise("Missing required to: option in redirect")

  @impl Plug
  @spec call(Conn.t(), options()) :: Conn.t()
  def call(conn, to: to), do: Controller.redirect(conn, to: append_query_string(conn, to))

  @spec append_query_string(Plug.Conn.t(), String.t()) :: String.t()
  defp append_query_string(%Plug.Conn{query_string: ""}, path), do: path
  defp append_query_string(%Plug.Conn{query_string: query}, path), do: "#{path}?#{query}"
end
