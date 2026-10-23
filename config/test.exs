import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :alerts_ui, AlertsUI.Repo,
  adapter: Ecto.Adapters.Postgres,
  pool: Ecto.Adapters.SQL.Sandbox

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :alerts_ui, AlertsUIWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "7+lgNetlQrrPYf5ffzj/5XmtGR1YOBlWqEamnZ7Mdzo/pHixA1hIQsd2DtnXW0XQ",
  server: false

# Don't run Oban jobs and plugins during test runs
config :alerts_ui, Oban, testing: :inline

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# function for writing feed output files
config :alerts_ui, file_write_module: AlertsUI.FeedOutput.WriteNowhere

# function for reading S3 files (fake)
config :alerts_ui, file_read_module: AlertsUI.SkateDetours.ReadLocal

config :ueberauth, Ueberauth,
  providers: [
    keycloak: {Ueberauth.Strategy.FakeKeycloak, [issuer: :keycloak_issuer]}
  ]

config :laboratory,
  features: [
    {:test_flag, "Cool Bean", "cool bean for test"},
    {:show_alerts_table, "Show Alerts Table",
     "Shows menu link to a page with the alerts DB table"},
    {:show_components_page, "Show Components Style Guide page",
     "Shows the menu link to a page showing a guide to our components"},
    {:show_stop_ids, "Show stop ids", "Show a list of selected stop ids in the form."},
    {:show_bulk_download_page, "Show Commuter Rail download page", "Shows a page where you
    can download bulk Commuter Rail alerts."},
    {:show_new_bus_detours, "Show New Bus Detours", "Makes bus detours w skate available"}
  ],
  cookie: [
    # one month,
    max_age: 3600 * 24 * 30,
    http_only: true
  ]
