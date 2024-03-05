defmodule AlertsUIWeb.ApiControllerTest do
  @moduledoc false
  use AlertsUIWeb.ConnCase, async: false

  import Mock
  import Test.Support.Helpers

  alias Oidcc.{ClientContext, Token}
  alias Plug.Conn

  describe "GET /api/test" do
    setup do
      reassign_env(:ueberauth_oidcc, :providers, %{
        keycloak: %{
          client_id: "FAKE_KEYCLOAK_CLIENT_ID",
          client_secret: "FAKE_KEYCLOAK_CLIENT_SECRET"
        }
      })
    end

    test "when authorized, returns 200 Ok", %{conn: conn} do
      with_mock(ClientContext,
        from_configuration_worker: fn _provider, _client_id, _client_secret -> {:ok, %{}} end
      ) do
        with_mock(Token,
          validate_jwt: fn _token, _client_context, _opts ->
            {:ok,
             %{
               "resource_access" => %{
                 "alerts-ui" => %{"roles" => ["api-writer"]}
               }
             }}
          end
        ) do
          conn =
            conn
            |> Conn.put_req_header("authorization", "Bearer FAKE_TOKEN")
            |> get("/api/test")

          assert %{"result" => "ok"} = json_response(conn, 200)
        end
      end
    end

    test "when unauthenticated, returns 403 unauthenticated", %{conn: conn} do
      conn = get(conn, "/api/test")
      assert %{"error" => "unauthenticated"} = json_response(conn, 403)
    end
  end
end
