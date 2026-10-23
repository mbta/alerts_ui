defmodule AlertsUIWeb.Router do
  use AlertsUIWeb, :router
  import Oban.Web.Router
  import AlertsUIWeb.UserAuth
  import AlertsUIWeb.PutMetadataInAssigns

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
    plug :put_metadata_in_assigns

    plug :put_secure_browser_headers, %{
      "strict-transport-security" => "max-age=31536000",
      "content-security-policy" =>
        "default-src 'self'; img-src 'self' https://rs.fullstory.com cdn.mbta.com data:; style-src 'self' 'unsafe-inline'; script-src 'self' https://edge.fullstory.com https://rs.fullstory.com 'unsafe-inline'; connect-src 'self' https://edge.fullstory.com https://rs.fullstory.com 'unsafe-inline';"
    }

    plug :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :require_viewer do
    plug :require_viewer_role
  end

  pipeline :require_author do
    plug :require_roles, required_roles: [:author]
  end

  pipeline :require_developer do
    plug :require_roles, required_roles: [:developer]
  end

  pipeline :static_layout do
    plug :put_layout, html: {AlertsUIWeb.Layouts, :static}
  end

  scope "/", AlertsUIWeb do
    # Unauthenticated pages
    pipe_through [:redirect_prod_http, :browser, :static_layout]

    get("/unauthorized", UnauthorizedController, :index)
    get("/reauthenticate", PageController, :reauthenticate)
  end

  # Viewers
  scope "/", AlertsUIWeb do
    # Authenticated pages
    pipe_through [
      :redirect_prod_http,
      :browser,
      :static_layout,
      :require_authenticated_user,
      :require_viewer
    ]

    get "/", Redirector, to: "/alerts"
    get "/download_history/download", DownloadHistoryController, :export
    get "/download_history/download_bulk", DownloadHistoryController, :export_bulk

    live_session :require_authenticated_user,
      on_mount: [
        {AlertsUIWeb.UserAuth, :ensure_authenticated},
        AlertsUIWeb.PutFlagsInAssignsHook,
        AlertsUIWeb.PutMetadataInAssigns
      ] do
      live("/alerts", ViewAlertsLive)
      live("/components", ComponentsLive)
      live("/help", HelpPageLive)
      live("/sftp_demo", SFTPDemoLive)
      live("/download_history", DownloadHistoryLive)
    end
  end

  # Authors
  scope "/", AlertsUIWeb do
    # Authenticated pages
    pipe_through [
      :redirect_prod_http,
      :browser,
      :require_authenticated_user,
      :require_viewer,
      :require_author
    ]

    live_session :require_author,
      on_mount: [
        {AlertsUIWeb.UserAuth, :ensure_authenticated},
        AlertsUIWeb.PutFlagsInAssignsHook,
        AlertsUIWeb.PutMetadataInAssigns
      ] do
      live("/alerts/new", CreateAlertLive, :new)
      live("/alerts/new/:route_type/", CreateAlertLive, :new)
      live("/alerts/new/:route_type/:effect_name", CreateAlertLive, :new)
      live("/alerts/edit/:alert_id", CreateAlertLive, :edit)
      live("/alerts/edit/:alert_id/:route_type/", CreateAlertLive, :edit)
      live("/alerts/edit/:alert_id/:route_type/:effect_name", CreateAlertLive, :edit)
      live("/alerts/duplicate/:alert_id", CreateAlertLive, :duplicate)
      live("/alerts/duplicate/:alert_id/:route_type/", CreateAlertLive, :duplicate)

      live(
        "/alerts/duplicate/:alert_id/:route_type/:effect_name",
        CreateAlertLive,
        :duplicate
      )
    end
  end

  # Developers
  scope "/", AlertsUIWeb do
    # Authenticated pages
    pipe_through [
      :redirect_prod_http,
      :browser,
      :require_authenticated_user,
      :require_viewer,
      :require_developer
    ]

    oban_dashboard("/oban")
    get("/_version", VersionController, :index)
    get("/detours_viewer", DetoursViewerController, :index)

    live_session :require_developer,
      on_mount: [
        {AlertsUIWeb.UserAuth, :ensure_authenticated},
        AlertsUIWeb.PutFlagsInAssignsHook,
        AlertsUIWeb.PutMetadataInAssigns
      ] do
      live("/db", DBPageLive)
      live("/import", IBIImporterLive)
      live("/feature_flags", FeatureFlagsLive)
    end
  end

  scope "/_flags", Laboratory do
    pipe_through [:browser, :require_authenticated_user]
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
      pipe_through [
        :redirect_prod_http,
        :browser,
        :require_authenticated_user,
        :require_developer
      ]

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
