# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :alerts_ui,
  namespace: AlertsUI,
  ecto_repos: [AlertsUI.Repo],
  aws_rds_mod: ExAws.RDS,
  gtfs_proto_filename: "./assets/outputs/gtfs-realtime.proto",
  standard_json_output_filename: "alerts_feed.json",
  enhanced_json_output_filename: "alerts_feed_enhanced.json",
  protobuf_output_filename: "alerts_feed.pb",
  skip_migrations: true

config :alerts_ui, :phoenix_swagger,
  swagger_files: %{
    "priv/static/swagger.json" => [
      # phoenix routes will be converted to swagger paths
      router: AlertsUIWeb.Router,
      # (optional) endpoint config used to set host, port and https schemes.
      endpoint: AlertsUIWeb.Endpoint
    ]
  }

config :phoenix_swagger, json_library: Jason

config :elixir, :time_zone_database, Tzdata.TimeZoneDatabase

# Configure your database
config :alerts_ui, AlertsUI.Repo,
  migration_timestamps: [
    type: :utc_datetime,
    inserted_at: :created_at
  ],
  migration_primary_key: [name: :id, type: :binary_id],
  migration_foreign_key: [column: :id, type: :binary_id]

# Configures the endpoint
config :alerts_ui, AlertsUIWeb.Endpoint,
  http: [:inet6, port: 4000],
  url: [host: "localhost"],
  render_errors: [
    formats: [html: AlertsUIWeb.ErrorHTML, json: AlertsUIWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: AlertsUI.PubSub,
  live_view: [signing_salt: "zLRBcKO6"]

config :alerts_ui, :redirect_http?, false

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

config :mbta_v3_api, api_version: "2021-01-09"

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.3.2",
  default: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configure Oban
config :alerts_ui, Oban,
  repo: AlertsUI.Repo,
  plugins: [
    Oban.Plugins.Pruner,
    {Oban.Plugins.Cron,
     crontab: [
       # Write GTFS feeds every minute
       {"*/1 * * * *", AlertsUI.FeedWriter,
        max_attempts: 1, unique: [period: 30, states: [:available, :scheduled, :executing]]},
       # Update recurring alerts every day at 3:01 am
       {"1 3 * * *", AlertsUI.RecurringAlertUpdater}
     ]}
  ],
  queues: [default: 10]

# Configures Flop Pagination
config :flop,
  repo: AlertsUI.Repo

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :ueberauth, Ueberauth,
  providers: [
    keycloak: {
      Ueberauth.Strategy.Oidcc,
      [
        issuer: :keycloak_issuer,
        userinfo: true,
        uid_field: "preferred_username",
        scopes: ~w(openid email roles),
        preferred_auth_methods: ~w(client_secret_post)a
      ]
    }
  ]

config :laboratory,
  features: [
    {:show_created_alert, "Show Created Alert", "Makes created alert visible on success screen"},
    {:show_components_page, "Show Components Style Guide page",
     "Shows the menu link to a page showing a guide to our components"},
    {:show_stop_ids, "Show stop ids", "Show a list of selected stop ids in the form."},
    {:show_validate_page, "Show Validate Page",
     "Shows the menu link to a page that helps validate alerts feeds"}
  ],
  cookie: [
    # one month,
    max_age: 3600 * 24 * 30,
    http_only: true
  ]

config :paper_trail,
  repo: AlertsUI.Repo,
  item_type: Ecto.UUID,
  originator_type: Ecto.UUID,
  originator_relationship_options: [references: :uuid]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
