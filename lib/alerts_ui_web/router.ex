defmodule AlertsUIWeb.Router do
  use AlertsUIWeb, :router
  import Oban.Web.Router
  import AlertsUIWeb.UserAuth
  import AlertsUIWeb.PutEnvironmentInAssigns

  @redirect_http Application.compile_env(:alerts_ui, :redirect_http?)

  pipeline :redirect_prod_http do
    if @redirect_http do
      plug(Plug.SSL, rewrite_on: [:x_forwarded_proto])
    end
  end

  pipeline :get_flags do
    plug AlertsUIWeb.Plug.PutFlagsInSessionPlug
  end

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :get_flags
    plug :fetch_live_flash
    plug :put_root_layout, html: {AlertsUIWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_environment_in_assigns

    plug :put_secure_browser_headers, %{
      "strict-transport-security" => "max-age=31536000",
      "content-security-policy" =>
        "default-src 'self'; img-src 'self' cdn.mbta.com data:; style-src 'self' 'unsafe-inline';"
    }

    plug :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :require_author do
    plug :require_roles, required_roles: [:author]
  end

  pipeline :require_developer do
    plug :require_roles, required_roles: [:developer]
  end

  # So far, no unauth views. All endpoints require the user to be in keycloak
  scope "/", AlertsUIWeb do
    # Unauthenticated pages
    pipe_through [:redirect_prod_http, :browser]

    get("/help", PageController, :help)
  end

  # Viewers
  scope "/", AlertsUIWeb do
    # Authenticated pages
    pipe_through [:redirect_prod_http, :browser, :require_authenticated_user]

    get "/", Redirector, to: "/alerts"
    get "/download_history", DownloadHistoryController, :export
    oban_dashboard("/oban")

    live_session :require_authenticated_user,
      on_mount: [
        {AlertsUIWeb.UserAuth, :ensure_authenticated},
        AlertsUIWeb.PutFlagsInAssignsHook,
        AlertsUIWeb.PutEnvironmentInAssigns,
        AlertsUIWeb.PreloadCacheOnMount
      ] do
      live("/alerts", ViewAlertsLive)
      live("/components", ComponentsLive)
    end
  end

  # Authors
  scope "/", AlertsUIWeb do
    # Authenticated pages
    pipe_through [:redirect_prod_http, :browser, :require_authenticated_user, :require_author]

    live_session :require_author,
      on_mount: [
        {AlertsUIWeb.UserAuth, :ensure_authenticated},
        AlertsUIWeb.PutFlagsInAssignsHook,
        AlertsUIWeb.PutEnvironmentInAssigns,
        AlertsUIWeb.PreloadCacheOnMount
      ] do
      live("/alerts/new", CreateAlertLive, :new)
      live("/alerts/edit", CreateAlertLive, :edit)
      live("/alerts/duplicate", CreateAlertLive, :duplicate)
    end
  end

  # Developers
  scope "/", AlertsUIWeb do
    # Authenticated pages
    pipe_through [:redirect_prod_http, :browser, :require_authenticated_user, :require_developer]

    get("/_version", VersionController, :index)

    live_session :require_developer,
      on_mount: [
        {AlertsUIWeb.UserAuth, :ensure_authenticated},
        AlertsUIWeb.PutFlagsInAssignsHook,
        AlertsUIWeb.PutEnvironmentInAssigns,
        AlertsUIWeb.PreloadCacheOnMount
      ] do
      live("/validate", ValidateLive)
      live("/db", DBPageLive)
      live("/import", IBIImporterLive)
    end
  end

  scope "/_flags", Laboratory do
    pipe_through [:browser, :require_developer]
    forward "/", Router
  end

  ## Authentication routes

  scope "/auth", AlertsUIWeb do
    pipe_through [:redirect_prod_http, :browser, :redirect_if_user_is_authenticated]

    get "/:provider", AuthController, :request
  end

  scope "/auth", AlertsUIWeb do
    pipe_through [:redirect_prod_http, :browser]

    get "/:provider/callback", AuthController, :callback
    delete "/keycloak/logout", AuthController, :logout
    # Is this... ok? Can't use delete method in activity_tracker handle_event
    get "/keycloak/logout", AuthController, :logout
  end

  ## Health check

  scope "/", AlertsUIWeb do
    get("/_health", HealthController, :index)
  end

  # Other scopes may use custom stacks.
  scope "/api", AlertsUIWeb do
    pipe_through [:api, :require_authenticated_api_user]
    post "/alerts", ApiController, :new
  end

  # Enable LiveDashboard in development
  if Application.compile_env(:alerts_ui, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through [:redirect_prod_http, :browser, :require_developer]

      live_dashboard "/dashboard", metrics: AlertsUIWeb.Telemetry
    end
  end

  scope "/api/swagger" do
    forward "/", PhoenixSwagger.Plug.SwaggerUI, otp_app: :alerts_ui, swagger_file: "swagger.json"
  end

  def swagger_info do
    %{
      info: %{
        version: "1.0",
        title: "AlertsUI"
      }
    }
  end
end
