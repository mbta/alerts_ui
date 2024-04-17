defmodule AlertsUIWeb.ApiControllerTest do
  @moduledoc false
  use AlertsUIWeb.ConnCase, async: false

  import Mock
  import Test.Support.Helpers

  alias Oidcc.{ClientContext, Token}
  alias Plug.Conn

  describe "POST /api/alerts" do
    setup do
      reassign_env(:ueberauth_oidcc, :providers, %{
        keycloak: %{
          client_id: "FAKE_KEYCLOAK_CLIENT_ID",
          client_secret: "FAKE_KEYCLOAK_CLIENT_SECRET"
        }
      })
    end

    test "when authorized, but alert is not valid, return 400", %{conn: conn} do
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
            |> post("/api/alerts", %{
              header_text: "header",
              description_text: "description",
              effect: "ACCESSIBILITY_ISSUE"
            })

          assert %{"error" => %{"informed_entity" => ["can't be blank"]}} =
                   json_response(conn, 400)
        end
      end
    end

    test "when authorized, returns 201 Created", %{conn: conn} do
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
            |> post("/api/alerts", %{
              header_text: "header",
              description_text: "description",
              effect: "ACCESSIBILITY_ISSUE",
              informed_entity: [
                %{route_id: "1"}
              ]
            })

          assert %{"result" => "ok", "alert_id" => _alert_id} = json_response(conn, 201)
        end
      end
    end

    test "when unauthenticated, returns 403 unauthenticated", %{conn: conn} do
      conn = post(conn, "/api/alerts")
      assert %{"error" => "unauthenticated"} = json_response(conn, 401)
    end
  end
end
