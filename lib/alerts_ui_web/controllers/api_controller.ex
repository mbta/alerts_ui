defmodule AlertsUIWeb.ApiController do
  @moduledoc """
  API controller- contains
  POST /api/alerts to create a new alert
  """
  use AlertsUIWeb, :controller
  use PhoenixSwagger
  alias AlertsUI.AlertFromApi
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
    response(401, "Unauthorized", Schema.ref(:UnauthenticatedError))
    response(401, "Unauthenticated", Schema.ref(:UnauthenticatedError))
    response(403, "Forbidden", %{"error" => "Forbidden"})
  end

  def new(conn, params) do
    params
    |> Jason.encode!()
    |> Jason.decode!(keys: :atoms)
    |> AlertFromApi.fill_in_alert()
    |> Alerts.create_or_update_alert()
    |> case do
      {:ok, alert} ->
        alert_uuid = Map.get(alert, :id)

        alert = alert_uuid |> Alerts.get_by_id()

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
            effect(:string, "The effect of this problem on the affected entity.")

            effect_detail(
              :string,
              "Description of the effect of the alert that allows for agency-specific language",
              required: true
            )

            cause(:string)
            cause_detail(:string)
            description_text(:string)
            severity_level(:string)
            url(:string, "The URL which provides additional information about the alert.")

            informed_entity(Schema.array(:InformedEntity), "Array of Informed Entities",
              required: true
            )
          end
        end,
      InformedEntity:
        swagger_schema do
          title("InformedEntity")
          description("Body for InformedEntity to be included with Alert")

          properties do
            agency_id(:string, "Agency ID")
            route_id(:string, "Route ID")
            facility_id(:string, "Facility ID")
            route_type(:integer, "Route Type")
            direction_id(:integer, "Direction ID", enum: [0, 1])
            stop_id(:string, "Stop ID")
            activities(:array, :string)
            trip(Schema.array(:Trip), "Trip included with Informed Entity")
          end
        end,
      Trip:
        swagger_schema do
          title("TripDescriptor")
          description("TripDescriptor optionally included with Informed Entity")

          properties do
            trip_id(:string, "Trip ID")
            route_id(:string, "Route ID")
            direction_id(:integer, "Direction ID", enum: [0, 1])
            start_time(:string, "Start Time in format HH:MM:SS")
            start_date(:string, "Start Date in format YYYYMMDD")
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
            error(:object)
          end
        end,
      UnauthenticatedError:
        swagger_schema do
          title("AlertError")
          description("send upon returning a 401")

          properties do
            error(:string)
          end
        end
    }
  end
end
