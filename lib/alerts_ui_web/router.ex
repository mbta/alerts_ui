defmodule AlertsUIWeb.Router do
  use AlertsUIWeb, :router

  import AlertsUIWeb.UserAuth

  @redirect_http Application.compile_env(:alerts_ui, :redirect_http?)

  pipeline :redirect_prod_http do
    if @redirect_http do
      plug(Plug.SSL, rewrite_on: [:x_forwarded_proto])
    end
  end

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {AlertsUIWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", AlertsUIWeb do
    # Unauthenticated pages
    pipe_through [:redirect_prod_http, :browser]
  end

  scope "/", AlertsUIWeb do
    # Authenticated pages
    pipe_through [:redirect_prod_http, :browser, :require_authenticated_user]

    get "/", PageController, :home

    live_session :require_authenticated_user,
      on_mount: [{AlertsUIWeb.UserAuth, :ensure_authenticated}] do
      live("/alerts", ViewAlertsLive)
      live("/alerts/new", CreateAlertLive)
    end
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
  # scope "/api", AlertsUIWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard in development
  if Application.compile_env(:alerts_ui, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through [:redirect_prod_http, :browser]

      live_dashboard "/dashboard", metrics: AlertsUIWeb.Telemetry
    end
  end
end
