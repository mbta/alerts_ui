defmodule AlertsUIWeb.ApiControllerTest do
  @moduledoc false
  use AlertsUIWeb.ConnCase, async: false

  import Mock
  import Test.Support.Helpers
  import AlertsUI.Support.Factory

  use PhoenixSwagger.SchemaTest, "priv/static/swagger.json"

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

    test "when authorized, returns 201 Created", %{conn: conn, swagger_schema: schema} do
      with_mocks([
        {ClientContext, [],
         from_configuration_worker: fn _provider, _client_id, _client_secret -> {:ok, %{}} end},
        {Token, [],
         validate_jwt: fn _token, _client_context, _opts ->
           {:ok,
            %{
              "resource_access" => %{
                "alerts-ui" => %{"roles" => ["api-writer"]}
              }
            }}
         end}
      ]) do
        conn =
          conn
          |> Conn.put_req_header("authorization", "Bearer FAKE_TOKEN")
          |> post("/api/alerts", %{
            header_text: "header",
            active_period_start: "2023-01-01 00:00:00",
            description_text: "description",
            effect_detail: "ACCESS_ISSUE",
            informed_entity: [
              %{route_id: "1"}
            ],
            user: build(:user_map)
          })
          |> validate_resp_schema(schema, :AlertResponse)

        assert %{"result" => "ok", "alert_id" => _alert_id} = json_response(conn, 201)
      end
    end

    @tag capture_log: true
    test "when authorized, but alert is not valid, return 400", %{
      conn: conn,
      swagger_schema: schema
    } do
      with_mocks([
        {ClientContext, [],
         from_configuration_worker: fn _provider, _client_id, _client_secret -> {:ok, %{}} end},
        {Token, [],
         validate_jwt: fn _token, _client_context, _opts ->
           {:ok,
            %{
              "resource_access" => %{
                "alerts-ui" => %{"roles" => ["api-writer"]}
              }
            }}
         end}
      ]) do
        conn =
          conn
          |> Conn.put_req_header("authorization", "Bearer FAKE_TOKEN")
          |> post("/api/alerts", %{
            header_text: "header",
            active_period_start: "2023-01-01 00:00:00",
            description_text: "description",
            effect_detail: "ACCESS_ISSUE",
            user: build(:user_map)
          })
          |> validate_resp_schema(schema, :AlertError)

        assert %{"error" => %{"informed_entity" => ["can't be blank"]}} = json_response(conn, 400)
      end
    end

    @tag capture_log: true
    test "when unauthenticated, returns 401 unauthenticated", %{
      conn: conn,
      swagger_schema: schema
    } do
      conn = post(conn, "/api/alerts") |> validate_resp_schema(schema, :UnauthenticatedError)
      assert %{"error" => "unauthenticated"} = json_response(conn, 401)
    end
  end
end
