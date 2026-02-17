import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/alerts_ui start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :alerts_ui, AlertsUIWeb.Endpoint, server: true
end

# Used for MAIN api key of app in deployed environments.
# Ensures use of the DEV api key for dev environments that use dev API urls
# and PROD api key for ones pointed to production API
get_api_key = fn ->
  if System.get_env("SENTRY_ENV", "") |> String.contains?("dev") do
    System.get_env("DEV_API_KEY")
  else
    System.get_env("API_KEY")
  end
end

cond do
  config_env() == :test ->
    config :alerts_ui, AlertsUI.Repo, url: System.fetch_env!("DATABASE_URL_TEST")

    config :alerts_ui,
      environment_name: System.get_env("SENTRY_ENV", "local"),
      api_url: "https://api-dev.mbtace.com",
      api_key: "",
      dev_api_url: "https://api-dev.mbtace.com",
      dev_api_key: ""

    config :mbta_v3_api,
      base_url: "https://api-dev.mbtace.com/",
      api_key: ""

  config_env() == :prod ->
    # The secret key base is used to sign/encrypt cookies and other secrets.
    # A default value is used in config/dev.exs and config/test.exs but you
    # want to use a different value for prod and you most likely don't want
    # to check this value into version control, so we use an environment
    # variable instead.

    config :sentry,
      dsn: System.fetch_env!("SENTRY_DSN"),
      environment_name: System.get_env("SENTRY_ENV", "local"),
      enable_source_code_context: true,
      root_source_code_paths: [File.cwd!()]

    secret_key_base =
      System.get_env("SECRET_KEY_BASE") ||
        raise """
        environment variable SECRET_KEY_BASE is missing.
        You can generate one by calling: mix phx.gen.secret
        """

    host = System.get_env("PHX_HOST") || "example.com"

    port = String.to_integer(System.get_env("PORT") || "4000")

    config :alerts_ui, AlertsUIWeb.Endpoint,
      url: [host: host, port: 443, scheme: "https"],
      http: [
        # Enable IPv6 and bind on all interfaces.
        # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
        # See the documentation on https://hexdocs.pm/plug_cowboy/Plug.Cowboy.html
        # for details about using IPv6 vs IPv4 and loopback vs public addresses.
        ip: {0, 0, 0, 0, 0, 0, 0, 0},
        port: port
      ],
      secret_key_base: secret_key_base

    pool_size =
      case System.get_env("DATABASE_POOL_SIZE") do
        nil -> 20
        val -> String.to_integer(val)
      end

    port = System.get_env("DATABASE_PORT") |> String.to_integer()
    hostname = System.get_env("DATABASE_HOST")

    config :alerts_ui, AlertsUI.Repo,
      username: System.get_env("DATABASE_USER"),
      database: System.get_env("DATABASE_NAME"),
      hostname: hostname,
      port: port,
      pool_size: pool_size,
      # password set by `configure` callback below
      configure: {AlertsUI.Repo, :before_connect, []},
      timeout: 30_000,
      ssl: true,
      ssl_opts: [
        cacertfile: "priv/aws-cert-bundle.pem",
        verify: :verify_peer,
        server_name_indication: String.to_charlist(hostname),
        verify_fun:
          {&:ssl_verify_hostname.verify_fun/3, [check_hostname: String.to_charlist(hostname)]}
      ]

    config :alerts_ui,
      environment_name: System.get_env("SENTRY_ENV", "local"),
      full_story_org_id: System.get_env("FULLSTORY_ORG_ID"),
      api_url: String.replace_trailing(System.get_env("API_URL"), "/", ""),
      api_key: get_api_key.(),
      ibi_enhanced_alerts_api_url:
        System.get_env(
          "IBI_ENHANCED_ALERTS_API_URL",
          "http://s3.amazonaws.com/mbta-realtime-test/alerts_enhanced.json"
        ),
      ibi_standard_alerts_api_url:
        System.get_env(
          "IBI_STANDARD_ALERTS_API_URL",
          "https://cdn.mbta.com/realtime/Alerts.json"
        ),
      trapeze_sftp_host: System.get_env("TRAPEZE_SFTP_HOST", ""),
      trapeze_sftp_port: System.get_env("TRAPEZE_SFTP_PORT", ""),
      trapeze_sftp_user: System.get_env("TRAPEZE_SFTP_USER", ""),
      trapeze_sftp_password: System.get_env("TRAPEZE_SFTP_PASSWORD", ""),
      trapeze_sftp_filename: System.get_env("TRAPEZE_SFTP_FILENAME", ""),
      # below are used only for GTFS validation
      dev_api_url: String.replace_trailing(System.fetch_env!("DEV_API_URL"), "/", ""),
      dev_api_key: System.fetch_env!("DEV_API_KEY")

    config :mbta_v3_api,
      base_url: String.replace_trailing(System.fetch_env!("API_URL"), "/", ""),
      api_key: get_api_key.()

    if keycloak_issuer = System.get_env("KEYCLOAK_ISSUER") do
      keycloak_base_opts = [
        client_id: System.fetch_env!("KEYCLOAK_CLIENT_ID"),
        client_secret: System.fetch_env!("KEYCLOAK_CLIENT_SECRET")
      ]

      config :ueberauth_oidcc,
        issuers: [
          %{
            name: :keycloak_issuer,
            issuer: keycloak_issuer
          }
        ],
        providers: [
          keycloak: keycloak_base_opts,
          edit_password: keycloak_base_opts,
          update_profile: keycloak_base_opts
        ]
    end

  true ->
    config :alerts_ui, AlertsUI.Repo, url: System.fetch_env!("DATABASE_URL")

    config :alerts_ui,
      environment_name: System.get_env("SENTRY_ENV", "local"),
      # the main API key for your environment
      api_url: String.replace_trailing(System.fetch_env!("API_URL"), "/", ""),
      api_key: System.fetch_env!("API_KEY"),
      # below are used only for GTFS validation
      dev_api_url: String.replace_trailing(System.fetch_env!("DEV_API_URL"), "/", ""),
      dev_api_key: System.fetch_env!("DEV_API_KEY")

    config :sentry,
      # Prevents sentry reporting in local environments
      dsn: nil

    config :mbta_v3_api,
      base_url: String.replace_trailing(System.fetch_env!("API_URL"), "/", ""),
      api_key: System.fetch_env!("API_KEY")
end
