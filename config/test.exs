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

# Don't run data processes (e.g. the API stream) during test
config :alerts_ui, start_data_processes: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
