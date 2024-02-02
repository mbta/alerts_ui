defmodule AlertsUIWeb.RedirectorTest do
  @moduledoc false
  use ExUnit.Case, async: true

  import Phoenix.ConnTest, only: [redirected_to: 1]

  alias AlertsUIWeb.Redirector

  defmodule MockRouter do
    @moduledoc false
    use Phoenix.Router

    get "/oak-grove", Redirector, to: "/chinatown"
    get "/exceptional", Redirector, []
  end

  describe "init/1" do
    test "passes along the opts" do
      opts = [to: "chinatown"]

      assert Redirector.init(opts) == opts
    end

    test "raises an exception if the to option isn't defined" do
      assert_raise RuntimeError, fn ->
        Redirector.init([])
      end
    end
  end

  describe "call/2" do
    test "redirects the route" do
      conn = call(MockRouter, :get, "/oak-grove")

      assert redirected_to(conn) == "/chinatown"
    end

    test "retains a query string" do
      conn = call(MockRouter, :get, "/oak-grove?foo=bar")

      assert redirected_to(conn) == "/chinatown?foo=bar"
    end
  end

  defp call(router, verb, path) do
    verb
    |> Plug.Test.conn(path)
    |> router.call(router.init([]))
  end
end
