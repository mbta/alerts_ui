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
  alert_api_url: {:system, "ALERT_API_URL"},
  gtfs_proto_filename: "./assets/outputs/gtfs-realtime.proto",
  enhanced_json_output_filename: "alerts_feed_enhanced.json",
  protobuf_output_filename: "alerts_feed.pb",
  skip_migrations: true

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
       # Import and write GTFS feeds every minute
       {"*/2 * * * *", AlertsUi.FeedImporterExporter,
        max_attempts: 1, unique: [period: 30, states: [:available, :scheduled, :executing]]}
     ]}
  ],
  queues: [default: 10]

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

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
