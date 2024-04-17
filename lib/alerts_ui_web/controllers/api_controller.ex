defmodule AlertsUIWeb.ApiController do
  @moduledoc """
  TODO
  """
  use AlertsUIWeb, :controller
  use PhoenixSwagger
  alias AlertsUI.Alerts

  swagger_path :new do
    post("/api/alerts")
    description("Create a new alert")
    consumes("application/json")
    produces("application/json")

    parameter(:alert, :body, Schema.ref(:AlertRequest), "The alert details",
      example: %{
        user: %{name: "Joe", email: "Joe1@mail.com"}
      }
    )

    response(201, "Created", Schema.ref(:AlertResponse))
    response(400, "Bad Request", Schema.ref(:AlertError))
    response(401, %{"error" => "unauthenticated"})
    response(403, %{"error" => "unauthorized"})
  end

  def new(conn, params) do
    case Alerts.create_or_update_alert(params) do
      {:ok, result} ->
        alert_uuid = Map.get(result, :id)
        alert = if is_nil(alert_uuid), do: %{}, else: alert_uuid |> Alerts.get_by_id()

        conn
        |> Plug.Conn.resp(201, "Created")
        |> json(%{result: :ok, alert_id: Map.get(alert, :alert_id, "")})

      {:error, result} ->
        conn
        |> Plug.Conn.resp(400, "Bad Request")
        |> json(%{error: result |> Alerts.parse_changeset_errors()})
    end
  end

  def swagger_definitions do
    %{
      Alert:
        swagger_schema do
          title("Alert")
          description("Alert information")

          properties do
            header_text(:string, "Header for the alert.", required: true)
            description_text(:string, "Description for the alert.", required: true)
            effect(:string, "The effect of this problem on the affected entity.", required: true)

            effect_detail(
              :string,
              "Description of the effect of the alert that allows for agency-specific language"
            )

            informed_entity(
              :array,
              Schema.new do
                properties do
                  agency_id(:string, "Agency ID")
                  route_id(:string, "Route ID")
                  facility_id(:string, "Facility ID")
                  route_type(:integer, "Route Type")
                  direction_id(:integer, "Direction ID", enum: [0, 1])
                  stop_id(:string, "Stop ID")

                  trip(
                    Schema.new do
                      properties do
                        trip_id(:string, "Trip ID")
                        route_id(:string, "Route ID")
                        direction_id(:integer, "Direction ID", enum: [0, 1])
                        start_time(:string, "11:15:35")
                        start_date(:string, "YYYYMMDD")
                      end
                    end
                  )
                end
              end
            )
          end
        end,
      AlertRequest:
        swagger_schema do
          title("AlertRequest")
          description("POST body for creating a user")
          property(:alert, Schema.ref(:Alert), "The alert details")
        end,
      AlertResponse:
        swagger_schema do
          title("AlertResponse")
          description("send upon successful alert")

          properties do
            result(:string)
            alert_id(:string)
          end
        end,
      AlertError:
        swagger_schema do
          title("AlertError")
          description("send upon error in alert creation")

          properties do
            error(:map)
          end
        end
    }
  end
end
