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
  enhanced_sita_json_output_filename: "alerts_feed_enhanced_SITA.json",
  s3_bucket_name: System.get_env("S3_BUCKET_NAME", ""),
  s3_bucket_prefix: System.get_env("S3_BUCKET_PREFIX", ""),
  skate_file_path: "/detours/active.ndjson",
  skip_migrations: true,
  trapeze_sftp_host: System.get_env("TRAPEZE_SFTP_HOST", ""),
  trapeze_sftp_port: System.get_env("TRAPEZE_SFTP_PORT", ""),
  trapeze_sftp_user: System.get_env("TRAPEZE_SFTP_USER", ""),
  trapeze_sftp_password: System.get_env("TRAPEZE_SFTP_PASSWORD", ""),
  trapeze_sftp_filename: System.get_env("TRAPEZE_SFTP_FILENAME", ""),
  sentry_env: System.get_env("SENTRY_ENV"),
  ## Environment level flags
  # Whether to use translated strings for `cause_detail` and `effect_detail`
  translated_cause_effect_detail?: false,
  # Whether to import from trapeze
  trapeze_import?: true

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
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

config :mbta_v3_api, api_version: "2021-01-09"

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.17",
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
       {
         "*/1 * * * *",
         AlertsUI.Jobs.FeedWriter,
         max_attempts: 1, unique: [period: 30, states: [:available, :scheduled, :executing]]
       },
       # Write GTFS feeds every minute, offset by 30s
       {
         "*/1 * * * *",
         AlertsUI.Jobs.DelayedJob,
         args: %{delay: 30_000, module: AlertsUI.Jobs.FeedWriter},
         max_attempts: 1,
         unique: [period: 30, states: [:available, :scheduled, :executing]]
       },
       # Log checksum of published S3 files every minute
       {"*/1 * * * *", AlertsUI.Jobs.FeedChecker, max_attempts: 1},
       # Read the Trapeze Elevator/Escalator feed, every minute
       {"*/1 * * * *", AlertsUI.Trapeze.Importer, max_attempts: 1},
       # Update recurring alerts every day at 3:01 am EST
       {"1 8 * * *", AlertsUI.Jobs.RecurringAlertUpdater},
       # Validate alerts against production every day at 4:00 am EST
       {"*/30 * * * *", AlertsUI.Jobs.AlertValidationDailyWorker},
       # Check if we need to validate alerts against dev every minute
       {
         "*/1 * * * *",
         AlertsUI.Jobs.AlertValidationUpcomingWorker,
         max_attempts: 1
       },
       # Refresh MBTA API caches every 55 minutes (TTL is 1 hour)
       {"*/55 * * * *", AlertsUI.Jobs.CacheRefreshWorker, max_attempts: 1}
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

# 12 hours in seconds
max_session_time = 12 * 60 * 60

config :alerts_ui, AlertsUIWeb.UserAuth,
  max_session_time: max_session_time,
  # 3 hours in seconds
  idle_time: 3 * 60 * 60

config :ueberauth, Ueberauth,
  providers: [
    keycloak: {
      Ueberauth.Strategy.Oidcc,
      [
        issuer: :keycloak_issuer,
        userinfo: true,
        uid_field: "preferred_username",
        scopes: ~w(openid email roles),
        authorization_params: %{max_age: "#{max_session_time}"},
        authorization_params_passthrough: ~w"prompt login_hint"
      ]
    }
  ]

config :laboratory,
  features: [
    {:show_alerts_table, "Show Alerts Table",
     "Shows menu link to a page with the alerts DB table"},
    {:show_components_page, "Show Components Style Guide page",
     "Shows the menu link to a page showing a guide to our components"},
    {:show_stop_ids, "Show stop ids", "Show a list of selected stop ids in the form."},
    {:fullstory_disabled, "Stop Fullstory",
     "When enabled, turns OFF Fullstory, our session tracker"},
    {:use_legacy_form, "Use legacy form",
     "When enabled, goes back to the legacy version of the form, not the new refactor"},
    {:show_bulk_download_page, "Show Commuter Rail download page", "Shows a page where you
    can download bulk Commuter Rail alerts."},
    {:show_new_bus_detours, "Show New Bus Detours", "Makes bus detours w skate available"}
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
  originator: [name: :user, model: AlertsUI.Models.User],
  originator_relationship_options: [references: :uuid]

# Include referrer in Logster request log
config :logster, :allowed_headers, ["referer"]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
